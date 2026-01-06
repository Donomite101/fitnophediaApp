import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../data/providers/workout_provider.dart';
import 'workout_log_screen.dart';

class SavedWorkoutDetailScreen extends StatelessWidget {
  final Map<String, dynamic> workoutData;
  final String? gymId;
  final String? memberId;

  const SavedWorkoutDetailScreen({
    Key? key,
    required this.workoutData,
    this.gymId,
    this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;

    final title = workoutData['planName'] ?? workoutData['name'] ?? "Untitled Workout";
    final isAi = workoutData['source'] == 'ai_coach' || workoutData['source'] == 'ai';
    
    // Get the same image used in the workout card
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    ImageProvider bgImageProvider;
    
    // 1. Try to get first exercise image (same logic as workout card)
    String? firstExerciseName;
    if (workoutData['exercises'] != null && (workoutData['exercises'] as List).isNotEmpty) {
      firstExerciseName = workoutData['exercises'][0]['name'];
    } else if (workoutData['plan'] != null) {
       if (workoutData['plan']['schedule'] != null && (workoutData['plan']['schedule'] as List).isNotEmpty) {
          final day = workoutData['plan']['schedule'][0];
          if (day['exercises'] != null && (day['exercises'] as List).isNotEmpty) {
             firstExerciseName = day['exercises'][0]['name'];
          }
       } else if (workoutData['plan']['exercises'] != null && (workoutData['plan']['exercises'] as List).isNotEmpty) {
          firstExerciseName = workoutData['plan']['exercises'][0]['name'];
       }
    }

    if (firstExerciseName != null) {
       try {
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
         } else {
           bgImageProvider = _getFallbackAssetImage(title);
         }
       } catch (_) {
         bgImageProvider = _getFallbackAssetImage(title);
       }
    } else {
      // 2. Fallback to asset logic based on title (same as workout card)
      bgImageProvider = _getFallbackAssetImage(title);
    }
    
    // Calculate stats
    int totalExercises = 0;
    int totalSets = 0;
    
    if (workoutData['exercises'] != null) {
      final exercises = workoutData['exercises'] as List;
      totalExercises = exercises.length;
      for (var ex in exercises) {
        totalSets += _parseIntValue(ex['sets'], 3);
      }
    } else if (workoutData['plan'] != null && workoutData['plan']['schedule'] != null) {
      final schedule = workoutData['plan']['schedule'] as List;
      for (var day in schedule) {
        if (day['exercises'] != null) {
          totalExercises += (day['exercises'] as List).length;
          for (var ex in day['exercises']) {
            totalSets += _parseIntValue(ex['sets'], 3);
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (workoutData['id'] != null)
            IconButton(
              icon: const Icon(Iconsax.trash, color: Colors.redAccent),
              onPressed: () => _deleteWorkout(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Compact Header Stats
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAi ? Colors.purpleAccent : Colors.orange).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAi ? Iconsax.cpu : Iconsax.edit_2,
                        size: 14,
                        color: isAi ? Colors.purpleAccent : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAi ? "AI" : "CUSTOM",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAi ? Colors.purpleAccent : Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stats
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCompactStat(Iconsax.activity, totalExercises.toString(), "Exercises", isDark),
                      Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),
                      _buildCompactStat(Iconsax.flash_1, totalSets.toString(), "Sets", isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (workoutData['plan'] != null && workoutData['plan']['schedule'] != null)
                    _buildCompactSchedule(context, workoutData['plan']['schedule'], isDark, textColor)
                  else if (workoutData['exercises'] != null)
                    _buildCompactExerciseGrid(context, workoutData['exercises'], isDark, textColor)
                  else if (workoutData['plan'] != null && workoutData['plan']['exercises'] != null)
                    _buildCompactExerciseGrid(context, workoutData['plan']['exercises'], isDark, textColor)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Iconsax.activity, size: 48, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              "No exercises found",
                              style: TextStyle(color: textColor.withOpacity(0.5), fontFamily: 'Outfit'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Fixed Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () {
                  if (gymId != null && memberId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutLogScreen(
                          gymId: gymId!,
                          memberId: memberId!,
                          workoutData: workoutData,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User info missing. Cannot start workout.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Iconsax.play5, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "START WORKOUT",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, String label, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00E676)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSchedule(BuildContext context, List schedule, bool isDark, Color textColor) {
    return Column(
      children: schedule.map((day) {
        final dayName = day['day'] ?? "Day";
        final focus = day['focus'] ?? "Workout";
        final exercises = day['exercises'] as List? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              // Compact Day Header
              InkWell(
                onTap: () {
                  if (gymId != null && memberId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutLogScreen(
                          gymId: gymId!,
                          memberId: memberId!,
                          workoutData: workoutData,
                          initialDayName: dayName,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Iconsax.calendar_2, color: Color(0xFF00E676), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                            Text(
                              focus,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                color: Color(0xFF00E676),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Iconsax.play5, size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              "START",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Compact Exercise Grid
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildCompactExerciseGrid(context, exercises, isDark, textColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompactExerciseGrid(BuildContext context, List exercises, bool isDark, Color textColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        return _buildCompactExerciseCard(context, exercises[index], isDark, textColor);
      },
    );
  }

  Widget _buildCompactExerciseCard(BuildContext context, Map<String, dynamic> ex, bool isDark, Color textColor) {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    String? imageUrl;
    
    try {
      final aiName = (ex['name'] ?? "").toString().toLowerCase().trim();
      var exercise = provider.exercises.firstWhere(
        (e) => e.name.toLowerCase() == aiName,
        orElse: () => provider.exercises.first,
      );

      if (exercise.name.toLowerCase() != aiName) {
        try {
          exercise = provider.exercises.firstWhere((e) {
            final dbName = e.name.toLowerCase();
            if (aiName.length < 4 || dbName.length < 4) return false;
            return dbName.contains(aiName) || aiName.contains(dbName);
          });
        } catch (_) {}
      }
      
      imageUrl = exercise.imageUrl;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              color: const Color(0xFF00E676).withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Iconsax.activity,
                        color: Color(0xFF00E676),
                        size: 32,
                      ),
                    )
                  : const Icon(Iconsax.activity, color: Color(0xFF00E676), size: 32),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ex['name'] ?? "Exercise",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildMiniChip("${ex['sets']}", Iconsax.layer, isDark),
                      _buildMiniChip("${ex['reps']}", Iconsax.repeate_music, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: const Color(0xFF00E676)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to safely parse int values that could be String or int
  int _parseIntValue(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  // Get fallback asset image based on title (same as workout card)
  ImageProvider _getFallbackAssetImage(String title) {
    String assetPath = 'assets/exercise/upper_body.jpeg';
    final lowerTitle = title.toString().toLowerCase();
    if (lowerTitle.contains('leg') || lowerTitle.contains('lower')) {
      assetPath = 'assets/exercise/legs.jpeg';
    } else if (lowerTitle.contains('ab') || lowerTitle.contains('core')) {
      assetPath = 'assets/exercise/abs.jpeg';
    } else if (lowerTitle.contains('bicep') || lowerTitle.contains('arm')) {
      assetPath = 'assets/exercise/biceps.jpeg';
    } else if (lowerTitle.contains('tricep')) {
      assetPath = 'assets/exercise/triceps.jpeg';
    } else if (lowerTitle.contains('push') || lowerTitle.contains('chest')) {
      assetPath = 'assets/exercise/pushups.jpeg';
    } else if (lowerTitle.contains('cardio') || lowerTitle.contains('rope')) {
      assetPath = 'assets/exercise/rope.jpeg';
    }
    return AssetImage(assetPath);
  }

  Future<void> _deleteWorkout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Workout",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to delete this workout plan?",
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete", style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final gymId = userDoc.data()?['gymId'];
      
      if (gymId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Gym ID not found")),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .collection('workout_plans')
          .doc(workoutData['id'])
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Workout deleted successfully"),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error deleting workout: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e")),
        );
      }
    }
  }
}
