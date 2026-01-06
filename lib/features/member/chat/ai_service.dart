// REPLACE your existing AiService with this file (keep imports)
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
  static String get groqKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String MODEL = "llama-3.3-70b-versatile";
  static const int MAX_RETRIES = 4;
  static final Duration INITIAL_BACKOFF = const Duration(seconds: 2);
  static const int SAFE_MAX_TOKENS = 2000; // safer default; provider may reject huge values

  static final List<Map<String, String>> _history = [];
  static const int _maxHistory = 8;

  static void clearHistory() => _history.clear();

  Future<Map<String, dynamic>> getFullProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _defaultProfile();
    try {
      final gyms = await FirebaseFirestore.instance.collection('gyms').get();
      for (var gym in gyms.docs) {
        final doc = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(gym.id)
            .collection('members')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          return {
            'name': data['name'] ?? 'Member',
            'age': data['age'] ?? 25,
            'weightKg': (data['weight'] is num) ? (data['weight'] as num).toDouble() : 70.0,
            'heightCm': data['height'] ?? 170,
            'gender': data['gender'] ?? 'male',
            'goal': data['primaryGoal'] ?? 'muscle_gain',
            'level': data['trainingLevel'] ?? 'Beginner',
            'dietType': data['dietType'] ?? 'veg',
            'injuries': data['injuries'] ?? 'none',
            'gymAccess': data['gymAccess'] == true,
            'daysPerWeek': data['daysPerWeek'] ?? 4,
          };
        }
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
    'gymAccess': true,
    'daysPerWeek': 4,
  };

  Future<AiResult> ask(String message) async {
    final profile = await getFullProfile();
    final name = profile['name'] ?? 'Member';

    // maintain short history
    _history.add({"role": "user", "content": message});
    if (_history.length > _maxHistory) _history.removeRange(0, _history.length - _maxHistory);

    final systemPrompt = _buildSystemPrompt(profile);

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
        if (jsonBlock.isNotEmpty) replyText = content.replaceFirst(jsonBlock, '').trim();
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

  String _buildSystemPrompt(Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'Member';
    final age = profile['age'] ?? 25;
    final weight = profile['weightKg'] ?? 70.0;
    final height = profile['heightCm'] ?? 170;
    final goal = profile['goal'] ?? 'muscle_gain';
    final level = profile['level'] ?? 'Beginner';
    final dietType = profile['dietType'] ?? 'veg';
    final gymAccess = profile['gymAccess'] == true;
    final days = profile['daysPerWeek'] ?? 4;

    final heightM = height / 100.0;
    final bmi = weight / (heightM * heightM);
    final bmiCategory = bmi < 18.5 ? 'underweight' : bmi < 25 ? 'normal' : bmi < 30 ? 'overweight' : 'obese';

    final bmr = profile['gender'] == 'male'
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;

    int targetCal = (bmr * 1.5).round();
    if (goal == 'weight_loss') targetCal -= 500;
    if (goal == 'muscle_gain') targetCal += 300;

    final proteinG = (weight * (goal == 'muscle_gain' ? 2.0 : 1.6)).round();

    return '''
You are Coach Fitnophedia — a premium AI fitness coach. User: $name (${age}y, ${weight}kg, ${height}cm, $level, Goal: $goal, Diet: $dietType, BMI: ${bmi.toStringAsFixed(1)} - $bmiCategory).

RESPONSE RULES:
1) Start with 1-2 motivational sentences addressing $name.
2) Only generate workout/diet plans when the user explicitly asks. Otherwise give helpful answers without plans.
3) If a plan is produced: show MARKDOWN TABLES in human text and append exactly one machine-readable JSON object inside ```json``` at the end (no extra text after the closing fence).
4) Keep answers concise, professional and friendly.
5) Keep human text <400 words.
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
