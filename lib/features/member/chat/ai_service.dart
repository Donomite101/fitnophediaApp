import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiResult {
  final String replyText;
  final Map<String, dynamic>? workoutPlan;
  final Map<String, dynamic>? dietPlan;
  final bool saveFlag;

  AiResult({
    required this.replyText,
    this.workoutPlan,
    this.dietPlan,
    required this.saveFlag,
  });
}

class AiService {
  // Load from environment variables for security
  static String get groqKey {
    final key = dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty) print('⚠️ WARNING: GROQ_API_KEY is missing in .env!');
    return key;
  }

  static const String MODEL = "llama-3.3-70b-versatile";
  static const int MAX_RETRIES = 4;
  static final Duration INITIAL_BACKOFF = const Duration(seconds: 2);
  static const int SAFE_MAX_TOKENS = 2000; // safer default; provider may reject huge values

  static final List<Map<String, String>> _history = [];
  static const int _maxHistory = 8;

  static void clearHistory() => _history.clear();

  static void addToHistory(String text) {
    _history.add({"role": "user", "content": text});
    if (_history.length > _maxHistory) _history.removeRange(0, _history.length - _maxHistory);
  }

  static void addBotToHistory(String text) {
    _history.add({"role": "assistant", "content": text});
    if (_history.length > _maxHistory) _history.removeRange(0, _history.length - _maxHistory);
  }

  Future<Map<String, dynamic>> getFullProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _defaultProfile();

    try {
      // 1. Get gymId from users collection first (much faster)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return _defaultProfile();

      final gymId = userDoc.data()?['gymId'];
      if (gymId == null) return _defaultProfile();

      // 2. Fetch full member profile from the correct gym
      final memberDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (memberDoc.exists) {
        final data = memberDoc.data()!;
        // Return all relevant fields for the AI
        return {
          'name': data['firstName'] ?? data['name'] ?? 'Member',
          'age': data['age'] ?? 25,
          'weightKg': (data['weight'] is num) ? (data['weight'] as num).toDouble() : 70.0,
          'heightCm': data['height'] ?? 170,
          'gender': data['gender'] ?? 'male',
          'goal': data['primaryGoal'] ?? 'muscle_gain',
          'level': data['fitnessLevel'] ?? 'Beginner',
          'dietType': data['dietType'] ?? 'veg',
          'injuries': data['injuries'] ?? data['injuryHistory'] ?? 'none',
          'medicalConditions': data['medicalConditions'] ?? 'none',
          'daysPerWeek': data['workoutFrequency'] ?? '4 days',
          'equipment': 'gym', // Default to gym access
        };
      }
    } catch (e) {
      print('Profile fetch error: $e');
    }
    return _defaultProfile();
  }

  Map<String, dynamic> _defaultProfile() => {
    'name': 'Member',
    'age': 25,
    'weightKg': 70.0,
    'heightCm': 170,
    'gender': 'male',
    'goal': 'muscle_gain',
    'level': 'Beginner',
    'dietType': 'veg',
    'injuries': 'none',
    'medicalConditions': 'none',
    'daysPerWeek': '4 days',
    'equipment': 'gym',
  };

  Future<AiResult> ask(String message, {List<String>? availableExercises}) async {
    final profile = await getFullProfile();
    final name = profile['name'] ?? 'Member';

    // maintain short history
    _history.add({"role": "user", "content": message});
    if (_history.length > _maxHistory) _history.removeRange(0, _history.length - _maxHistory);

    final systemPrompt = _buildSystemPrompt(profile, availableExercises);

    final messages = [
      {"role": "system", "content": systemPrompt},
      ..._history,
    ];

    try {
      final content = await _callGroqApiWithRetries(messages);
      if (content == null) {
        // explanatory friendly message instead of blank
        return AiResult(
          replyText: 'Server busy ya rate-limited hai. Thodi der baad try karein, $name.',
          workoutPlan: null,
          dietPlan: null,
          saveFlag: false,
        );
      }

      // parse response robustly
      String replyText = content;
      Map<String, dynamic>? workoutPlan;
      Map<String, dynamic>? dietPlan;
      bool saveFlag = false;

      final extracted = _extractJsonFromContent(content);
      if (extracted != null && extracted is Map<String, dynamic>) {
        if (extracted['workoutPlan'] is Map) workoutPlan = Map<String, dynamic>.from(extracted['workoutPlan']);
        if (extracted['dietPlan'] is Map) dietPlan = Map<String, dynamic>.from(extracted['dietPlan']);
        saveFlag = extracted['save'] == true;

        final jsonBlock = _jsonSubstring(content);
        if (jsonBlock.isNotEmpty) {
           // Remove the JSON block and anything after it to keep the UI clean
           final index = content.indexOf(jsonBlock);
           if (index != -1) {
             replyText = content.substring(0, index).trim();
           }
        }
      } else {
        final fallback = _tryParseMarkdownFallback(content);
        if (fallback != null) {
          if (fallback['workoutPlan'] != null) workoutPlan = Map<String, dynamic>.from(fallback['workoutPlan']);
          if (fallback['dietPlan'] != null) dietPlan = Map<String, dynamic>.from(fallback['dietPlan']);
          replyText = _removeMatchedTables(content).trim();
        }
      }

      // Make replyText non-empty & friendly
      replyText = replyText.trim();
      if (replyText.isEmpty) replyText = "Plan generated — details available. Let me know if you'd like changes.";

      // store assistant part in history (no JSON)
      _history.add({"role": "assistant", "content": replyText});
      if (_history.length > _maxHistory) _history.removeRange(0, _history.length - _maxHistory);

      return AiResult(replyText: replyText, workoutPlan: workoutPlan, dietPlan: dietPlan, saveFlag: saveFlag);
    } on TimeoutException {
      return AiResult(replyText: 'Request timed out — try again.', workoutPlan: null, dietPlan: null, saveFlag: false);
    } catch (e) {
      print('Ask error: $e');
      return AiResult(replyText: 'Kuch issue aaya — please retry.', workoutPlan: null, dietPlan: null, saveFlag: false);
    }
  }

  String _buildSystemPrompt(Map<String, dynamic> profile, List<String>? availableExercises) {
    final name = profile['name'];
    final age = profile['age'];
    final weight = profile['weightKg'];
    final height = profile['heightCm'];
    final goal = profile['goal'];
    final level = profile['level'];
    final dietType = profile['dietType'];
    final injuries = profile['injuries'];
    final medical = profile['medicalConditions'];
    final days = profile['daysPerWeek'];

    String exerciseConstraint = "";
    if (availableExercises != null && availableExercises.isNotEmpty) {
      final exerciseList = availableExercises.join(", ");
      exerciseConstraint = '''
IMPORTANT: You must ONLY recommend exercises from the following list to ensure they have images in the app. 
If a user asks for something not here, find the closest match in this list.
AVAILABLE EXERCISES: [$exerciseList]
''';
    }

    return '''
You are Coach Fitnophedia, a highly intelligent, empathetic, and "human-like" Personal Trainer.
User Profile:
- Name: $name
- Stats: ${age}y, ${weight}kg, ${height}cm
- Goal: $goal
- Level: $level
- Diet: $dietType
- Schedule: $days/week
- Issues: Injuries: $injuries, Medical: $medical

$exerciseConstraint

CORE ALGORITHM & BEHAVIOR:
1.  **Analyze First:** Before answering, "think" about the user's prompt. Detect their emotion (motivated, frustrated, confused) and intent.
2.  **Be a Trainer, Not a Bot:**
    - Do NOT just dump data. Speak like a real coach.
    - If a user says "I want to gain 10kg in 3 months", don't just give a plan. Validate it: "That's an aggressive goal, bro! We'll need a serious calorie surplus. Here's how we'll attack it..."
    - Use "Gen-Z" friendly, Indian-context language (Bro, Chill, Scene sorted, Desi diet).
    - **Variety is Key:** Do NOT always start with the same exercises. Mix it up! If the user asks for a chest workout, don't always start with Bench Press. Try Dumbbell Press, or Incline, or even a Machine Press sometimes.
    - **Use Available Exercises:** Prioritize the "AVAILABLE EXERCISES" list provided above.
3.  **"Learn" & Remember:**
    - Always check the chat history. If the user previously said they hate "Karela", NEVER suggest it.
    - If they mentioned an injury before, ask "How's the knee feeling today?" before suggesting squats.
4.  **Format Rules:**
    - Keep conversational text engaging but concise.
    - **ONLY** if a specific WORKOUT or DIET plan is needed/requested, append the **JSON block** at the very end.
    - Do NOT write anything after the ```json``` block.

JSON STRUCTURE (Use strictly if plan requested):
```json
{
  "workoutPlan": {
    "title": "Aggressive Hypertrophy Split",
    "schedule": [
      {
        "day": "Monday",
        "focus": "Push (Chest/Shoulders/Triceps)",
        "exercises": [
          {"name": "Bench Press", "sets": "4", "reps": "6-8", "notes": "Heavy loading for mass"},
          {"name": "Overhead Press", "sets": "3", "reps": "8-10", "notes": "Control the eccentric"}
        ]
      }
    ]
  },
  "dietPlan": {
    "title": "Bulking Surplus Diet",
    "calories": 2800,
    "macros": {"protein": "160g", "carbs": "350g", "fats": "80g"},
    "meals": [
      {
        "name": "Pre-Workout",
        "items": ["Banana", "Black Coffee", "Toast with Peanut Butter"],
        "calories": 300
      }
    ]
  }
}
```
''';
  }

  // API call with retries and robust content extraction
  Future<String?> _callGroqApiWithRetries(List<Map<String, String>> messages) async {
    var attempt = 0;
    var backoff = INITIAL_BACKOFF;
    while (attempt < MAX_RETRIES) {
      attempt++;
      try {
        final uri = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
        final body = jsonEncode({
          "model": MODEL,
          "messages": messages,
          "temperature": 0.3,
          "max_tokens": SAFE_MAX_TOKENS,
          "top_p": 0.9,
        });

        final response = await http
            .post(
          uri,
          headers: {"Authorization": "Bearer $groqKey", "Content-Type": "application/json"},
          body: body,
        )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          // Support multiple shapes: choices[0].message.content OR choices[0].text
          final contentField = decoded['choices']?[0]?['message']?['content'];
          final alt = decoded['choices']?[0]?['text'];
          final content = (contentField ?? alt ?? '').toString().trim();
          return content;
        }

        // Log non-200 for debugging (very important)
        print('Groq API non-200: ${response.statusCode} -> ${response.body}');

        if (response.statusCode == 429) {
          // rate limited: backoff and retry
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }

        // Retry on server errors
        if (response.statusCode >= 500 && response.statusCode < 600) {
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }

        // Client error or other: return null so caller shows friendly message
        return null;
      } on TimeoutException {
        print('Groq API timeout on attempt $attempt');
        if (attempt >= MAX_RETRIES) rethrow;
        await Future.delayed(backoff);
        backoff *= 2;
      } catch (e) {
        print('Groq API exception: $e');
        if (attempt >= MAX_RETRIES) rethrow;
        await Future.delayed(backoff);
        backoff *= 2;
      }
    }
    return null;
  }

  // --- JSON extraction helpers (fixed regexes) ---
  static String _jsonSubstring(String content) {
    final codeFenceRegex = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true);
    final codeMatch = codeFenceRegex.firstMatch(content);
    if (codeMatch != null) return codeMatch.group(0) ?? '';

    final lastOpen = content.lastIndexOf('{');
    if (lastOpen == -1) return '';
    int depth = 0;
    for (int i = lastOpen; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return content.substring(lastOpen, i + 1);
        }
      }
    }
    return '';
  }

  static dynamic _extractJsonFromContent(String content) {
    try {
      final codeFenceRegex = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true);
      final codeMatch = codeFenceRegex.firstMatch(content);
      if (codeMatch != null) {
        final inside = codeMatch.group(1) ?? '';
        return jsonDecode(inside);
      }
      final substr = _jsonSubstring(content);
      if (substr.isNotEmpty) return jsonDecode(substr);
    } catch (e) {
      print('extractJson error: $e');
    }
    return null;
  }

  // --- Markdown table fallback (kept simple) ---
  static List<Map<String, String>> _parseMarkdownTable(String md) {
    final lines = md.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) return [];
    final headerParts = lines[0].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (headerParts.isEmpty) return [];
    final dataLines = <String>[];
    for (int i = 2; i < lines.length; i++) {
      if (lines[i].contains('|')) dataLines.add(lines[i]);
    }
    final rows = <Map<String, String>>[];
    for (var r in dataLines) {
      final cols = r.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (cols.isEmpty) continue;
      final map = <String, String>{};
      for (var i = 0; i < headerParts.length && i < cols.length; i++) map[headerParts[i]] = cols[i];
      rows.add(map);
    }
    return rows;
  }

  static Map<String, dynamic>? _tryParseMarkdownFallback(String content) {
    try {
      final tableRegex = RegExp(r'\|[^\n]*\|\s*\n\|[-:\s|]+\|\s*\n(?:\|[^\n]*\|\s*\n?)+', multiLine: true);
      final matches = tableRegex.allMatches(content).toList();
      if (matches.isEmpty) return null;
      List<Map<String, String>>? workoutTbl;
      List<Map<String, String>>? dietTbl;
      if (matches.length >= 1) workoutTbl = _parseMarkdownTable(matches[0].group(0) ?? '');
      if (matches.length >= 2) dietTbl = _parseMarkdownTable(matches[1].group(0) ?? '');
      final out = <String, dynamic>{};
      if (workoutTbl != null && workoutTbl.isNotEmpty) out['workoutPlan'] = {'table': workoutTbl};
      if (dietTbl != null && dietTbl.isNotEmpty) out['dietPlan'] = {'table': dietTbl};
      return out.isEmpty ? null : out;
    } catch (e) {
      print('markdown fallback parse error: $e');
      return null;
    }
  }

  static String _removeMatchedTables(String content) {
    try {
      final tableRegex = RegExp(r'\|[^\n]*\|\s*\n\|[-:\s|]+\|\s*\n(?:\|[^\n]*\|\s*\n?)+', multiLine: true);
      return content.replaceAll(tableRegex, '').trim();
    } catch (e) {
      return content;
    }
  }
}
