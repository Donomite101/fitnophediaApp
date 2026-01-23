import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionItem {
  final String name;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;

  NutritionItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
  });

  factory NutritionItem.fromMap(Map<String, dynamic> map) {
    return NutritionItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      sugar: (map['sugar'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
  };
}

class NutritionMeal {
  final String mealId;
  final String name;
  final String timeOfDay; // "HH:mm"
  final DateTime createdAt;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalSugar;
  final List<NutritionItem> items;
  final bool isConsumed;

  NutritionMeal({
    required this.mealId,
    required this.name,
    required this.timeOfDay,
    required this.createdAt,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalSugar,
    required this.items,
    this.isConsumed = false,
  });

  factory NutritionMeal.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NutritionMeal(
      mealId: doc.id,
      name: data['name'] ?? '',
      timeOfDay: data['timeOfDay'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      totalCalories: (data['totalCalories'] ?? 0).toDouble(),
      totalProtein: (data['totalProtein'] ?? 0).toDouble(),
      totalCarbs: (data['totalCarbs'] ?? 0).toDouble(),
      totalFat: (data['totalFat'] ?? 0).toDouble(),
      totalSugar: (data['totalSugar'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => NutritionItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      isConsumed: data['isConsumed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'timeOfDay': timeOfDay,
    'createdAt': Timestamp.fromDate(createdAt),
    'totalCalories': totalCalories,
    'totalProtein': totalProtein,
    'totalCarbs': totalCarbs,
    'totalFat': totalFat,
    'totalSugar': totalSugar,
    'items': items.map((e) => e.toMap()).toList(),
    'isConsumed': isConsumed,
  };
}

class DailyNutritionSummary {
  final String dateKey; // yyyy-MM-dd
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalSugar;
  final int waterMl;
  final int waterGoalMl;

  DailyNutritionSummary({
    required this.dateKey,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalSugar,
    required this.waterMl,
    required this.waterGoalMl,
  });

  factory DailyNutritionSummary.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyNutritionSummary(
      dateKey: doc.id,
      totalCalories: (data['totalCalories'] ?? 0).toDouble(),
      totalProtein: (data['totalProtein'] ?? 0).toDouble(),
      totalCarbs: (data['totalCarbs'] ?? 0).toDouble(),
      totalFat: (data['totalFat'] ?? 0).toDouble(),
      totalSugar: (data['totalSugar'] ?? 0).toDouble(),
      waterMl: (data['waterMl'] ?? 0) as int,
      waterGoalMl: (data['waterGoalMl'] ?? 2500) as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'totalCalories': totalCalories,
    'totalProtein': totalProtein,
    'totalCarbs': totalCarbs,
    'totalFat': totalFat,
    'totalSugar': totalSugar,
    'waterMl': waterMl,
    'waterGoalMl': waterGoalMl,
  };
}

class MealTemplate {
  final String id;
  final String name;
  final String defaultTime; // "HH:mm"
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final List<String> ingredients;

  MealTemplate({
    required this.id,
    required this.name,
    required this.defaultTime,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.ingredients,
  });

  factory MealTemplate.fromMap(Map<String, dynamic> map) {
    return MealTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      defaultTime: map['defaultTime'] ?? '08:00',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      sugar: (map['sugar'] ?? 0).toDouble(),
      ingredients: (map['ingredients'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
