import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';

import '../models/meal_plan_model.dart';
import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import 'daily_diet_plan_screen.dart';

class MealPlanDetailScreen extends StatefulWidget {
  final MealPlan mealPlan;
  final String gymId;
  final String memberId;

  const MealPlanDetailScreen({
    Key? key,
    required this.mealPlan,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends State<MealPlanDetailScreen> {
  late final NutritionRepository _repo;
  bool _isLoading = false;
  late MealPlan _currentPlan;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _currentPlan = widget.mealPlan;
  }

  Future<void> _deletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE PLAN'),
        content: const Text('Are you sure you want to delete this meal plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _repo.deleteMealPlan(_currentPlan.id);
        if (mounted) {
          Navigator.pop(context); // Pop detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal plan deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting plan: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _applyPlan() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      // Normalize to midnight to ensure consistent date keys
      final startDate = DateTime(now.year, now.month, now.day);
      
      // Iterate through each day of the plan
      for (final dayPlan in _currentPlan.dailyPlans) {
        // Calculate the date for this day of the plan
        // dayNumber is 1-based
        final date = startDate.add(Duration(days: dayPlan.dayNumber - 1));
        
        // Clear existing meals for this day to avoid duplicates
        await _repo.clearMealsForDay(date);
        
        // Save each meal for this day
        for (final mealEntry in dayPlan.meals) {
          final nutritionMeal = _convertToNutritionMeal(mealEntry, date);
          await _repo.saveMeal(date, nutritionMeal);
        }
        
        // Recalculate summary for the day
        await _repo.recalculateSummary(date);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan applied successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        // Navigate back to Daily Diet Plan
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyDietPlanScreen(
              gymId: widget.gymId,
              memberId: widget.memberId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  NutritionMeal _convertToNutritionMeal(MealEntry entry, DateTime date) {
    // Determine time of day based on meal type if not specified
    String timeOfDay = entry.time ?? "12:00";
    if (entry.time == null) {
      if (entry.mealType == "Breakfast") timeOfDay = "08:00";
      else if (entry.mealType == "Lunch") timeOfDay = "13:00";
      else if (entry.mealType == "Dinner") timeOfDay = "19:00";
      else if (entry.mealType == "Snack") timeOfDay = "16:00";
    }
    
    // Create simplified items list since we don't have detailed ingredient macros
    // We'll assign all macros to a single "Main Meal" item for now
    final items = [
      NutritionItem(
        name: entry.name,
        quantity: 1,
        unit: 'serving',
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        sugar: 0, // Not provided in AI response usually
      )
    ];

    return NutritionMeal(
      mealId: const Uuid().v4(),
      name: entry.name,
      timeOfDay: timeOfDay,
      createdAt: DateTime.now(),
      totalCalories: entry.calories,
      totalProtein: entry.protein,
      totalCarbs: entry.carbs,
      totalFat: entry.fat,
      totalSugar: 0,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
              title: Text(
                'PLAN DETAILS',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 2.0,
                ),
              ),
              centerTitle: true,
            actions: [
              if (_currentPlan.isCustom)
                IconButton(
                  icon: Icon(Iconsax.trash, color: Colors.red),
                  onPressed: _deletePlan,
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentPlan.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getDifficultyColor().withOpacity(0.5)),
                        ),
                        child: Text(
                          _currentPlan.difficulty.displayName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getDifficultyColor(),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _currentPlan.description,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats
                  Row(
                    children: [
                      _buildStatCard(
                        Iconsax.calendar,
                        '${_currentPlan.durationDays} DAYS',
                        'DURATION',
                        textColor,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        Iconsax.flash_1,
                        '${_currentPlan.targetCaloriesMin.toInt()}-${_currentPlan.targetCaloriesMax.toInt()}',
                        'KCAL / DAY',
                        textColor,
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Macros
                  Text(
                    'DAILY MACROS',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMacroCard('PROTEIN', '${_currentPlan.targetProtein.toInt()}g', Colors.blue, isDark),
                      const SizedBox(width: 12),
                      _buildMacroCard('CARBS', '${_currentPlan.targetCarbs.toInt()}g', Colors.orange, isDark),
                      const SizedBox(width: 12),
                      _buildMacroCard('FAT', '${_currentPlan.targetFat.toInt()}g', Colors.purple, isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Tags
                  Text(
                    'TAGS',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentPlan.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                            letterSpacing: 1.0,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Sample Day (if available)
                  // Daily Plans
                  if (_currentPlan.dailyPlans.isNotEmpty) ...[
                    ..._currentPlan.dailyPlans.map((dayPlan) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'DAY ${dayPlan.dayNumber}',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          ...dayPlan.meals.asMap().entries.map((entry) {
                            final index = entry.key;
                            final meal = entry.value;
                            return _buildMealCard(meal, isDark, textColor, dayPlan.dayNumber, index);
                          }).toList(),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _applyPlan,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: const Color(0xFF00C853), // Vibrant Green
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'START THIS PLAN',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color textColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal, bool isDark, Color textColor, int dayNumber, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  meal.mealType.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  String displayTime = meal.time ?? '';
                  if (displayTime.isEmpty) {
                    if (meal.mealType == "Breakfast") displayTime = "08:00";
                    else if (meal.mealType == "Lunch") displayTime = "13:00";
                    else if (meal.mealType == "Dinner") displayTime = "19:00";
                    else if (meal.mealType == "Snack") displayTime = "16:00";
                  }
                  
                  if (displayTime.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.clock, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            displayTime,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
              ),
              const Spacer(),
              Text(
                '${meal.calories.toInt()} KCAL',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _editMeal(meal, dayNumber, index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.edit,
                    size: 16,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            meal.name,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meal.description,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMacroChip('P: ${meal.protein.toInt()}g', Colors.blue, isDark),
              const SizedBox(width: 8),
              _buildMacroChip('C: ${meal.carbs.toInt()}g', Colors.orange, isDark),
              const SizedBox(width: 8),
              _buildMacroChip('F: ${meal.fat.toInt()}g', Colors.purple, isDark),
            ],
          ),
        ],
      ),
    );
  }

  void _editMeal(MealEntry meal, int dayNumber, int index) {
    final nameController = TextEditingController(text: meal.name);
    final caloriesController = TextEditingController(text: meal.calories.toInt().toString());
    final proteinController = TextEditingController(text: meal.protein.toInt().toString());
    final carbsController = TextEditingController(text: meal.carbs.toInt().toString());
    final fatController = TextEditingController(text: meal.fat.toInt().toString());
    
    // Default time logic
    String defaultTime = "12:00";
    if (meal.mealType == "Breakfast") defaultTime = "08:00";
    else if (meal.mealType == "Lunch") defaultTime = "13:00";
    else if (meal.mealType == "Dinner") defaultTime = "19:00";
    else if (meal.mealType == "Snack") defaultTime = "16:00";
    
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.parse((meal.time ?? defaultTime).split(':')[0]),
      minute: int.parse((meal.time ?? defaultTime).split(':')[1]),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text(
              'EDIT MEAL',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditTextField('Meal Name', nameController, isDark, textColor),
                  const SizedBox(height: 16),
                  
                  Text(
                    'TIME',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() {
                          selectedTime = time;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.clock, size: 18, color: textColor),
                          const SizedBox(width: 8),
                          Text(
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildEditTextField('Calories', caloriesController, isDark, textColor, isNumber: true),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Protein (g)', proteinController, isDark, textColor, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildEditTextField('Carbs (g)', carbsController, isDark, textColor, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildEditTextField('Fat (g)', fatController, isDark, textColor, isNumber: true)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final newTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                  
                  final updatedMeal = meal.copyWith(
                    name: nameController.text,
                    calories: double.tryParse(caloriesController.text) ?? meal.calories,
                    protein: double.tryParse(proteinController.text) ?? meal.protein,
                    carbs: double.tryParse(carbsController.text) ?? meal.carbs,
                    fat: double.tryParse(fatController.text) ?? meal.fat,
                    time: newTime,
                  );
                  
                  _updateMealInPlan(updatedMeal, dayNumber, index);
                  Navigator.pop(context);
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00C853),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller, bool isDark, Color textColor, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            color: textColor,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00C853)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _updateMealInPlan(MealEntry updatedMeal, int dayNumber, int index) {
    setState(() {
      final dayIndex = _currentPlan.dailyPlans.indexWhere((d) => d.dayNumber == dayNumber);
      if (dayIndex != -1) {
        final dayPlan = _currentPlan.dailyPlans[dayIndex];
        
        // Create a new list of meals
        final newMeals = List<MealEntry>.from(dayPlan.meals);
        
        // Update the specific meal at the index
        if (index >= 0 && index < newMeals.length) {
          newMeals[index] = updatedMeal;
          
          // Create a new day plan with updated meals
          final updatedDayPlan = dayPlan.copyWith(meals: newMeals);
          
          // Update the list of daily plans
          final newDailyPlans = List<DayMealPlan>.from(_currentPlan.dailyPlans);
          newDailyPlans[dayIndex] = updatedDayPlan;
          
          // Update the current plan
          _currentPlan = _currentPlan.copyWith(dailyPlans: newDailyPlans);
        }
      }
    });
  }

  Widget _buildMacroChip(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    if (widget.mealPlan.tags.contains('keto') || widget.mealPlan.tags.contains('low-carb')) {
      return [const Color(0xFFE91E63), const Color(0xFFC2185B)];
    } else if (widget.mealPlan.tags.contains('vegetarian') || widget.mealPlan.tags.contains('vegan')) {
      return [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
    } else if (widget.mealPlan.tags.contains('high-protein') || widget.mealPlan.tags.contains('muscle-gain')) {
      return [const Color(0xFF2196F3), const Color(0xFF1976D2)];
    } else if (widget.mealPlan.tags.contains('mediterranean')) {
      return [const Color(0xFFFF9800), const Color(0xFFF57C00)];
    } else if (widget.mealPlan.tags.contains('quick') || widget.mealPlan.tags.contains('easy')) {
      return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
    }
    return [const Color(0xFF4CAF50), const Color(0xFF45A049)];
  }

  Color _getDifficultyColor() {
    switch (widget.mealPlan.difficulty) {
      case DifficultyLevel.beginner:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.intermediate:
        return const Color(0xFFFF9800);
      case DifficultyLevel.advanced:
        return const Color(0xFFE91E63);
    }
  }
}
