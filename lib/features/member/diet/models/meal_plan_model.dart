import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a complete meal plan with multiple days of meals
class MealPlan {
  final String id;
  final String name;
  final String description;
  final int durationDays;
  final double targetCaloriesMin;
  final double targetCaloriesMax;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final DifficultyLevel difficulty;
  final List<String> tags;
  final String? imageUrl;
  final bool isCustom;
  final String? creatorId;
  final List<DayMealPlan> dailyPlans;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.targetCaloriesMin,
    required this.targetCaloriesMax,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.difficulty,
    required this.tags,
    this.imageUrl,
    required this.isCustom,
    this.creatorId,
    required this.dailyPlans,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'durationDays': durationDays,
      'targetCaloriesMin': targetCaloriesMin,
      'targetCaloriesMax': targetCaloriesMax,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'difficulty': difficulty.name,
      'tags': tags,
      'imageUrl': imageUrl,
      'isCustom': isCustom,
      'creatorId': creatorId,
      'dailyPlans': dailyPlans.map((d) => d.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MealPlan.fromMap(Map<String, dynamic> map, String documentId) {
    return MealPlan(
      id: map['id'] ?? documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      durationDays: map['durationDays'] ?? 7,
      targetCaloriesMin: (map['targetCaloriesMin'] ?? 0).toDouble(),
      targetCaloriesMax: (map['targetCaloriesMax'] ?? 0).toDouble(),
      targetProtein: (map['targetProtein'] ?? 0).toDouble(),
      targetCarbs: (map['targetCarbs'] ?? 0).toDouble(),
      targetFat: (map['targetFat'] ?? 0).toDouble(),
      difficulty: DifficultyLevel.values.firstWhere(
        (e) => e.name == map['difficulty'],
        orElse: () => DifficultyLevel.intermediate,
      ),
      tags: List<String>.from(map['tags'] ?? []),
      imageUrl: map['imageUrl'],
      isCustom: map['isCustom'] ?? false,
      creatorId: map['creatorId'],
      dailyPlans: (map['dailyPlans'] as List<dynamic>?)
              ?.map((d) => DayMealPlan.fromMap(d))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  MealPlan copyWith({
    String? id,
    String? name,
    String? description,
    int? durationDays,
    double? targetCaloriesMin,
    double? targetCaloriesMax,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    DifficultyLevel? difficulty,
    List<String>? tags,
    String? imageUrl,
    bool? isCustom,
    String? creatorId,
    List<DayMealPlan>? dailyPlans,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      durationDays: durationDays ?? this.durationDays,
      targetCaloriesMin: targetCaloriesMin ?? this.targetCaloriesMin,
      targetCaloriesMax: targetCaloriesMax ?? this.targetCaloriesMax,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      isCustom: isCustom ?? this.isCustom,
      creatorId: creatorId ?? this.creatorId,
      dailyPlans: dailyPlans ?? this.dailyPlans,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents meals for a single day
class DayMealPlan {
  final int dayNumber;
  final List<MealEntry> meals;

  DayMealPlan({
    required this.dayNumber,
    required this.meals,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'meals': meals.map((m) => m.toMap()).toList(),
    };
  }

  factory DayMealPlan.fromMap(Map<String, dynamic> map) {
    return DayMealPlan(
      dayNumber: map['dayNumber'] ?? 1,
      meals: (map['meals'] as List<dynamic>?)
              ?.map((m) => MealEntry.fromMap(m))
              .toList() ??
          [],
    );
  }
  DayMealPlan copyWith({
    int? dayNumber,
    List<MealEntry>? meals,
  }) {
    return DayMealPlan(
      dayNumber: dayNumber ?? this.dayNumber,
      meals: meals ?? this.meals,
    );
  }
}

/// Represents a single meal entry
class MealEntry {
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final String name;
  final String description;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> ingredients;
  final String? instructions;
  final int? prepTimeMinutes;
  final String? imageUrl;
  final String? time; // Format: "HH:mm"

  MealEntry({
    required this.mealType,
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    this.instructions,
    this.prepTimeMinutes,
    this.imageUrl,
    this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'mealType': mealType,
      'name': name,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ingredients': ingredients,
      'instructions': instructions,
      'prepTimeMinutes': prepTimeMinutes,
      'imageUrl': imageUrl,
      'time': time,
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      mealType: map['mealType'] ?? 'Meal',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      ingredients: List<String>.from(map['ingredients'] ?? []),
      instructions: map['instructions'],
      prepTimeMinutes: map['prepTimeMinutes'],
      imageUrl: map['imageUrl'],
      time: map['time'],
    );
  }

  MealEntry copyWith({
    String? mealType,
    String? name,
    String? description,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    List<String>? ingredients,
    String? instructions,
    int? prepTimeMinutes,
    String? imageUrl,
    String? time,
  }) {
    return MealEntry(
      mealType: mealType ?? this.mealType,
      name: name ?? this.name,
      description: description ?? this.description,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      imageUrl: imageUrl ?? this.imageUrl,
      time: time ?? this.time,
    );
  }
}

enum DifficultyLevel {
  beginner,
  intermediate,
  advanced,
}

extension DifficultyLevelExtension on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Simple recipes, minimal prep';
      case DifficultyLevel.intermediate:
        return 'Moderate cooking skills required';
      case DifficultyLevel.advanced:
        return 'Complex recipes, more time needed';
    }
  }
}
