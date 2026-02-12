import '../models/meal_plan_model.dart';

/// Sample meal plans for demonstration and initial content
class SampleMealPlans {
  static List<MealPlan> getSamplePlans() {
    List<MealPlan> plans = [
      _muscleBuilderPlan(),
      _ketoKickstartPlan(),
      _vegetarianVitalityPlan(),
      _mediterraneanMagicPlan(),
      _quickAndEasyPlan(),
    ];
    
    // Generate specialized plans for each category
    plans.addAll(_generateCategoryPlans('Vegetarian', ['vegetarian', 'plant-based'], 10));
    plans.addAll(_generateCategoryPlans('Vegan', ['vegan', 'plant-based', 'dairy-free'], 10));
    plans.addAll(_generateCategoryPlans('Keto', ['keto', 'low-carb', 'high-fat'], 10));
    plans.addAll(_generateCategoryPlans('High Protein', ['high-protein', 'muscle-gain'], 10));
    
    return plans;
  }

  static List<MealPlan> _generateCategoryPlans(String prefix, List<String> tags, int count) {
    return List.generate(count, (index) {
      final variation = index + 1;
      return MealPlan(
        id: '${prefix.toLowerCase().replaceAll(" ", "_")}_plan_$variation',
        name: '$prefix Plan #$variation',
        description: 'A specialized $prefix diet plan variation $variation tailored for your goals.',
        durationDays: 7,
        targetCaloriesMin: 1800 + (index * 50).toDouble(),
        targetCaloriesMax: 2200 + (index * 50).toDouble(),
        targetProtein: prefix == 'High Protein' ? 150 + (index * 5) : 100,
        targetCarbs: prefix == 'Keto' ? 30 : 200,
        targetFat: prefix == 'Keto' ? 120 : 70,
        difficulty: index % 3 == 0 ? DifficultyLevel.beginner : (index % 3 == 1 ? DifficultyLevel.intermediate : DifficultyLevel.advanced),
        tags: [...tags, 'variation-$variation'],
        imageUrl: null,
        isCustom: false,
        creatorId: null,
        dailyPlans: _generateDailyPlans(prefix),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }

  static List<DayMealPlan> _generateDailyPlans(String type) {
    return List.generate(7, (d) {
      return DayMealPlan(
        dayNumber: d + 1,
        meals: _generateMealsForType(type, d + 1),
      );
    });
  }

  static List<MealEntry> _generateMealsForType(String type, int day) {
    List<MealEntry> meals = [];
    
    // Breakfast
    meals.add(MealEntry(
      mealType: 'Breakfast',
      name: '$type Breakfast Day $day',
      description: 'Nutritious start to your day',
      calories: 400,
      protein: 25,
      carbs: type == 'Keto' ? 5 : 40,
      fat: type == 'Keto' ? 30 : 15,
      ingredients: type == 'Vegan' ? ['Oats', 'Almond Milk', 'Berries'] : ['Eggs', 'Spinach', 'Toast'],
      instructions: 'Prepare and serve fresh.',
      prepTimeMinutes: 10,
    ));

    // Lunch
    meals.add(MealEntry(
      mealType: 'Lunch',
      name: '$type Power Lunch Day $day',
      description: 'Balanced midday meal',
      calories: 600,
      protein: 35,
      carbs: type == 'Keto' ? 8 : 50,
      fat: 20,
      ingredients: ['Mixed Salad', 'Protein Source', 'Dressing'],
      instructions: 'Combine ingredients in a bowl.',
      prepTimeMinutes: 15,
    ));

    // Dinner
    meals.add(MealEntry(
      mealType: 'Dinner',
      name: '$type Savory Dinner Day $day',
      description: 'Satisfying evening meal',
      calories: 550,
      protein: 30,
      carbs: type == 'Keto' ? 6 : 45,
      fat: 25,
      ingredients: ['Roasted Vegetables', 'Main Protein', 'Spices'],
      instructions: 'Cook main protein and serve with veggies.',
      prepTimeMinutes: 30,
    ));

    return meals;
  }


  static MealPlan _muscleBuilderPlan() {
    return MealPlan(
      id: 'muscle_builder_7day',
      name: '7-Day Muscle Builder',
      description: 'High-protein meal plan designed to support muscle growth and recovery',
      durationDays: 7,
      targetCaloriesMin: 2400,
      targetCaloriesMax: 2800,
      targetProtein: 180,
      targetCarbs: 250,
      targetFat: 80,
      difficulty: DifficultyLevel.intermediate,
      tags: ['high-protein', 'muscle-gain', 'balanced'],
      imageUrl: null,
      isCustom: false,
      creatorId: null,
      dailyPlans: [
        DayMealPlan(
          dayNumber: 1,
          meals: [
            MealEntry(
              mealType: 'Breakfast',
              name: 'Protein Power Oatmeal',
              description: 'Oats with protein powder, banana, and almonds',
              calories: 520,
              protein: 35,
              carbs: 65,
              fat: 12,
              ingredients: ['Oats (80g)', 'Whey protein (30g)', 'Banana', 'Almonds (20g)', 'Honey'],
              instructions: 'Cook oats, mix in protein powder, top with banana and almonds',
              prepTimeMinutes: 10,
            ),
            MealEntry(
              mealType: 'Lunch',
              name: 'Grilled Chicken & Rice Bowl',
              description: 'Lean chicken breast with brown rice and vegetables',
              calories: 650,
              protein: 55,
              carbs: 70,
              fat: 15,
              ingredients: ['Chicken breast (200g)', 'Brown rice (150g)', 'Broccoli', 'Carrots', 'Olive oil'],
              instructions: 'Grill chicken, cook rice, steam vegetables, combine',
              prepTimeMinutes: 25,
            ),
            MealEntry(
              mealType: 'Snack',
              name: 'Greek Yogurt & Berries',
              description: 'High-protein snack with antioxidants',
              calories: 250,
              protein: 20,
              carbs: 30,
              fat: 5,
              ingredients: ['Greek yogurt (200g)', 'Mixed berries', 'Honey'],
              prepTimeMinutes: 5,
            ),
            MealEntry(
              mealType: 'Dinner',
              name: 'Salmon with Sweet Potato',
              description: 'Omega-3 rich salmon with complex carbs',
              calories: 680,
              protein: 45,
              carbs: 55,
              fat: 25,
              ingredients: ['Salmon fillet (180g)', 'Sweet potato (200g)', 'Asparagus', 'Lemon', 'Olive oil'],
              instructions: 'Bake salmon and sweet potato, grill asparagus',
              prepTimeMinutes: 30,
            ),
          ],
        ),
        // Additional days would follow similar pattern
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MealPlan _ketoKickstartPlan() {
    return MealPlan(
      id: 'keto_kickstart_7day',
      name: 'Keto Kickstart',
      description: 'Low-carb, high-fat meal plan to enter ketosis',
      durationDays: 7,
      targetCaloriesMin: 1800,
      targetCaloriesMax: 2200,
      targetProtein: 120,
      targetCarbs: 30,
      targetFat: 150,
      difficulty: DifficultyLevel.intermediate,
      tags: ['keto', 'low-carb', 'high-fat', 'weight-loss'],
      imageUrl: null,
      isCustom: false,
      creatorId: null,
      dailyPlans: [
        DayMealPlan(
          dayNumber: 1,
          meals: [
            MealEntry(
              mealType: 'Breakfast',
              name: 'Keto Egg Scramble',
              description: 'Eggs with cheese, avocado, and bacon',
              calories: 550,
              protein: 30,
              carbs: 8,
              fat: 45,
              ingredients: ['Eggs (3)', 'Cheddar cheese (50g)', 'Avocado (half)', 'Bacon (2 strips)', 'Butter'],
              instructions: 'Scramble eggs in butter, add cheese, serve with avocado and bacon',
              prepTimeMinutes: 12,
            ),
            MealEntry(
              mealType: 'Lunch',
              name: 'Chicken Caesar Salad (No Croutons)',
              description: 'Grilled chicken on romaine with Caesar dressing',
              calories: 480,
              protein: 40,
              carbs: 6,
              fat: 32,
              ingredients: ['Chicken breast (150g)', 'Romaine lettuce', 'Parmesan cheese', 'Caesar dressing', 'Olive oil'],
              instructions: 'Grill chicken, toss salad with dressing and cheese',
              prepTimeMinutes: 15,
            ),
            MealEntry(
              mealType: 'Snack',
              name: 'Cheese & Nuts',
              description: 'Quick keto-friendly snack',
              calories: 280,
              protein: 12,
              carbs: 5,
              fat: 24,
              ingredients: ['Cheddar cheese (40g)', 'Macadamia nuts (30g)'],
              prepTimeMinutes: 2,
            ),
            MealEntry(
              mealType: 'Dinner',
              name: 'Butter Garlic Steak with Zucchini',
              description: 'Juicy steak with low-carb vegetables',
              calories: 620,
              protein: 48,
              carbs: 8,
              fat: 46,
              ingredients: ['Ribeye steak (200g)', 'Zucchini', 'Garlic', 'Butter (30g)', 'Herbs'],
              instructions: 'Pan-sear steak in butter, sauté zucchini with garlic',
              prepTimeMinutes: 20,
            ),
          ],
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MealPlan _vegetarianVitalityPlan() {
    return MealPlan(
      id: 'vegetarian_vitality_7day',
      name: 'Vegetarian Vitality',
      description: 'Plant-powered nutrition for energy and health',
      durationDays: 7,
      targetCaloriesMin: 1900,
      targetCaloriesMax: 2300,
      targetProtein: 90,
      targetCarbs: 220,
      targetFat: 70,
      difficulty: DifficultyLevel.beginner,
      tags: ['vegetarian', 'plant-based', 'balanced', 'easy'],
      imageUrl: null,
      isCustom: false,
      creatorId: null,
      dailyPlans: [
        DayMealPlan(
          dayNumber: 1,
          meals: [
            MealEntry(
              mealType: 'Breakfast',
              name: 'Veggie Breakfast Burrito',
              description: 'Scrambled eggs with beans, cheese, and salsa',
              calories: 480,
              protein: 22,
              carbs: 52,
              fat: 18,
              ingredients: ['Eggs (2)', 'Black beans', 'Whole wheat tortilla', 'Cheese', 'Salsa', 'Avocado'],
              instructions: 'Scramble eggs, warm beans, assemble burrito',
              prepTimeMinutes: 12,
            ),
            MealEntry(
              mealType: 'Lunch',
              name: 'Quinoa Buddha Bowl',
              description: 'Quinoa with roasted vegetables and tahini',
              calories: 520,
              protein: 18,
              carbs: 68,
              fat: 20,
              ingredients: ['Quinoa (100g)', 'Chickpeas', 'Sweet potato', 'Kale', 'Tahini dressing'],
              instructions: 'Cook quinoa, roast vegetables, assemble bowl with dressing',
              prepTimeMinutes: 25,
            ),
            MealEntry(
              mealType: 'Snack',
              name: 'Hummus & Veggies',
              description: 'Fresh vegetables with protein-rich hummus',
              calories: 220,
              protein: 8,
              carbs: 28,
              fat: 10,
              ingredients: ['Hummus (100g)', 'Carrots', 'Cucumber', 'Bell peppers'],
              prepTimeMinutes: 5,
            ),
            MealEntry(
              mealType: 'Dinner',
              name: 'Lentil Curry with Rice',
              description: 'Spiced lentils with basmati rice',
              calories: 580,
              protein: 24,
              carbs: 85,
              fat: 16,
              ingredients: ['Red lentils (150g)', 'Basmati rice (100g)', 'Coconut milk', 'Curry spices', 'Spinach'],
              instructions: 'Cook lentils with spices and coconut milk, serve over rice',
              prepTimeMinutes: 30,
            ),
          ],
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MealPlan _mediterraneanMagicPlan() {
    return MealPlan(
      id: 'mediterranean_magic_7day',
      name: 'Mediterranean Magic',
      description: 'Heart-healthy Mediterranean diet with fresh ingredients',
      durationDays: 7,
      targetCaloriesMin: 2000,
      targetCaloriesMax: 2400,
      targetProtein: 100,
      targetCarbs: 200,
      targetFat: 90,
      difficulty: DifficultyLevel.intermediate,
      tags: ['mediterranean', 'heart-healthy', 'balanced', 'fish'],
      imageUrl: null,
      isCustom: false,
      creatorId: null,
      dailyPlans: [
        DayMealPlan(
          dayNumber: 1,
          meals: [
            MealEntry(
              mealType: 'Breakfast',
              name: 'Greek Yogurt Parfait',
              description: 'Yogurt with honey, nuts, and fresh fruit',
              calories: 420,
              protein: 25,
              carbs: 48,
              fat: 16,
              ingredients: ['Greek yogurt (250g)', 'Honey', 'Walnuts', 'Fresh berries', 'Granola'],
              instructions: 'Layer yogurt with toppings',
              prepTimeMinutes: 5,
            ),
            MealEntry(
              mealType: 'Lunch',
              name: 'Mediterranean Chickpea Salad',
              description: 'Chickpeas with feta, olives, and vegetables',
              calories: 510,
              protein: 20,
              carbs: 55,
              fat: 24,
              ingredients: ['Chickpeas', 'Feta cheese', 'Olives', 'Tomatoes', 'Cucumber', 'Olive oil', 'Lemon'],
              instructions: 'Combine all ingredients, dress with olive oil and lemon',
              prepTimeMinutes: 10,
            ),
            MealEntry(
              mealType: 'Snack',
              name: 'Mixed Nuts & Dried Fruit',
              description: 'Energy-boosting Mediterranean snack',
              calories: 280,
              protein: 8,
              carbs: 32,
              fat: 15,
              ingredients: ['Almonds', 'Walnuts', 'Dried figs', 'Dried apricots'],
              prepTimeMinutes: 2,
            ),
            MealEntry(
              mealType: 'Dinner',
              name: 'Grilled Sea Bass with Vegetables',
              description: 'Fresh fish with roasted Mediterranean vegetables',
              calories: 620,
              protein: 42,
              carbs: 48,
              fat: 28,
              ingredients: ['Sea bass (200g)', 'Zucchini', 'Eggplant', 'Tomatoes', 'Olive oil', 'Herbs', 'Lemon'],
              instructions: 'Grill fish, roast vegetables with olive oil and herbs',
              prepTimeMinutes: 28,
            ),
          ],
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MealPlan _quickAndEasyPlan() {
    return MealPlan(
      id: 'quick_easy_7day',
      name: 'Quick & Easy',
      description: 'Simple meals ready in 15 minutes or less',
      durationDays: 7,
      targetCaloriesMin: 1800,
      targetCaloriesMax: 2200,
      targetProtein: 110,
      targetCarbs: 200,
      targetFat: 70,
      difficulty: DifficultyLevel.beginner,
      tags: ['quick', 'easy', 'beginner', 'time-saving'],
      imageUrl: null,
      isCustom: false,
      creatorId: null,
      dailyPlans: [
        DayMealPlan(
          dayNumber: 1,
          meals: [
            MealEntry(
              mealType: 'Breakfast',
              name: 'Protein Smoothie Bowl',
              description: 'Blended smoothie with toppings',
              calories: 380,
              protein: 28,
              carbs: 48,
              fat: 10,
              ingredients: ['Protein powder', 'Banana', 'Berries', 'Almond milk', 'Granola', 'Chia seeds'],
              instructions: 'Blend ingredients, pour into bowl, add toppings',
              prepTimeMinutes: 8,
            ),
            MealEntry(
              mealType: 'Lunch',
              name: 'Turkey & Avocado Wrap',
              description: 'Quick wrap with lean protein',
              calories: 480,
              protein: 32,
              carbs: 42,
              fat: 20,
              ingredients: ['Turkey slices (120g)', 'Whole wheat wrap', 'Avocado', 'Lettuce', 'Tomato', 'Mustard'],
              instructions: 'Assemble wrap with all ingredients',
              prepTimeMinutes: 5,
            ),
            MealEntry(
              mealType: 'Snack',
              name: 'Protein Bar & Apple',
              description: 'Convenient on-the-go snack',
              calories: 280,
              protein: 20,
              carbs: 35,
              fat: 8,
              ingredients: ['Protein bar', 'Apple'],
              prepTimeMinutes: 1,
            ),
            MealEntry(
              mealType: 'Dinner',
              name: 'Stir-Fry Chicken & Veggies',
              description: 'Quick stir-fry with pre-cut vegetables',
              calories: 520,
              protein: 38,
              carbs: 52,
              fat: 18,
              ingredients: ['Chicken strips (180g)', 'Stir-fry vegetable mix', 'Soy sauce', 'Ginger', 'Rice'],
              instructions: 'Stir-fry chicken and vegetables, serve over rice',
              prepTimeMinutes: 15,
            ),
          ],
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
