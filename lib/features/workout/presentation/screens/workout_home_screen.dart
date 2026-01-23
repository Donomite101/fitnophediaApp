import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../routes/app_routes.dart';
import '../../data/providers/workout_provider.dart';
import 'saved_workout_detail_screen.dart';
import '../../../member/streak/service/streak_service.dart';
import '../../../member/chat/ai_service.dart';
import '../../data/services/recovery_service.dart';
import '../widgets/unified_workout_card.dart';
import 'workout_create_screen.dart';
import 'workout_list_screen.dart';

class WorkoutHomeScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const WorkoutHomeScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<WorkoutHomeScreen> createState() => _WorkoutHomeScreenState();
}

class _WorkoutHomeScreenState extends State<WorkoutHomeScreen> {
  String _userName = "Athlete";
  int _streakDays = 0; // Default to 0
  int _recoveryScore = 85; // Mocked
  Map<String, double> _workoutProgress = {};
  bool _isInitialized = false;
  String _lastActiveWorkoutName = "Upper Body Power";
  String _lastActiveWorkoutDifficulty = "Intermediate";
  String? _lastActiveWorkoutId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadAllWorkoutProgress();
      _isInitialized = true;
    }
  }

  late Stream<QuerySnapshot> _workoutPlansStream;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchWorkoutTemplates();
    _loadAllWorkoutProgress();
    
    // Initialize stream once to prevent blinking on rebuilds
    _workoutPlansStream = FirebaseFirestore.instance
        .collection('gyms')
        .doc(widget.gymId)
        .collection('members')
        .doc(widget.memberId)
        .collection('workout_plans')
        .limit(10)
        .snapshots();
  }

  Future<void> _loadAllWorkoutProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, double> progressMap = {};
      
      final prefix = "workout_draft_${widget.memberId}_${widget.gymId}_";
      
      int latestTimestamp = 0;
      String? latestName;
      String? latestId;
      String? latestDifficulty;

      for (String key in keys) {
        if (key.startsWith(prefix)) {
          final workoutId = key.replaceFirst(prefix, "");
          final draftString = prefs.getString(key);
          if (draftString != null) {
            final draft = jsonDecode(draftString);
            final Map<String, dynamic> logs = Map<String, dynamic>.from(draft['logs']);
            final int timestamp = draft['timestamp'] ?? 0;
            
            // Track latest workout
            if (timestamp > latestTimestamp) {
              latestTimestamp = timestamp;
              latestName = draft['workoutName'];
              latestId = workoutId;
              latestDifficulty = draft['difficulty'];
            }

            int totalSets = 0;
            int completedSets = 0;
            
            logs.forEach((key, value) {
              final List sets = value;
              totalSets += sets.length;
              completedSets += sets.where((s) => s['completed'] == true).length;
            });
            
            if (totalSets > 0) {
              progressMap[workoutId] = completedSets / totalSets;
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _workoutProgress = progressMap;
          if (latestName != null) {
            _lastActiveWorkoutName = latestName;
            _lastActiveWorkoutId = latestId;
            if (latestDifficulty != null) {
              _lastActiveWorkoutDifficulty = latestDifficulty;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading workout progress: $e");
    }
  }

  StreamSubscription<DocumentSnapshot>? _memberSubscription;

  @override
  void dispose() {
    _memberSubscription?.cancel();
    super.dispose();
  }

  DateTime? _startDate;

  Future<void> _fetchUserData() async {
    debugPrint("🔍 _fetchUserData called");
    
    if (widget.gymId.isEmpty || widget.memberId.isEmpty) {
      debugPrint("⚠️ GymId or MemberId is empty. Skipping user data fetch.");
      return;
    }

    // 1. Listen to Member Profile Changes (Real-time Name)
    _memberSubscription?.cancel();
    _memberSubscription = FirebaseFirestore.instance
        .collection('gyms')
        .doc(widget.gymId)
        .collection('members')
        .doc(widget.memberId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          final firstName = data['firstName'] as String? ?? "";
          final lastName = data['lastName'] as String? ?? "";
          final fullName = "$firstName $lastName".trim();
          
          setState(() {
            _userName = fullName.isNotEmpty ? fullName : "Athlete";
          });
          debugPrint("👤 User name updated: $_userName");
        }
      }
    }, onError: (e) {
      debugPrint("❌ Error listening to member profile: $e");
    });

    // 2. Fetch Streak & Recovery (Keep as one-time fetch for now, or move to stream if needed)
    try {
      debugPrint("🔍 Fetching streak for gym: ${widget.gymId}, member: ${widget.memberId}");
      final streak = await StreakService.instance.getEffectiveStreak(widget.gymId, widget.memberId);
      debugPrint("✅ Streak fetched: $streak");
      
      final recovery = await RecoveryService.instance.getRecoveryScore(widget.gymId, widget.memberId);
      debugPrint("✅ Recovery fetched: $recovery");

      // 3. Fetch First Workout Date for Roadmap
      DateTime? start;
      try {
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(widget.gymId)
            .collection('members')
            .doc(widget.memberId)
            .collection('attendance')
            .orderBy('timestamp', descending: false)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          final data = attendanceSnapshot.docs.first.data();
          if (data['timestamp'] != null) {
            start = (data['timestamp'] as Timestamp).toDate();
          }
        }
      } catch (e) {
        debugPrint("❌ Error fetching start date: $e");
      }

      if (mounted) {
        setState(() {
          _streakDays = streak;
          _recoveryScore = recovery;
          _startDate = start;
        });
        
        // 4. Fetch AI Tip (after basic data is loaded)
        _fetchAiCoachTip();
      }
    } catch (e) {
      debugPrint("❌ Error fetching streak/recovery: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Consistency Signals
              _buildHeader(isDark, textColor),
              const SizedBox(height: 24),

              // 2. The "Today" Card (Hero) - Compact
              _buildTodayHeroCard(isDark),
              const SizedBox(height: 16),

              // 3. Quick Actions (Library & Custom)
              _buildQuickActions(isDark),
              const SizedBox(height: 24),

              // 4. Program Roadmap
              _buildProgramRoadmap(isDark, textColor),
              const SizedBox(height: 24),

              // 5. Coach Insight
              _buildCoachInsight(isDark),
              const SizedBox(height: 24),

              // 6. Your Workouts
              _buildYourWorkouts(isDark, textColor),
              const SizedBox(height: 24),

              // 7. Explore Templates
              _buildTemplateSection(isDark, textColor),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Header ---
  Widget _buildHeader(bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, $_userName",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: isDark ? Colors.grey : Colors.grey[600],
              ),
            ),
            Row(
              children: [
                Text(
                  "Ready to Train?",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                Text(
                  "$_streakDays",
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00E676).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "$_recoveryScore%",
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                  fontSize: 14,
                ),
              ),
              const Text(
                "Recovery",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  color: Color(0xFF00E676),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. Today Hero Card (Compact) ---
  Widget _buildTodayHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastActiveWorkoutName,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Iconsax.timer_1, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              const Text("Resume", // Changed from 45 min since it's likely a resume
                                  style: TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Iconsax.flash_1, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              Text(_lastActiveWorkoutDifficulty, // Dynamic Difficulty
                                  style: const TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_lastActiveWorkoutId != null) {
                          // Fetch the specific workout
                          final doc = await FirebaseFirestore.instance
                              .collection('gyms')
                              .doc(widget.gymId)
                              .collection('members')
                              .doc(widget.memberId)
                              .collection('workout_plans')
                              .doc(_lastActiveWorkoutId)
                              .get();

                          if (doc.exists && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SavedWorkoutDetailScreen(
                                  workoutData: doc.data() as Map<String, dynamic>,
                                  gymId: widget.gymId,
                                  memberId: widget.memberId,
                                ),
                              ),
                            ).then((_) {
                              _loadAllWorkoutProgress();
                              _fetchUserData();
                            });
                            return;
                          }
                        }

                        // Fallback: Navigate to the first available workout plan
                        final snapshot = await FirebaseFirestore.instance
                            .collection('gyms')
                            .doc(widget.gymId)
                            .collection('members')
                            .doc(widget.memberId)
                            .collection('workout_plans')
                            .limit(1)
                            .get();

                        if (snapshot.docs.isNotEmpty && mounted) {
                          final plan = snapshot.docs.first;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavedWorkoutDetailScreen(
                                workoutData: plan.data() as Map<String, dynamic>,
                                gymId: widget.gymId,
                                memberId: widget.memberId,
                              ),
                            ),
                          ).then((_) {
                            _loadAllWorkoutProgress();
                            _fetchUserData(); 
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "START",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_lastActiveWorkoutId != null && _workoutProgress.containsKey(_lastActiveWorkoutId)) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Overall Progress",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Outfit'),
                      ),
                      Text(
                        "${(_workoutProgress[_lastActiveWorkoutId]! * 100).toInt()}%",
                        style: const TextStyle(
                            color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                   ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _workoutProgress[_lastActiveWorkoutId]!,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Quick Actions ---
  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildAlternativeChip(
            isDark,
            icon: Iconsax.element_3,
            label: "Exercise Library",
            onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseLibrary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAlternativeChip(
            isDark,
            icon: Iconsax.add_circle,
            label: "Create Custom",
            onTap: () {
               // Direct push to avoid route generator issues
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (_) => const CreateWorkoutScreen()),
               );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeChip(bool isDark, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.grey : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. Program Roadmap ---
  Widget _buildProgramRoadmap(bool isDark, Color textColor) {
    // Calculate dynamic progress
    int currentWeek = 1;
    int currentDay = 1;
    
    final days = ["M", "T", "W", "T", "F", "S", "S"];
    final todayIndex = DateTime.now().weekday - 1;

    // Calculate progress based on the first workout date (Program Start)
    // This continues counting even if the streak is broken.
    if (_startDate != null) {
      final now = DateTime.now();
      // Reset time components to ensure day difference is accurate
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      
      final difference = today.difference(start).inDays;
      
      if (difference >= 0) {
        currentWeek = (difference / 7).floor() + 1;
        currentDay = (difference % 7) + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Week $currentWeek • Day $currentDay",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Keep pushing forward!",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 4 / 12,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),

        // Days Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final isToday = index == todayIndex;
            final isPast = index < todayIndex;
            final isRest = index == 6; // Mock Sunday as rest
            
            return Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: isToday 
                        ? const Color(0xFF00E676) 
                        : (isDark ? Colors.grey : Colors.grey[600]),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday 
                        ? const Color(0xFF00E676) 
                        : (isPast 
                            ? (isDark ? Colors.white10 : Colors.grey[200]) 
                            : Colors.transparent),
                    border: Border.all(
                      color: isToday 
                          ? const Color(0xFF00E676) 
                          : (isDark ? Colors.white24 : Colors.grey[300]!),
                    ),
                  ),
                  child: Center(
                    child: isPast
                        ? Icon(Iconsax.tick_circle, size: 14, color: isDark ? Colors.white : Colors.black)
                        : (isRest 
                            ? Icon(Iconsax.moon, size: 14, color: Colors.grey) 
                            : Text(
                                "${DateTime.now().subtract(Duration(days: todayIndex - index)).day}",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isToday 
                                      ? Colors.black 
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                              )),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // --- 5. Coach Insight ---
  bool _showCoachTip = true;
  String? _aiCoachTip;
  bool _isLoadingTip = false;

  final List<String> _coachTips = [
    "Consistency is key! Even a short workout is better than none.",
    "Hydrate! Drink water before, during, and after your workout.",
    "Focus on form over weight. Quality reps build quality muscle.",
    "Rest days are when your muscles grow. Don't skip them!",
    "Protein is your friend. Aim for 1.6g-2.2g per kg of body weight.",
    "Sleep is the best recovery tool. Aim for 7-9 hours.",
    "Warm up properly to prevent injury and improve performance.",
    "Track your progress. You can't improve what you don't measure.",
    "Listen to your body. If it hurts (bad pain), stop.",
    "Progressive overload: try to do a little more than last time.",
    "Eat whole foods. Fuel your body with high-quality nutrients.",
    "Stretch after your workout to improve flexibility and recovery.",
    "Don't compare your chapter 1 to someone else's chapter 20.",
    "Visualize your success. Mental preparation is powerful.",
    "Compound exercises give you the most bang for your buck.",
    "Control the eccentric (lowering) phase for more muscle growth.",
    "Breathe! Exhale on the exertion, inhale on the release.",
    "Set realistic goals. Small wins add up to big results.",
    "Find a workout buddy. Accountability increases consistency.",
    "Enjoy the process! Fitness is a journey, not a destination."
  ];

  List<Map<String, dynamic>> _workoutTemplates = [];
  bool _isLoadingTemplates = false;

  Future<void> _fetchWorkoutTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final String response = await rootBundle.loadString('assets/workouts/workout_templates.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _workoutTemplates = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("Error loading workout templates: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  Future<void> _fetchAiCoachTip() async {
    if (_aiCoachTip != null) return; // Already fetched

    setState(() => _isLoadingTip = true);

    try {
      // 1. Fetch Last Workout
      Map<String, dynamic>? lastWorkout;
      final snapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .collection('attendance')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        lastWorkout = snapshot.docs.first.data();
      }

      // 2. Call AI Service
      final tip = await AiService().getGenZCoachTip(lastWorkout);
      
      if (mounted && tip != null && tip.isNotEmpty) {
        setState(() {
          _aiCoachTip = tip;
        });
      }
    } catch (e) {
      debugPrint("Error fetching AI tip: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTip = false);
    }
  }

  Widget _buildCoachInsight(bool isDark) {
    if (!_showCoachTip) return const SizedBox.shrink();

    // Fallback to static tip if AI tip is not ready
    final dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));
    final tipIndex = dayOfYear % _coachTips.length;
    final staticTip = _coachTips[tipIndex];
    
    final displayTip = _aiCoachTip ?? staticTip;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: _isLoadingTip 
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2196F3)))
                : const Icon(Iconsax.lamp_on, color: Color(0xFF2196F3), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Coach Tip",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                        fontSize: 12,
                      ),
                    ),
                    if (_aiCoachTip != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "AI",
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayTip,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Iconsax.close_circle, size: 16, color: isDark ? Colors.grey : Colors.black45),
            onPressed: () {
              setState(() {
                _showCoachTip = false;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // --- 6. Explore Templates Section ---
  Widget _buildTemplateSection(bool isDark, Color textColor) {
    if (_workoutTemplates.isEmpty && !_isLoadingTemplates) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0), // Already padded by parent
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Explore Templates",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutListScreen(
                        title: "Explore Templates",
                        staticWorkouts: _workoutTemplates,
                        gymId: widget.gymId,
                        memberId: widget.memberId,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingTemplates)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 180, // Height for the horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _workoutTemplates.length,
              itemBuilder: (context, index) {
                final template = _workoutTemplates[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 260, // Fixed width for consistency
                    child: UnifiedWorkoutCard(
                      data: {
                        'planName': template['name'],
                        'level': template['level'],
                        'category': template['category'],
                        'tags': template['tags'],
                        'exercises': template['exercises'],
                        'source': 'template',
                        'id': template['id'],
                        // Mock date for display
                        'savedAt': Timestamp.now(), 
                      },
                      gymId: widget.gymId,
                      memberId: widget.memberId,
                      isDark: isDark,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- 7. Your Workouts Section ---
  Widget _buildYourWorkouts(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your Workouts",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutListScreen(
                      title: "Your Workouts",
                      workoutStream: FirebaseFirestore.instance
                          .collection('gyms')
                          .doc(widget.gymId)
                          .collection('members')
                          .doc(widget.memberId)
                          .collection('workout_plans')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      gymId: widget.gymId,
                      memberId: widget.memberId,
                    ),
                  ),
                );
              },
              child: const Text(
                "See All",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 180, // Matched with explore templates
          child: StreamBuilder<QuerySnapshot>(
            stream: _workoutPlansStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint("❌ Error loading plans: ${snapshot.error}");
                return Center(child: Text("Error loading plans", style: TextStyle(color: textColor)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
              }

              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return _buildEmptyWorkoutCard(isDark);
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  data['id'] = docs[index].id; // Inject ID for deletion
                  return UnifiedWorkoutCard(
                    data: data,
                    gymId: widget.gymId,
                    memberId: widget.memberId,
                    isDark: isDark,
                    workoutProgress: _workoutProgress,
                    onRefresh: () {
                      _loadAllWorkoutProgress();
                      _fetchUserData();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 7. Featured Workouts ---
  Widget _buildFeaturedWorkouts(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Featured Workouts",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200, // Increased height
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [

              UnifiedWorkoutCard(
                data: {
                  'id': 'feat_1',
                  'name': 'Power Lifting 101',
                  'exercises': List.generate(8, (i) => {'name': 'Squat'}),
                  'source': 'ai',
                },
                gymId: widget.gymId,
                memberId: widget.memberId,
                isDark: isDark,
                workoutProgress: _workoutProgress,
              ),
              const SizedBox(width: 16),
              UnifiedWorkoutCard(
                data: {
                  'id': 'feat_2',
                  'name': 'Bodyweight Burner',
                  'exercises': List.generate(6, (i) => {'name': 'Pushups'}),
                  'source': 'custom',
                },
                gymId: widget.gymId,
                memberId: widget.memberId,
                isDark: isDark,
                workoutProgress: _workoutProgress,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWorkoutCard(bool isDark) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.add_circle, size: 32, color: isDark ? Colors.grey : Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            "No saved workouts yet",
            style: TextStyle(
              fontFamily: 'Outfit',
              color: isDark ? Colors.grey : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }


}
