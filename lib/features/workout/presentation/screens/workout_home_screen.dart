import 'dart:convert';
import 'package:flutter/material.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadAllWorkoutProgress();
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadAllWorkoutProgress();
  }

  Future<void> _loadAllWorkoutProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, double> progressMap = {};
      
      final prefix = "workout_draft_${widget.memberId}_${widget.gymId}_";
      
      for (String key in keys) {
        if (key.startsWith(prefix)) {
          final workoutId = key.replaceFirst(prefix, "");
          final draftString = prefs.getString(key);
          if (draftString != null) {
            final draft = jsonDecode(draftString);
            final Map<String, dynamic> logs = Map<String, dynamic>.from(draft['logs']);
            
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
        });
      }
    } catch (e) {
      debugPrint("Error loading workout progress: $e");
    }
  }

  Future<void> _fetchUserData() async {
    debugPrint("🔍 _fetchUserData called");
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint("👤 User found: ${user.uid}");
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? "Athlete";
        });
      }

      if (widget.gymId.isEmpty || widget.memberId.isEmpty) {
        debugPrint("⚠️ GymId or MemberId is empty. Skipping streak fetch.");
        return;
      }

      // Fetch Streak
      debugPrint("🔍 Fetching streak for gym: ${widget.gymId}, member: ${widget.memberId}");
      try {
        final streak = await StreakService.instance.getEffectiveStreak(widget.gymId, widget.memberId);
        debugPrint("✅ Streak fetched: $streak");
        setState(() {
          _streakDays = streak;
        });
      } catch (e) {
        debugPrint("❌ Error fetching streak: $e");
      }
    } else {
      debugPrint("❌ No user logged in");
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
                          const Text(
                            "Upper Body Power",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Iconsax.timer_1, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              const Text("45 min",
                                  style: TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Iconsax.flash_1, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              const Text("Intermediate",
                                  style: TextStyle(color: Colors.grey, fontFamily: 'Outfit', fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Navigate to the first available workout plan in the list
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
                          ).then((_) => _loadAllWorkoutProgress());
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
                if (_workoutProgress.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Overall Progress",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Outfit'),
                      ),
                      Text(
                        "${_workoutProgress.isNotEmpty ? (_workoutProgress.values.cast<double>().reduce((a, b) => a > b ? a : b) * 100).toInt() : 0}%",
                        style: const TextStyle(
                            color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                   ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _workoutProgress.isNotEmpty ? _workoutProgress.values.cast<double>().reduce((a, b) => a > b ? a : b) : 0.0,
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
            onTap: () => Navigator.pushNamed(context, AppRoutes.createWorkout),
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
    final days = ["M", "T", "W", "T", "F", "S", "S"];
    final todayIndex = DateTime.now().weekday - 1;

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
                  "Hypertrophy Phase 1",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Week 4 of 12",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.calendar_1, size: 18, color: Colors.grey),
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
  Widget _buildCoachInsight(bool isDark) {
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
            child: const Icon(Iconsax.lamp_on, color: Color(0xFF2196F3), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 4),
                Text(
                  "You crushed your last leg day! Focus on slow eccentrics today to maximize growth.",
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
              // Dismiss logic
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // --- 6. Your Workouts Section ---
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
                // Navigate to all saved plans
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
          height: 200, // Increased height for progress bar safety
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('gyms')
                .doc(widget.gymId)
                .collection('members')
                .doc(widget.memberId)
                .collection('workout_plans')
                .limit(10)
                .snapshots(),
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
                  return _buildWorkoutCard(isDark, data);
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
              _buildWorkoutCard(isDark, {
                'id': 'feat_1',
                'name': 'Power Lifting 101',
                'exercises': List.generate(8, (i) => {'name': 'Squat'}),
                'source': 'ai',
              }),
              const SizedBox(width: 16),
              _buildWorkoutCard(isDark, {
                'id': 'feat_2',
                'name': 'Bodyweight Burner',
                'exercises': List.generate(6, (i) => {'name': 'Pushups'}),
                'source': 'custom',
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWorkoutCard(bool isDark) {
    return Container(
      width: 280,
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

  Widget _buildWorkoutCard(bool isDark, Map<String, dynamic> data) {
    // Handle different field names from AI vs Custom
    final title = data['planName'] ?? data['name'] ?? "Untitled Workout";
    
    final timestamp = data['createdAt'] ?? data['savedAt'];
    final date = timestamp != null 
        ? DateFormat('MMM d').format((timestamp as Timestamp).toDate()) 
        : "Unknown Date";

    // Handle exercises list location
    int exerciseCount = 0;
    if (data['exercises'] != null) {
      // Custom workout (flat list)
      exerciseCount = (data['exercises'] as List).length;
    } else if (data['plan'] != null) {
      // AI Plan
      if (data['plan']['schedule'] != null) {
        // Multi-day schedule
        for (var day in (data['plan']['schedule'] as List)) {
          if (day['exercises'] != null) {
            exerciseCount += (day['exercises'] as List).length;
          }
        }
      } else if (data['plan']['exercises'] != null) {
        // Single day AI plan
        exerciseCount = (data['plan']['exercises'] as List).length;
      }
    }
    
    // Determine Tag
    final isAi = data['source'] == 'ai_coach' || data['source'] == 'ai' || data.containsKey('aiSessionId');
    final tagLabel = isAi ? "AI Plan" : "Custom";
    final tagColor = isAi ? Colors.purpleAccent : Colors.orange;

    // Determine Image
    ImageProvider? bgImageProvider;
    
    // 1. Try to get first exercise image
    String? firstExerciseName;
    if (data['exercises'] != null && (data['exercises'] as List).isNotEmpty) {
      firstExerciseName = data['exercises'][0]['name'];
    } else if (data['plan'] != null) {
       if (data['plan']['schedule'] != null && (data['plan']['schedule'] as List).isNotEmpty) {
          final day = data['plan']['schedule'][0];
          if (day['exercises'] != null && (day['exercises'] as List).isNotEmpty) {
             firstExerciseName = day['exercises'][0]['name'];
          }
       } else if (data['plan']['exercises'] != null && (data['plan']['exercises'] as List).isNotEmpty) {
          firstExerciseName = data['plan']['exercises'][0]['name'];
       }
    }

    if (firstExerciseName != null) {
       try {
         final provider = Provider.of<WorkoutProvider>(context, listen: false);
         final aiName = firstExerciseName.toString().toLowerCase().trim();
         
         // Try exact match
         var exercise = provider.exercises.firstWhere(
            (e) => e.name.toLowerCase() == aiName,
            orElse: () => provider.exercises.first,
         );

         // Try fuzzy match if exact failed
         if (exercise.name.toLowerCase() != aiName) {
            try {
               exercise = provider.exercises.firstWhere((e) {
                 final dbName = e.name.toLowerCase();
                 if (aiName.length < 4 || dbName.length < 4) return false;
                 return dbName.contains(aiName) || aiName.contains(dbName);
               });
            } catch (_) {}
         }
         
         if (exercise.imageUrl != null) {
            bgImageProvider = CachedNetworkImageProvider(exercise.imageUrl!);
         }
       } catch (_) {}
    }

    // 2. Fallback to asset logic
    if (bgImageProvider == null) {
        String assetPath = 'assets/exercise/upper_body.jpeg';
        final lowerTitle = title.toString().toLowerCase();
        if (lowerTitle.contains('leg') || lowerTitle.contains('lower')) assetPath = 'assets/exercise/legs.jpeg';
        else if (lowerTitle.contains('ab') || lowerTitle.contains('core')) assetPath = 'assets/exercise/abs.jpeg';
        else if (lowerTitle.contains('bicep') || lowerTitle.contains('arm')) assetPath = 'assets/exercise/biceps.jpeg';
        else if (lowerTitle.contains('tricep')) assetPath = 'assets/exercise/triceps.jpeg';
        else if (lowerTitle.contains('push') || lowerTitle.contains('chest')) assetPath = 'assets/exercise/pushups.jpeg';
        else if (lowerTitle.contains('cardio') || lowerTitle.contains('rope')) assetPath = 'assets/exercise/rope.jpeg';
        bgImageProvider = AssetImage(assetPath);
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavedWorkoutDetailScreen(
              workoutData: data,
              gymId: widget.gymId,
              memberId: widget.memberId,
            ),
          ),
        );
        _loadAllWorkoutProgress(); // Refresh when back
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.grey[900], // Fallback color
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. Background Image with Fade In
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: bgImageProvider is CachedNetworkImageProvider
                    ? CachedNetworkImage(
                        imageUrl: (bgImageProvider as CachedNetworkImageProvider).url,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 700),
                        placeholder: (context, url) => Container(color: Colors.grey[800]),
                        errorWidget: (context, url, error) => Image.asset('assets/exercise/upper_body.jpeg', fit: BoxFit.cover),
                      )
                    : Image(image: bgImageProvider, fit: BoxFit.cover),
              ),
            ),
            
            // 2. Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.calendar_1, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Type Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tagLabel,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.activity, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                "$exerciseCount Exercises",
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          if (data['id'] != null && _workoutProgress.containsKey(data['id'].toString()))
                            Text(
                              "${(_workoutProgress[data['id'].toString()]! * 100).toInt()}%",
                              style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Premium Progress Bar at Bottom Edge
            if (data['id'] != null && _workoutProgress.containsKey(data['id'].toString()))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: LinearProgressIndicator(
                    value: _workoutProgress[data['id'].toString()],
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                    minHeight: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
