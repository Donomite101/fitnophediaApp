import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents user's dietary preferences for personalized meal plans
class MealPreference {
  final String userId;
  final DietType dietType;
  final FitnessGoal goal;
  final List<Allergen> allergies;
  final List<String> dislikedFoods;
  final MealFrequency mealFrequency;
  final CookingTime cookingTime;
  final BudgetLevel budget;
  final List<CuisineType> cuisinePreferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPreference({
    required this.userId,
    required this.dietType,
    required this.goal,
    required this.allergies,
    required this.dislikedFoods,
    required this.mealFrequency,
    required this.cookingTime,
    required this.budget,
    required this.cuisinePreferences,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'dietType': dietType.name,
      'goal': goal.name,
      'allergies': allergies.map((a) => a.name).toList(),
      'dislikedFoods': dislikedFoods,
      'mealFrequency': mealFrequency.name,
      'cookingTime': cookingTime.name,
      'budget': budget.name,
      'cuisinePreferences': cuisinePreferences.map((c) => c.name).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore document
  factory MealPreference.fromMap(Map<String, dynamic> map) {
    return MealPreference(
      userId: map['userId'] ?? '',
      dietType: DietType.values.firstWhere(
        (e) => e.name == map['dietType'],
        orElse: () => DietType.balanced,
      ),
      goal: FitnessGoal.values.firstWhere(
        (e) => e.name == map['goal'],
        orElse: () => FitnessGoal.maintenance,
      ),
      allergies: (map['allergies'] as List<dynamic>?)
              ?.map((a) => Allergen.values.firstWhere(
                    (e) => e.name == a,
                    orElse: () => Allergen.none,
                  ))
              .toList() ??
          [],
      dislikedFoods: List<String>.from(map['dislikedFoods'] ?? []),
      mealFrequency: MealFrequency.values.firstWhere(
        (e) => e.name == map['mealFrequency'],
        orElse: () => MealFrequency.threeMeals,
      ),
      cookingTime: CookingTime.values.firstWhere(
        (e) => e.name == map['cookingTime'],
        orElse: () => CookingTime.moderate,
      ),
      budget: BudgetLevel.values.firstWhere(
        (e) => e.name == map['budget'],
        orElse: () => BudgetLevel.medium,
      ),
      cuisinePreferences: (map['cuisinePreferences'] as List<dynamic>?)
              ?.map((c) => CuisineType.values.firstWhere(
                    (e) => e.name == c,
                    orElse: () => CuisineType.international,
                  ))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MealPreference copyWith({
    String? userId,
    DietType? dietType,
    FitnessGoal? goal,
    List<Allergen>? allergies,
    List<String>? dislikedFoods,
    MealFrequency? mealFrequency,
    CookingTime? cookingTime,
    BudgetLevel? budget,
    List<CuisineType>? cuisinePreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPreference(
      userId: userId ?? this.userId,
      dietType: dietType ?? this.dietType,
      goal: goal ?? this.goal,
      allergies: allergies ?? this.allergies,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      mealFrequency: mealFrequency ?? this.mealFrequency,
      cookingTime: cookingTime ?? this.cookingTime,
      budget: budget ?? this.budget,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Enums for preference options

enum DietType {
  balanced,
  vegetarian,
  vegan,
  keto,
  highProtein,
}

extension DietTypeExtension on DietType {
  String get displayName {
    switch (this) {
      case DietType.balanced:
        return 'Balanced';
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Vegan';
      case DietType.keto:
        return 'Keto';
      case DietType.highProtein:
        return 'High Protein';
    }
  }

  String get description {
    switch (this) {
      case DietType.balanced:
        return 'A well-rounded diet with all food groups';
      case DietType.vegetarian:
        return 'Plant-based with dairy and eggs';
      case DietType.vegan:
        return 'Completely plant-based, no animal products';
      case DietType.keto:
        return 'Very low carb, high fat for ketosis';
      case DietType.highProtein:
        return 'Protein-focused for muscle building';
    }
  }
}

enum FitnessGoal {
  weightLoss,
  muscleGain,
  maintenance,
  athleticPerformance,
  generalHealth,
}

extension FitnessGoalExtension on FitnessGoal {
  String get displayName {
    switch (this) {
      case FitnessGoal.weightLoss:
        return 'Weight Loss';
      case FitnessGoal.muscleGain:
        return 'Muscle Gain';
      case FitnessGoal.maintenance:
        return 'Maintenance';
      case FitnessGoal.athleticPerformance:
        return 'Athletic Performance';
      case FitnessGoal.generalHealth:
        return 'General Health';
    }
  }

  String get description {
    switch (this) {
      case FitnessGoal.weightLoss:
        return 'Reduce body weight and fat';
      case FitnessGoal.muscleGain:
        return 'Build lean muscle mass';
      case FitnessGoal.maintenance:
        return 'Maintain current weight';
      case FitnessGoal.athleticPerformance:
        return 'Optimize for sports performance';
      case FitnessGoal.generalHealth:
        return 'Overall health and wellness';
    }
  }
}

enum Allergen {
  none,
  nuts,
  dairy,
  gluten,
  shellfish,
  soy,
  eggs,
  fish,
  peanuts,
  treeNuts,
  sesame,
}

extension AllergenExtension on Allergen {
  String get displayName {
    switch (this) {
      case Allergen.none:
        return 'None';
      case Allergen.nuts:
        return 'Nuts';
      case Allergen.dairy:
        return 'Dairy';
      case Allergen.gluten:
        return 'Gluten';
      case Allergen.shellfish:
        return 'Shellfish';
      case Allergen.soy:
        return 'Soy';
      case Allergen.eggs:
        return 'Eggs';
      case Allergen.fish:
        return 'Fish';
      case Allergen.peanuts:
        return 'Peanuts';
      case Allergen.treeNuts:
        return 'Tree Nuts';
      case Allergen.sesame:
        return 'Sesame';
    }
  }
}

enum MealFrequency {
  threeMeals,
  fourMeals,
  fiveToSixMeals,
  intermittentFasting,
}

extension MealFrequencyExtension on MealFrequency {
  String get displayName {
    switch (this) {
      case MealFrequency.threeMeals:
        return '3 Meals/Day';
      case MealFrequency.fourMeals:
        return '4 Meals/Day';
      case MealFrequency.fiveToSixMeals:
        return '5-6 Small Meals';
      case MealFrequency.intermittentFasting:
        return 'Intermittent Fasting';
    }
  }

  String get description {
    switch (this) {
      case MealFrequency.threeMeals:
        return 'Traditional breakfast, lunch, dinner';
      case MealFrequency.fourMeals:
        return 'Three meals plus one snack';
      case MealFrequency.fiveToSixMeals:
        return 'Smaller, more frequent meals';
      case MealFrequency.intermittentFasting:
        return 'Time-restricted eating window';
    }
  }
}

enum CookingTime {
  quick,
  moderate,
  elaborate,
}

extension CookingTimeExtension on CookingTime {
  String get displayName {
    switch (this) {
      case CookingTime.quick:
        return 'Quick (<15 min)';
      case CookingTime.moderate:
        return 'Moderate (15-30 min)';
      case CookingTime.elaborate:
        return 'Elaborate (>30 min)';
    }
  }
}

enum BudgetLevel {
  low,
  medium,
  high,
}

extension BudgetLevelExtension on BudgetLevel {
  String get displayName {
    switch (this) {
      case BudgetLevel.low:
        return 'Budget-Friendly';
      case BudgetLevel.medium:
        return 'Moderate';
      case BudgetLevel.high:
        return 'Premium';
    }
  }
}

enum CuisineType {
  indian,
  western,
  asian,
  mediterranean,
  mexican,
  middleEastern,
  international,
}

extension CuisineTypeExtension on CuisineType {
  String get displayName {
    switch (this) {
      case CuisineType.indian:
        return 'Indian';
      case CuisineType.western:
        return 'Western';
      case CuisineType.asian:
        return 'Asian';
      case CuisineType.mediterranean:
        return 'Mediterranean';
      case CuisineType.mexican:
        return 'Mexican';
      case CuisineType.middleEastern:
        return 'Middle Eastern';
      case CuisineType.international:
        return 'International';
    }
  }
}
