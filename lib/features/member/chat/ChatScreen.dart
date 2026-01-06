// lib/features/member/chat/chat_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'ai_service.dart';
import 'package:intl/intl.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key, required this.gymId, required this.memberId}) : super(key: key);
  final String gymId;
  final String memberId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Uuid _uuid = const Uuid();
  final ImagePicker _imagePicker = ImagePicker();
  bool _shortAnswers = true; //
  static const int _dailySaveLimit = 3;
  bool _isLoading = false;
  bool _isListening = false;
  String _preferredLanguage = 'english';
  late AnimationController _typingController;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    AiService.clearHistory();
    _loadAnswerPref();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeAndAskLanguage();
    });
  }

  @override
  void dispose() {
    _typingController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Helper to strip JSON from AI response text
  String _stripJsonFromText(String text) {
    if (text.isEmpty) return text;

    // Remove ```json ... ``` blocks
    final fenceRegex = RegExp(r'```(?:json)?[\s\S]*?```', multiLine: true, caseSensitive: false);
    String stripped = text.replaceAll(fenceRegex, '');

    // Remove trailing {...} block if present
    final jsonStart = stripped.lastIndexOf('{');
    if (jsonStart != -1) {
      final candidate = stripped.substring(jsonStart);
      if (candidate.contains(':') && candidate.contains('}')) {
        stripped = stripped.substring(0, jsonStart).trim();
      }
    }

    // Remove any remaining JSON-like content
    stripped = stripped.replaceAll(RegExp(r'\{\s*"[^"]*"\s*:\s*"[^"]*"\s*\}'), '');
    stripped = stripped.replaceAll(RegExp(r'\{\s*"[^"]*"\s*:\s*[^}]*\}'), '');

    return stripped.trim();
  }
  Future<void> _loadAnswerPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shortAnswers = prefs.getBool('short_answers_pref') ?? true;
    });
  }
  Future<void> _saveAnswerPref(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('short_answers_pref', v);
    setState(() => _shortAnswers = v);
  }

// returns number of saves already performed today for the member in given collection
  Future<int> _countTodaySaves(String collectionName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final gymId = await _fetchUserGymId();
    if (gymId == null) return 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await FirebaseFirestore.instance
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(user.uid)
        .collection(collectionName)
        .where('date', isEqualTo: today)
        .get();
    return snap.docs.length;
  }
  // Fetch user's gym ID automatically
  Future<String?> _fetchUserGymId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final gymsSnapshot = await FirebaseFirestore.instance.collection('gyms').get();

      for (var gymDoc in gymsSnapshot.docs) {
        final memberDoc = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(gymDoc.id)
            .collection('members')
            .doc(user.uid)
            .get();

        if (memberDoc.exists) {
          return gymDoc.id;
        }
      }
    } catch (e) {
      debugPrint('Error fetching gym ID: $e');
    }
    return null;
  }

  Future<void> _checkFirstTimeAndAskLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOpenedChat = prefs.getBool('has_opened_chat') ?? false;
    final savedLang = prefs.getString('preferred_language') ?? 'english';

    Map<String, dynamic> initialMsg;
    if (!hasOpenedChat) {
      await prefs.setBool('has_opened_chat', true);
      initialMsg = {
        'role': 'bot',
        'text': "Hey! I'm your AI fitness coach, here to help you reach your goals.\n\nWhich language do you prefer?\n• English (professional)\n• Hinglish (casual bhai style)",
        'isLanguageChoice': true,
      };
    } else {
      initialMsg = {
        'role': 'bot',
        'text': savedLang == 'hinglish'
            ? "Arre wapas aaye! Aaj kya plan hai bhai?"
            : "Welcome back! Ready to crush your goals today?",
      };
    }

    if (!mounted) return;
    setState(() {
      _preferredLanguage = savedLang;
      _messages.clear();
      _messages.add(initialMsg);
    });
  }

  Future<void> _saveLanguage(String choice) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = choice.toLowerCase().contains('hin') ? 'hinglish' : 'english';
    await prefs.setString('preferred_language', lang);
    if (!mounted) return;
    setState(() {
      _preferredLanguage = lang;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(int messageIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate the position to show the message at the top of the viewport
        final double itemHeight = 120.0; // Estimated height per message
        final double scrollPosition = messageIndex * itemHeight;

        _scrollController.animateTo(
          scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Helper: try to extract JSON (object or array) from a text blob.
  /// Returns decoded dynamic (Map or List) or null.
  dynamic _extractJsonFromText(String text) {
    if (text.trim().isEmpty) return null;

    // 1) try fenced ```json ... ``` blocks
    final fenceRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true, caseSensitive: false);
    final fenceMatch = fenceRegex.firstMatch(text);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim();
      if (inner != null) {
        try {
          return jsonDecode(inner);
        } catch (_) {
          // fallthrough
        }
      }
    }

    // 2) look for the last {...} or [...] substring that looks like JSON
    // We'll search for balanced braces/brackets starting from each '{' or '['.
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '{' || text[i] == '[') {
        final startChar = text[i];
        final endChar = startChar == '{' ? '}' : ']';
        int depth = 0;
        for (int j = i; j < text.length; j++) {
          if (text[j] == startChar) depth++;
          if (text[j] == endChar) depth--;
          if (depth == 0) {
            final candidate = text.substring(i, j + 1);
            try {
              final decoded = jsonDecode(candidate);
              return decoded;
            } catch (_) {
              break; // stop this candidate and continue searching
            }
          }
        }
      }
    }

    // 3) fallback: try to parse entire text as JSON
    try {
      return jsonDecode(text);
    } catch (_) {}

    return null;
  }

  Future<void> _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Handle language choice flow (unchanged)
    if (_messages.isNotEmpty && _messages[0]['isLanguageChoice'] == true) {
      await _saveLanguage(text);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.add({
          'role': 'bot',
          'text': _preferredLanguage == 'hinglish'
              ? "Perfect! Ab full Hinglish mein baat karte hain! Kya help chahiye?"
              : "Perfect! Let's continue in English. What can I help you with today?",
        });
      });
      _controller.clear();
      _scrollToBottom();
      return;
    }

    // Add user message + typing indicator
    if (mounted) {
      setState(() {
        _messages.add({'role': 'user', 'text': text});
        _messages.add({'role': 'typing'});
        _isLoading = true;
      });
    }
    _controller.clear();
    _scrollToBottom();

    // Helper to parse plan payloads that might be strings or embedded JSON
    Map<String, dynamic>? _parsePlan(dynamic raw, String fallbackText) {
      if (raw == null && (fallbackText == null || fallbackText.isEmpty)) return null;

      if (raw is Map<String, dynamic>) return raw;

      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is List) return {'table': decoded};
        } catch (_) {}
      }

      // Try to extract JSON from fallbackText using existing extractor
      if (fallbackText.isNotEmpty) {
        final extracted = _extractJsonFromText(fallbackText);
        if (extracted != null) {
          if (extracted is Map<String, dynamic>) return extracted;
          if (extracted is List) return {'table': extracted};
        }
      }

      return null;
    }

    try {
      // Build system hint dynamically using current prefs
      final systemHint = _preferredLanguage == 'hinglish'
          ? (_shortAnswers
          ? "(Reply in Hinglish; be short & professional — 1–2 sentences. Hide internal JSON/code-blocks.)"
          : "(Reply in Hinglish; be professional and detailed. Hide internal JSON/code-blocks.)")
          : (_shortAnswers
          ? "(Reply in English; be short & professional — 1–2 sentences. Hide internal JSON/code-blocks.)"
          : "(Reply in English; be professional and detailed. Hide internal JSON/code-blocks.)");

      final modifiedMessage =
          "$text. $systemHint Please include machine-readable workout/diet only inside a fenced ```json``` block when needed.";

      // Call AI service
      final result = await AiService().ask(modifiedMessage);

      if (!mounted) return;

      // Remove typing bubble
      setState(() {
        _messages.removeWhere((m) => m['role'] == 'typing');
      });

      final cleanReplyText = _stripJsonFromText(result.replyText ?? '');

      // parse possible plans (from fields or embedded JSON)
      final parsedWorkout = _parsePlan(result.workoutPlan, result.replyText ?? '');
      final parsedDiet = _parsePlan(result.dietPlan, result.replyText ?? '');

      final bool userAskedForPlan = text.toLowerCase().contains('plan') ||
          text.toLowerCase().contains('workout') ||
          text.toLowerCase().contains('diet') ||
          text.toLowerCase().contains('exercise') ||
          text.toLowerCase().contains('routine');

      final bool shouldShowPlan = userAskedForPlan && (parsedWorkout != null || parsedDiet != null);

      debugPrint('AI result: parsedWorkout=${parsedWorkout != null}, parsedDiet=${parsedDiet != null}, shouldShowPlan=$shouldShowPlan');

      // Add bot message with attached plans when appropriate
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': cleanReplyText.isNotEmpty ? cleanReplyText : "Your personalized plan is ready! Check the details below.",
          'workoutPlan': shouldShowPlan ? parsedWorkout : null,
          'dietPlan': shouldShowPlan ? parsedDiet : null,
          'saveFlag': shouldShowPlan ? (result.saveFlag ?? false) : false,
        });
      });

      // If plan detected => show floating SnackBar with Save action and auto-open modal
      if (shouldShowPlan) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              content: Row(
                children: const [
                  Icon(Icons.bookmark, color: Color(0xFF00E676)),
                  SizedBox(width: 12),
                  Expanded(child: Text('AI generated plan detected — would you like to save it?')),
                ],
              ),
              action: SnackBarAction(
                label: 'Save',
                textColor: Colors.white,
                onPressed: () {
                  // safely fetch last bot message and open modal
                  final Map<String, dynamic>? lastBot = _messages.reversed.firstWhere(
                        (m) => m['role'] == 'bot',
                    orElse: () => <String, dynamic>{},
                  ) as Map<String, dynamic>?;
                  _promptSaveDialog(lastBot?['workoutPlan'] as Map<String, dynamic>?, lastBot?['dietPlan'] as Map<String, dynamic>?);
                },
              ),
            ),
          );
        }

        // Auto-open save modal after UI frame (use last bot message)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final Map<String, dynamic>? lastBot = _messages.reversed.firstWhere(
                (m) => m['role'] == 'bot',
            orElse: () => <String, dynamic>{},
          ) as Map<String, dynamic>?;
          _promptSaveDialog(lastBot?['workoutPlan'] as Map<String, dynamic>?, lastBot?['dietPlan'] as Map<String, dynamic>?);
        });
      }

      // scroll to show new bot message
      _scrollToComfortablePosition();
    } catch (e, st) {
      debugPrint('Send message error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['role'] == 'typing');
        _messages.add({
          'role': 'bot',
          'text': _preferredLanguage == 'hinglish'
              ? "Network issue hai. Dobara try karo!"
              : "Connection issue. Please try again!",
        });
      });
      _scrollToComfortablePosition();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToComfortablePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.length > 2) {
        // Scroll to show the last 2-3 messages (user question + AI response)
        final int targetIndex = _messages.length > 3 ? _messages.length - 3 : 0;
        final double itemHeight = 120.0;
        final double scrollPosition = targetIndex * itemHeight;

        _scrollController.animateTo(
          scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollToBottom();
      }
    });
  }

  // For image messages
  Future<void> _sendImageMessage(File imageFile) async {
    try {
      setState(() => _isLoading = true);

      // Convert image to base64
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      final String imageType = imageFile.path.split('.').last;

      // Add image message to chat
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'user',
            'type': 'image',
            'imageBytes': base64Image,
            'imageType': imageType,
            'text': 'Sent an image'
          });
        });
      }

      _scrollToBottom();

      // Send base64 image to AI for analysis
      final modifiedMessage = "Analyze this fitness-related image (format: $imageType) and provide guidance: data:image/$imageType;base64,$base64Image";
      final result = await AiService().ask(modifiedMessage);

      if (!mounted) return;
      setState(() {
        final cleanReplyText = _stripJsonFromText(result.replyText);
        _messages.add({
          'role': 'bot',
          'text': cleanReplyText.isNotEmpty ? cleanReplyText : "I've analyzed your image. Here's my feedback!",
          // Don't show plans for image analysis
          'workoutPlan': null,
          'dietPlan': null,
          'saveFlag': false,
        });
      });

      _scrollToComfortablePosition();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        _sendImageMessage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image selection failed: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF00E676)),
                title: const Text('Camera', style: TextStyle(fontFamily: 'Poppins')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF00E676)),
                title: const Text('Gallery', style: TextStyle(fontFamily: 'Poppins')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone not available")),
      );
      return;
    }
    if (mounted) setState(() => _isListening = true);
    _speech.listen(onResult: (result) {
      _controller.text = result.recognizedWords;
      if (result.finalResult) {
        if (mounted) setState(() => _isListening = false);
        if (_controller.text.trim().isNotEmpty) {
          _sendMessage();
        }
      }
    });
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _promptSaveDialog(Map<String, dynamic>? workoutPlan, Map<String, dynamic>? dietPlan) async {
    if (workoutPlan == null && dietPlan == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: Color(0xFF00E676), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Save Plan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Where would you like to save this plan?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              if (workoutPlan != null)
                _buildSaveOption(
                  'Workout Plan',
                  'Save to your workouts collection',
                  Icons.fitness_center_rounded,
                      () => Navigator.pop(context, 'workout'),
                  isDark,
                ),
              if (workoutPlan != null && dietPlan != null) const SizedBox(height: 12),
              if (dietPlan != null)
                _buildSaveOption(
                  'Diet Plan',
                  'Save to your diets collection',
                  Icons.restaurant_menu_rounded,
                      () => Navigator.pop(context, 'diet'),
                  isDark,
                ),
              if (workoutPlan != null && dietPlan != null) const SizedBox(height: 12),
              if (workoutPlan != null && dietPlan != null)
                _buildSaveOption(
                  'Save Both',
                  'Save workout and diet plans',
                  Icons.done_all_rounded,
                      () => Navigator.pop(context, 'both'),
                  isDark,
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    // show a saving dialog while we persist
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Saving plan...'),
            ],
          ),
        ),
      ),
    );

    try {
      if (result == 'workout' && workoutPlan != null) {
        // save workout; alsoSaveGlobal true so it can appear in Trending if desired
        final id = await _savePlanToCollection('workouts', workoutPlan, alsoSaveGlobal: true);
        debugPrint('Saved workout id=$id');
      } else if (result == 'diet' && dietPlan != null) {
        final id = await _savePlanToCollection('diets', dietPlan, alsoSaveGlobal: false);
        debugPrint('Saved diet id=$id');
      } else if (result == 'both') {
        if (workoutPlan != null) {
          final id1 = await _savePlanToCollection('workouts', workoutPlan, alsoSaveGlobal: true);
          debugPrint('Saved workout id=$id1');
        }
        if (dietPlan != null) {
          final id2 = await _savePlanToCollection('diets', dietPlan, alsoSaveGlobal: false);
          debugPrint('Saved diet id=$id2');
        }
      }
    } catch (e) {
      debugPrint('Error saving plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      Navigator.of(context, rootNavigator: true).pop(); // remove saving dialog
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan saved successfully!'),
        backgroundColor: Color(0xFF00E676),
      ),
    );
  }

  Widget _buildSaveOption(String title, String subtitle, IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00E676), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _savePlanToCollection(
      String collectionName,
      Map<String, dynamic> plan, {
        bool alsoSaveGlobal = false,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to save plans')));
      return null;
    }

    try {
      final gymId = await _fetchUserGymId();
      if (gymId == null) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym membership not found')));
        return null;
      }

      // Enforce per-day limit (3)
      final now = DateTime.now();
      final String dateStr = DateFormat('yyyy-MM-dd').format(now);

      // Query member collection for today's saves in this collection
      final todaySnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .collection(collectionName)
          .where('date', isEqualTo: dateStr)
          .get();

      final int todayCount = todaySnapshot.docs.length;
      if (todayCount >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daily limit reached (3). Try tomorrow or delete an old plan.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }

      // Normalize plan summary fields
      final String name = (plan['name'] ?? plan['title'] ?? 'Untitled Workout').toString();
      final int duration = plan['duration'] is int ? plan['duration'] as int : (plan['totalDuration'] ?? 0);
      final int calories = plan['calories'] is int ? plan['calories'] as int : (plan['estimatedCalories'] ?? 0);
      final List<dynamic> exercises = plan['exercises'] is List ? plan['exercises'] as List : (plan['table'] is List ? plan['table'] as List : []);
      final String thumbnail = plan['imageUrl'] ?? plan['thumbnail'] ?? '';
      final String difficulty = plan['difficulty'] ?? 'Intermediate';

      final payload = <String, dynamic>{
        'name': name,
        'plan': plan,
        'date': dateStr, // normalized string date for easy server-side queries
        'duration': duration,
        'calories': calories,
        'exercisesCount': exercises.length,
        'imageUrl': thumbnail,
        'difficulty': difficulty,
        'savedBy': 'ai',
        'source': 'ai_coach',
        'savedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to member's collection
      final ref = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .collection(collectionName)
          .add(payload);

      // Optionally save to global collection for trending / discovery
      if (alsoSaveGlobal) {
        await FirebaseFirestore.instance.collection(collectionName).doc(ref.id).set({
          ...payload,
          'gymId': gymId,
          'memberId': user.uid,
          'visibility': 'public',
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$collectionName saved'), backgroundColor: const Color(0xFF00E676)),
        );
      }
      return ref.id;
    } catch (e, st) {
      debugPrint('Save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
      return null;
    }
  }

  Widget _buildTypingBubble() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 12),
            TypingDots(controller: _typingController, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (msg['type'] == 'image') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 60, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E676), Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(msg['imageBytes']),
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 150,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg['text'],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 60, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00C853)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          msg['text'],
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBotBubble(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPlan = msg['workoutPlan'] != null || msg['dietPlan'] != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 60, bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    msg['text'],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            if (hasPlan) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E676), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "YOUR PERSONAL PLAN",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (msg['workoutPlan'] != null) _buildPlanTable(msg['workoutPlan']),
                    if (msg['dietPlan'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDietTable(msg['dietPlan']),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _promptSaveDialog(
                          msg['workoutPlan'],
                          msg['dietPlan'],
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Save Plan",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTable(Map<String, dynamic> plan) {
    final rows = <Map<String, dynamic>>[];
    if (plan['table'] is List) {
      for (var r in plan['table']) {
        if (r is Map) rows.add(Map<String, dynamic>.from(r));
      }
    }
    if (rows.isEmpty) {
      return const Text(
        "Workout plan details available",
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.black87,
          fontSize: 12,
        ),
      );
    }

    final columns = rows.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowHeight: 48,
        columnSpacing: 20,
        headingRowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.1)),
        columns: columns
            .map((c) => DataColumn(
          label: Text(
            c,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ))
            .toList(),
        rows: rows
            .map(
              (r) => DataRow(
            cells: columns
                .map((c) => DataCell(
              Text(
                '${r[c] ?? ''}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                  fontSize: 11,
                ),
              ),
            ))
                .toList(),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildDietTable(Map<String, dynamic> plan) {
    final rows = <Map<String, dynamic>>[];
    if (plan['table'] is List) {
      for (var r in plan['table']) {
        if (r is Map) rows.add(Map<String, dynamic>.from(r));
      }
    }
    if (rows.isEmpty) {
      return const Text(
        "Diet plan details available",
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.black87,
          fontSize: 12,
        ),
      );
    }

    final columns = rows.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowHeight: 48,
        columnSpacing: 20,
        headingRowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.1)),
        columns: columns
            .map((c) => DataColumn(
          label: Text(
            c,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ))
            .toList(),
        rows: rows
            .map(
              (r) => DataRow(
            cells: columns
                .map((c) => DataCell(
              Text(
                '${r[c] ?? ''}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                  fontSize: 11,
                ),
              ),
            ))
                .toList(),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final suggestions = _preferredLanguage == 'hinglish'
        ? [
      {'icon': Icons.fitness_center_rounded, 'text': 'Workout plan banao'},
      {'icon': Icons.restaurant_menu_rounded, 'text': 'Diet chart chahiye'},
      {'icon': Icons.monitor_weight_rounded, 'text': 'Weight loss tips'},
      {'icon': Icons.flash_on_rounded, 'text': 'Motivation chahiye'},
    ]
        : [
      {'icon': Icons.fitness_center_rounded, 'text': 'Create workout plan'},
      {'icon': Icons.restaurant_menu_rounded, 'text': 'Give me diet chart'},
      {'icon': Icons.monitor_weight_rounded, 'text': 'Weight loss tips'},
      {'icon': Icons.flash_on_rounded, 'text': 'Motivate me'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((suggestion) {
            return GestureDetector(
              onTap: () {
                _controller.text = suggestion['text'] as String;
                _sendMessage();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      suggestion['icon'] as IconData,
                      size: 16,
                      color: const Color(0xFF00E676),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      suggestion['text'] as String,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSuggestions = _messages.length <= 2 && !_isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSuggestions) _buildSuggestionChips(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            border: showSuggestions ? null : Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              // Image picker button
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: const Color(0xFF00E676),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Voice input button
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red.withOpacity(0.1)
                        : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening
                          ? Colors.red
                          : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? Colors.red : (isDark ? Colors.white54 : Colors.black54),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Text input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: _preferredLanguage == 'hinglish'
                          ? "Kya puchna hai..."
                          : "Type anything...",
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Send button
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00C853)],
                    ),
                    color: _isLoading ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)) : null,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E676),
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Coach",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  "Powered by Fitnophedia",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                if (msg['role'] == 'typing') return _buildTypingBubble();
                if (msg['role'] == 'user') return _buildUserBubble(msg);
                return _buildBotBubble(msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}

class TypingDots extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const TypingDots({Key? key, required this.controller, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: [0.0, 0.33, 0.66].map((delay) {
          return Opacity(
            opacity: ((controller.value + (1 - delay)) % 1.0),
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white38 : Colors.black38,
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}