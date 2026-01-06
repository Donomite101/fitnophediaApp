import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import 'widgets/plan_card.dart';
import 'ai_service.dart';
import 'chat_history_screen.dart';
import '../../workout/data/providers/workout_provider.dart';

class ChatScreen extends StatefulWidget {
  final String? gymId;
  final String? memberId;
  final String? sessionId; // If provided, loads an existing chat session

  const ChatScreen({Key? key, this.gymId, this.memberId, this.sessionId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // Session Management
  String? _currentSessionId;
  bool _isNewSession = true;

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Typing animation
  late AnimationController _typingController;

  // Language preference
  String _preferredLanguage = 'english'; 

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _currentSessionId = widget.sessionId;
    _isNewSession = _currentSessionId == null;

    if (_isNewSession) {
      _checkLanguageAndInit();
    } else {
      _loadSessionMessages();
    }
  }

  Future<void> _checkLanguageAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('preferredLanguage')) {
        setState(() {
          _preferredLanguage = doc.data()!['preferredLanguage'];
        });
        // Language known, just show a simple welcome back without asking
        setState(() {
          _messages.add({
            'role': 'bot',
            'text': _preferredLanguage == 'hinglish' 
                ? "Welcome back! Kaise help kar sakta hoon aaj?" 
                : "Welcome back! How can I help you today?",
          });
        });
        return;
      }
    }
    // If no language saved, ask for it
    _addGreeting();
  }

  void _addGreeting() {
    setState(() {
      _messages.add({
        'role': 'bot',
        'text': "Hello! I'm Coach Fitnophedia. I can create personalized workout & diet plans for you. Would you like to chat in English or Hinglish?",
        'isLanguageChoice': true,
      });
    });
  }

  Future<void> _loadSessionMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentSessionId == null) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      setState(() {
        _messages.clear();
        for (var doc in snapshot.docs) {
          _messages.add(doc.data());
        }
        _isLoading = false;
      });

      // Populate AI Context
      AiService.clearHistory();
      for (var msg in _messages) {
        if (msg['role'] == 'user') {
          AiService.addToHistory(msg['text']);
        } else if (msg['role'] == 'bot') {
          AiService.addBotToHistory(msg['text']);
        }
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading session: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    _speech.stop();
    super.dispose();
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

  Future<void> _saveLanguage(String choice) async {
    final lower = choice.toLowerCase();
    String selected = 'english';
    if (lower.contains('hinglish') || lower.contains('hindi')) {
      selected = 'hinglish';
    }
    
    setState(() => _preferredLanguage = selected);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredLanguage': selected
      }, SetOptions(merge: true));
    }
  }

  Future<void> _ensureSessionExists(String firstMessage) async {
    if (_currentSessionId != null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create new session document
    final sessionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chat_sessions')
        .doc();
    
    _currentSessionId = sessionRef.id;

    await sessionRef.set({
      'title': firstMessage.length > 30 ? '${firstMessage.substring(0, 30)}...' : firstMessage,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'preview': firstMessage,
    });
  }

  Future<void> _saveMessageToSession(Map<String, dynamic> msg) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Ensure session exists before saving message
    if (_currentSessionId == null) {
      await _ensureSessionExists(msg['text'] ?? 'New Chat');
    }

    try {
      // 1. Add message to subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .collection('messages')
          .add({
        ...msg,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update session metadata (lastUpdated, preview)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .update({
        'lastUpdated': FieldValue.serverTimestamp(),
        'preview': msg['text'] ?? 'Image',
      });

    } catch (e) {
      debugPrint("Error saving message: $e");
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => setState(() => _isListening = false),
    );

    if (available) {
      setState(() => _isListening = true);
      final originalText = _controller.text; 
      
      _speech.listen(
        pauseFor: const Duration(seconds: 5), 
        onResult: (val) {
          setState(() {
            if (originalText.isEmpty) {
              _controller.text = val.recognizedWords;
            } else {
              _controller.text = "$originalText ${val.recognizedWords}";
            }
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Handle language choice flow (only for new sessions if not saved)
    if (_messages.isNotEmpty && _messages.length == 1 && _messages[0]['isLanguageChoice'] == true) {
      await _saveLanguage(text);
      if (!mounted) return;
      
      final newMsg = {
        'role': 'bot',
        'text': _preferredLanguage == 'hinglish'
            ? "Perfect! Ab full Hinglish mein baat karte hain! Kya help chahiye?"
            : "Perfect! Let's continue in English. What can I help you with today?",
      };
      
      setState(() {
        _messages.clear();
        _messages.add(newMsg);
      });
      
      // We start the session here with the bot's confirmation
      await _saveMessageToSession(newMsg);
      
      _controller.clear();
      _scrollToBottom();
      return;
    }

    final userMsg = {'role': 'user', 'text': text, 'type': 'text'};
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _messages.add({'role': 'typing'}); 
    });
    
    // Save user message (creates session if needed)
    await _saveMessageToSession(userMsg);
    
    _controller.clear();
    _scrollToBottom();

    // Prepare message for AI
    String modifiedMessage = text;
    if (_preferredLanguage == 'hinglish') {
      modifiedMessage += " (Please reply in Hinglish)";
    }

    try {
      // Optimization: Only fetch/pass exercises if the user asks for a plan/workout
      List<String>? availableExercises;
      final lowerText = modifiedMessage.toLowerCase();
      final isWorkoutRequest = lowerText.contains('plan') || 
                               lowerText.contains('workout') || 
                               lowerText.contains('exercise') ||
                               lowerText.contains('routine') ||
                               lowerText.contains('train') ||
                               lowerText.contains('suggest') ||
                               lowerText.contains('build');

      if (isWorkoutRequest) {
        try {
          final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
          if (workoutProvider.exercises.isNotEmpty) {
            availableExercises = workoutProvider.exercises.map((e) => e.name).toList();
          }
        } catch (e) {
          debugPrint("Could not fetch exercises from provider: $e");
        }
      }

      final result = await AiService().ask(modifiedMessage, availableExercises: availableExercises);

      if (!mounted) return;
      
      final botMsg = {
        'role': 'bot',
        'text': result.replyText,
        'workoutPlan': result.workoutPlan,
        'dietPlan': result.dietPlan,
      };

      setState(() {
        _messages.removeWhere((m) => m['role'] == 'typing'); 
        _isLoading = false;
        _messages.add(botMsg);
      });
      
      await _saveMessageToSession(botMsg);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['role'] == 'typing');
        _isLoading = false;
        _messages.add({
          'role': 'bot',
          'text': "Sorry, something went wrong. Please try again.",
        });
      });
    }
  }

  // --- Image Handling ---
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 600);
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final base64Img = base64Encode(bytes);

    final userMsg = {
      'role': 'user',
      'text': 'Analyze this image',
      'type': 'image',
      'imageBytes': base64Img,
    };

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _messages.add({'role': 'typing'});
    });
    await _saveMessageToSession(userMsg);
    _scrollToBottom();

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    final botMsg = {
      'role': 'bot',
      'text': "I see the image! (Image analysis feature coming soon)",
    };

    setState(() {
      _messages.removeWhere((m) => m['role'] == 'typing');
      _isLoading = false;
      _messages.add(botMsg);
    });
    await _saveMessageToSession(botMsg);
    _scrollToBottom();
  }

  // --- Saving Logic ---
  Future<String?> _fetchUserGymId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['gymId'];
  }

  Future<void> _promptSaveDialog(Map<String, dynamic>? workout, Map<String, dynamic>? diet) async {
    if (workout == null && diet == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Plan"),
        content: const Text("Would you like to save this plan to your profile?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          if (workout != null)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _savePlanToCollection('workout_plans', workout);
              },
              child: const Text("Save Workout"),
            ),
          if (diet != null)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _savePlanToCollection('diet_plans', diet);
              },
              child: const Text("Save Diet"),
            ),
        ],
      ),
    );
  }

  Future<String?> _savePlanToCollection(String collectionName, Map<String, dynamic> plan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to save plans')));
      return null;
    }

    try {
      final gymId = await _fetchUserGymId();
      if (gymId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym membership not found')));
        return null;
      }

      final now = DateTime.now();
      final String dateStr = DateFormat('yyyy-MM-dd').format(now);
      final String name = (plan['name'] ?? plan['title'] ?? 'Untitled Plan').toString();
      
      final payload = <String, dynamic>{
        'name': name,
        'plan': plan,
        'date': dateStr,
        'savedBy': 'ai',
        'source': 'ai_coach',
        'savedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .collection(collectionName)
          .add(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$collectionName saved successfully!'), backgroundColor: const Color(0xFF00E676)),
        );
      }
      return 'success';
    } catch (e) {
      debugPrint('Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
      return null;
    }
  }

  // --- UI Builders ---
  Widget _buildTypingBubble() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 60, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: TypingDots(controller: _typingController, isDark: isDark),
      ),
    );
  }

  Widget _buildUserBubble(Map<String, dynamic> msg) {
    final isImage = msg['type'] == 'image';
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(msg['imageBytes']),
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(
              msg['text'] ?? '',
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
        margin: const EdgeInsets.only(right: 20, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        isDark ? 'assets/login_logo.png' : 'assets/loginblack_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: MarkdownBody(
                      data: msg['text'] ?? '',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          height: 1.6,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00E676),
                        ),
                        listBullet: TextStyle(color: const Color(0xFF00E676)),
                        h1: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF00E676)),
                        h2: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF00E676)),
                        h3: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasPlan)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: PlanCard(
                  workoutPlan: msg['workoutPlan'],
                  dietPlan: msg['dietPlan'],
                  onSave: () {
                    _promptSaveDialog(msg['workoutPlan'], msg['dietPlan']);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suggestions = _preferredLanguage == 'hinglish'
        ? [
            {'icon': Icons.fitness_center, 'text': 'Workout plan banao'},
            {'icon': Icons.restaurant_menu, 'text': 'Diet chart chahiye'},
            {'icon': Icons.monitor_weight, 'text': 'Weight loss tips'},
            {'icon': Icons.flash_on, 'text': 'Motivation chahiye'},
          ]
        : [
            {'icon': Icons.fitness_center, 'text': 'Create workout plan'},
            {'icon': Icons.restaurant_menu, 'text': 'Give me diet chart'},
            {'icon': Icons.monitor_weight, 'text': 'Weight loss tips'},
            {'icon': Icons.flash_on, 'text': 'Motivate me'},
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: suggestions.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(s['icon'] as IconData, size: 16, color: const Color(0xFF00E676)),
              label: Text(s['text'] as String),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              labelStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                _controller.text = s['text'] as String;
                _sendMessage();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSuggestions = _messages.length <= 2 && !_isLoading;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSuggestions) _buildSuggestionChips(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF00E676),
                    onPressed: _showImageSourceDialog,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: "Ask Coach Fitnophedia...",
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                            color: _isListening ? Colors.red : Colors.grey,
                            onPressed: _isListening ? _stopListening : _startListening,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00C853)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E676), width: 2),
              ),
              child: ClipOval(
                child: Container(
                  width: 32,
                  height: 32,
                  color: isDark ? Colors.black : Colors.white, // Match background
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    isDark ? 'assets/login_logo.png' : 'assets/loginblack_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Fitnophedia AI",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            color: Colors.grey,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add), // New Chat Button
            tooltip: "New Chat",
            color: Colors.grey,
            onPressed: () {
              setState(() {
                _messages.clear();
                AiService.clearHistory();
                _currentSessionId = null;
                _isNewSession = true;
                _checkLanguageAndInit();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
        mainAxisSize: MainAxisSize.min,
        children: [0.0, 0.2, 0.4].map((delay) {
          return Opacity(
            opacity: ((controller.value + (1 - delay)) % 1.0).clamp(0.2, 1.0),
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}