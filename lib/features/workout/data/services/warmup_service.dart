import 'package:flutter/material.dart';

class WarmupService {
  static final WarmupService instance = WarmupService._internal();
  WarmupService._internal();

  List<Map<String, dynamic>> generateWarmup(List<Map<String, dynamic>> exercises) {
    final Set<String> bodyParts = {};
    
    // 1. Analyze Body Parts
    for (var ex in exercises) {
      if (ex['bodyPart'] != null) {
        bodyParts.add(ex['bodyPart'].toString().toLowerCase());
      }
    }

    List<Map<String, dynamic>> warmupExercises = [];

    // 2. Base Warmup (Always included - 4 Exercises)
    warmupExercises.add({
      'name': 'Jumping Jacks',
      'sets': 1,
      'reps': '60s',
      'weight': 0,
      'isWarmup': true,
      'instructions': 'Start with a light cardio warmup to get your heart rate up.',
      'bodyPart': 'cardio',
    });

    warmupExercises.add({
      'name': 'Arm Circles',
      'sets': 1,
      'reps': '30s',
      'weight': 0,
      'isWarmup': true,
      'instructions': 'Rotate your arms in large circles to warm up your shoulders.',
      'bodyPart': 'shoulders',
    });

    warmupExercises.add({
      'name': 'Torso Twists',
      'sets': 1,
      'reps': '30s',
      'weight': 0,
      'isWarmup': true,
      'instructions': 'Stand with feet shoulder-width apart and twist your torso side to side.',
      'bodyPart': 'core',
    });

    warmupExercises.add({
      'name': 'High Knees',
      'sets': 1,
      'reps': '30s',
      'weight': 0,
      'isWarmup': true,
      'instructions': 'Run in place, bringing your knees up as high as possible.',
      'bodyPart': 'cardio',
    });

    // 3. Specific Warmups (Appended if needed)
    if (bodyParts.any((b) => b.contains('leg') || b.contains('quad') || b.contains('glute') || b.contains('calf'))) {
      warmupExercises.add({
        'name': 'Leg Swings',
        'sets': 2,
        'reps': 15,
        'weight': 0,
        'isWarmup': true,
        'instructions': 'Swing your legs forward and backward to loosen up your hips.',
        'bodyPart': 'legs',
      });
      warmupExercises.add({
        'name': 'Bodyweight Squats',
        'sets': 2,
        'reps': 15,
        'weight': 0,
        'isWarmup': true,
        'instructions': 'Perform squats with just your bodyweight to prepare your joints.',
        'bodyPart': 'legs',
      });
    }

    if (bodyParts.any((b) => b.contains('chest') || b.contains('push') || b.contains('tricep'))) {
      warmupExercises.add({
        'name': 'Wall Pushups',
        'sets': 2,
        'reps': 15,
        'weight': 0,
        'isWarmup': true,
        'instructions': 'Perform pushups against a wall for a lighter chest warmup.',
        'bodyPart': 'chest',
      });
    }

    if (bodyParts.any((b) => b.contains('back') || b.contains('pull') || b.contains('lat') || b.contains('bicep'))) {
      warmupExercises.add({
        'name': 'Band Pull-Aparts',
        'sets': 2,
        'reps': 15,
        'weight': 0,
        'isWarmup': true,
        'instructions': 'Use a resistance band to pull apart and warm up your rear delts and back.',
        'bodyPart': 'back',
      });
    }

    return warmupExercises;
  }
}
