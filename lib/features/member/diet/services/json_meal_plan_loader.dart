import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/meal_plan_model.dart';

class JsonMealPlanLoader {
  static Future<List<MealPlan>> loadMealPlans() async {
    try {
      final String response = await rootBundle.loadString('assets/json/meal_plans.json');
      final List<dynamic> data = json.decode(response);
      
      return data.map((json) {
        // Ensure required fields exist or provide defaults
        return MealPlan(
          id: json['id'] ?? 'unknown',
          name: json['name'] ?? 'Untitled Plan',
          description: json['description'] ?? '',
          durationDays: json['durationDays'] ?? 7,
          targetCaloriesMin: (json['targetCaloriesMin'] ?? 0).toDouble(),
          targetCaloriesMax: (json['targetCaloriesMax'] ?? 0).toDouble(),
          targetProtein: (json['targetProtein'] ?? 0).toDouble(),
          targetCarbs: (json['targetCarbs'] ?? 0).toDouble(),
          targetFat: (json['targetFat'] ?? 0).toDouble(),
          difficulty: _parseDifficulty(json['difficulty']),
          tags: List<String>.from(json['tags'] ?? []),
          imageUrl: json['imageUrl'],
          isCustom: json['isCustom'] ?? false,
          creatorId: json['creatorId'],
          dailyPlans: (json['dailyPlans'] as List<dynamic>?)
                  ?.map((d) => DayMealPlan.fromMap(d))
                  .toList() ?? [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error loading meal plans from JSON: $e');
      return [];
    }
  }

  static DifficultyLevel _parseDifficulty(String? value) {
    if (value == null) return DifficultyLevel.intermediate;
    switch (value.toLowerCase()) {
      case 'beginner':
        return DifficultyLevel.beginner;
      case 'advanced':
        return DifficultyLevel.advanced;
      default:
        return DifficultyLevel.intermediate;
    }
  }
}
