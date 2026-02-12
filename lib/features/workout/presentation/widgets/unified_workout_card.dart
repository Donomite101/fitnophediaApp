import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/providers/workout_provider.dart';
import '../../data/models/exercise_model.dart';
import '../screens/saved_workout_detail_screen.dart';

class UnifiedWorkoutCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String gymId;
  final String memberId;
  final bool isDark;
  final Map<String, double> workoutProgress;
  final VoidCallback? onRefresh;

  const UnifiedWorkoutCard({
    Key? key,
    required this.data,
    required this.gymId,
    required this.memberId,
    required this.isDark,
    this.workoutProgress = const {},
    this.onRefresh,
    this.width,
    this.height,
    this.margin,
  }) : super(key: key);

  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    // Handle different field names from AI vs Custom
    final title = data['planName'] ?? data['name'] ?? "Untitled Workout";

    final timestamp = data['createdAt'] ?? data['savedAt'];
    final date = timestamp != null
        ? DateFormat('MMM d').format((timestamp as Timestamp).toDate())
        : "Unknown";

    // Handle exercises list location
    int exerciseCount = 0;
    if (data['exercises'] != null) {
      exerciseCount = (data['exercises'] as List).length;
    } else if (data['plan'] != null) {
      if (data['plan']['schedule'] != null) {
        for (var day in (data['plan']['schedule'] as List)) {
          if (day['exercises'] != null) {
            exerciseCount += (day['exercises'] as List).length;
          }
        }
      } else if (data['plan']['exercises'] != null) {
        exerciseCount = (data['plan']['exercises'] as List).length;
      }
    }

    // Determine Tag
    final isAi = data['source'] == 'ai_coach' ||
        data['source'] == 'ai' ||
        data.containsKey('aiSessionId');
    final tagLabel = isAi ? "AI Plan" : "Custom";
    final tagColor = isAi
        ? const Color(0xFFB388FF)
        : const Color(0xFFFFAB40); // Softer Purple / Orange

    // Determine Image (Strictly from Assets based on Title/Category/Tags/First Exercise)
    String? workoutImageUrl;
    String assetPath = 'assets/exercise/upper_body.jpeg'; // Default
    
    // Look for first exercise image
    try {
      final provider = Provider.of<WorkoutProvider>(context, listen: false);
      String? firstExId;
      String? firstExName;

      if (data['exercises'] != null && (data['exercises'] as List).isNotEmpty) {
        firstExId = data['exercises'][0]['exerciseId']?.toString() ?? data['exercises'][0]['id']?.toString();
        firstExName = data['exercises'][0]['name']?.toString();
      } else if (data['plan'] != null) {
        if (data['plan']['schedule'] != null && (data['plan']['schedule'] as List).isNotEmpty) {
           final day = data['plan']['schedule'][0];
           if (day['exercises'] != null && (day['exercises'] as List).isNotEmpty) {
              firstExId = day['exercises'][0]['exerciseId']?.toString() ?? day['exercises'][0]['id']?.toString();
              firstExName = day['exercises'][0]['name']?.toString();
           }
        }
      }

      Exercise? matchedEx;
      if (firstExId != null) {
        try {
          matchedEx = provider.exercises.firstWhere((e) => e.id == firstExId);
        } catch (_) {}
      }
      
      if (matchedEx == null && firstExName != null) {
        try {
          final search = firstExName.toLowerCase();
          matchedEx = provider.exercises.firstWhere((e) => e.name.toLowerCase() == search);
        } catch (_) {}
      }

      if (matchedEx != null && matchedEx.imageUrl.isNotEmpty) {
        workoutImageUrl = matchedEx.imageUrl;
      }
    } catch (_) {}

    // Helper to check keywords
    String? getAssetForString(String text) {
      final s = text.toLowerCase();
      if (s.contains('leg') || s.contains('lower') || s.contains('squat') || s.contains('lunge') || s.contains('glute')) {
        return 'assets/exercise/legs.jpeg';
      } else if (s.contains('ab') || s.contains('core') || s.contains('plank') || s.contains('crunch')) {
        return 'assets/exercise/abs.jpeg';
      } else if (s.contains('pull') || s.contains('back') || s.contains('row') || s.contains('lat')) {
        return 'assets/exercise/biceps.jpeg'; // Use biceps for pull/back to distinguish from general upper
      } else if (s.contains('bicep') || s.contains('curl')) {
        return 'assets/exercise/biceps.jpeg';
      } else if (s.contains('tricep') || s.contains('dip') || s.contains('extension')) {
        return 'assets/exercise/triceps.jpeg';
      } else if (s.contains('chest') || s.contains('press') || s.contains('bench')) {
        return 'assets/exercise/pushups.jpeg';
      } else if (s.contains('push')) {
        return 'assets/exercise/triceps.jpeg'; // Use triceps for generic_push to distinguish from chest
      } else if (s.contains('hiit') || s.contains('cardio') || s.contains('burn') || s.contains('jump') || s.contains('run')) {
        return 'assets/exercise/rope.jpeg';
      } else if (s.contains('full') || s.contains('body')) {
         if (s.contains('athlete') || s.contains('performance') || s.contains('conditioning')) {
           return 'assets/exercise/rope.jpeg';
         }
         return 'assets/exercise/pushups.jpeg'; // Default full body to pushups (compound)
      } else if (s.contains('upper') || s.contains('shoulder') || s.contains('arm')) {
        return 'assets/exercise/upper_body.jpeg';
      }
      return null;
    }

    // 1. Check Workout Title
    String? match = getAssetForString(title);

    // 2. Check Category/Tags if no title match
    if (match == null) {
      final category = (data['category'] ?? "").toString();
      match = getAssetForString(category);
      
      if (match == null) {
        final tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        for (var tag in tags) {
          match = getAssetForString(tag);
          if (match != null) break;
        }
      }
    }

    // 3. Check First Exercise Name if still no match
    if (match == null) {
      if (data['exercises'] != null && (data['exercises'] as List).isNotEmpty) {
        final firstExName = data['exercises'][0]['name']?.toString() ?? "";
        match = getAssetForString(firstExName);
      } else if (data['plan'] != null) {
         // Handle nested plan structure if needed
         if (data['plan']['schedule'] != null && (data['plan']['schedule'] as List).isNotEmpty) {
            final day = data['plan']['schedule'][0];
            if (day['exercises'] != null && (day['exercises'] as List).isNotEmpty) {
               match = getAssetForString(day['exercises'][0]['name']?.toString() ?? "");
            }
         } else if (data['plan']['exercises'] != null && (data['plan']['exercises'] as List).isNotEmpty) {
            match = getAssetForString(data['plan']['exercises'][0]['name']?.toString() ?? "");
         }
      }
    }

    if (match != null) {
      assetPath = match;
    }

    ImageProvider bgImageProvider = workoutImageUrl != null 
        ? CachedNetworkImageProvider(workoutImageUrl)
        : AssetImage(assetPath);

    // Robust Difficulty Check
    String difficulty = 'Beginner';
    if (data['difficulty'] != null) {
      difficulty = data['difficulty'];
    } else if (data['level'] != null) {
      difficulty = data['level'];
    } else if (data['plan'] != null) {
      if (data['plan']['difficulty'] != null)
        difficulty = data['plan']['difficulty'];
      else if (data['plan']['level'] != null)
        difficulty = data['plan']['level'];
    }

    Color difficultyColor;
    switch (difficulty.toString().toLowerCase()) {
      case 'advanced':
        difficultyColor = Colors.redAccent;
        break;
      case 'intermediate':
        difficultyColor = Colors.orangeAccent;
        break;
      default:
        difficultyColor = Colors.greenAccent;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavedWorkoutDetailScreen(
              workoutData: data,
              gymId: gymId,
              memberId: memberId,
            ),
          ),
        );
        if (onRefresh != null) onRefresh!();
      },
      child: Container(
        width: width ?? 260,
        height: height ?? 240,
        margin: margin ?? const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), 
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Header (Compact)
            SizedBox(
              height: height != null ? height! * 0.55 : 105,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: bgImageProvider is CachedNetworkImageProvider
                        ? CachedNetworkImage(
                            imageUrl:
                                (bgImageProvider as CachedNetworkImageProvider)
                                    .url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[800]),
                            errorWidget: (context, url, error) => Image.asset(
                                'assets/exercise/upper_body.jpeg',
                                fit: BoxFit.cover),
                          )
                        : Image(image: bgImageProvider, fit: BoxFit.cover),
                  ),
                  // Gradient Overlay for text readability if needed, or just style
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                  // Tag (AI/Custom) - Top Right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        tagLabel,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: tagColor,
                        ),
                      ),
                    ),
                  ),
                  // Progress Bar (if active) - At the border of image and content
                  if (data['id'] != null &&
                      workoutProgress.containsKey(data['id'].toString()))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: LinearProgressIndicator(
                          value: workoutProgress[data['id'].toString()],
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E676)),
                          minHeight: 4,
                        ),
                      ),
                    ),

                ],
              ),
            ),

            // 2. Content Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 6, 2), // Reduced top padding to prevent overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13, // Slightly smaller
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Iconsax.activity,
                                size: 10, // Reduced from 12
                                color: isDark ? Colors.grey : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "$exerciseCount Exercises",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10, // Reduced from 11
                                color: isDark ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        // Difficulty Badge - Below exercise count
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: difficultyColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: difficultyColor.withOpacity(0.4), width: 0.5),
                          ),
                          child: Text(
                            difficulty,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: difficultyColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                ),
              ),
            ),


          ],
        ),
      ),
    );
  }
}
