import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../widgets/nutrition_dashboard_card.dart';
// import '../widgets/smart_guidance_banner.dart';
import '../widgets/compact_hydration_card.dart';
// import '../widgets/weight_goal_card.dart';
// import '../widgets/notification_card.dart';
import '../widgets/horizontal_calendar.dart';
import '../widgets/diet_timeline.dart';
// import 'add_meal_screen.dart';
// import 'diet_plan_view_screen.dart';
// import 'diet_plan_list_screen.dart';
import 'meal_plan_discovery_screen.dart';
import 'manual_meal_create_screen.dart';
// import '../widgets/meal_item_card.dart';
import '../widgets/food_scanner_widget.dart';
import '../service/nutrition_api_service.dart';

class DailyDietPlanScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const DailyDietPlanScreen({
    super.key,
    required this.gymId,
    required this.memberId,
  });

  @override
  State<DailyDietPlanScreen> createState() => _DailyDietPlanScreenState();
}

class _DailyDietPlanScreenState extends State<DailyDietPlanScreen> {
  late final NutritionRepository _repo;
  late final NutritionApiService _api;
  DateTime _selectedDate = DateTime.now();
  
  // State
  double _currentWeight = 52.1;
  double _goalWeight = 48.0;
  bool _isEditingMeals = false;
  bool _isSubmitting = false;
  int _lastAddedAmount = 0;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _api = NutritionApiService();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- UI Helpers ---

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00C853), width: 1),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "NUTRITION HUB",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Color(0xFF00C853),
              ),
            ),
            Text(
              "Log your food",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: textColor.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildACTIONButtonFull({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: color,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: color.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _macroItem(String label, double value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${value.toStringAsFixed(1)}g",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroPreviewExtended(NutritionAnalysisResult result, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _macroItem("PROTEIN", result.protein, const Color(0xFF2196F3), isDark),
          _macroItem("CARBS", result.carbs, const Color(0xFFFF9800), isDark),
          _macroItem("FATS", result.fat, const Color(0xFF9C27B0), isDark),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(TextEditingController name, TextEditingController cal, TextEditingController pro, TextEditingController carb, TextEditingController fat, NutritionAnalysisResult? result) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () async {
          final foodName = name.text.trim();
          final calories = double.tryParse(cal.text.trim()) ?? 0.0;
          final protein = double.tryParse(pro.text.trim()) ?? 0.0;
          final carbs = double.tryParse(carb.text.trim()) ?? 0.0;
          final fatVal = double.tryParse(fat.text.trim()) ?? 0.0;

          if (foodName.isNotEmpty) {
            setState(() => _isSubmitting = true);
            try {
              final now = DateTime.now();
              final meal = NutritionMeal(
                mealId: DateTime.now().millisecondsSinceEpoch.toString(),
                name: foodName,
                timeOfDay: _formatTime(now),
                createdAt: now,
                totalCalories: calories,
                totalProtein: protein,
                totalCarbs: carbs,
                totalFat: fatVal,
                totalSugar: result?.sugar ?? 0.0,
                items: [],
                isConsumed: true,
              );
              await _repo.saveMeal(_selectedDate, meal);
              await _repo.recalculateSummary(_selectedDate);
              
              if (mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              debugPrint('Error saving meal: $e');
            } finally {
              if (mounted) setState(() => _isSubmitting = false);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C3E50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text(
              "COMPLETE LOGGING",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
        ),
      ),
    );
  }

  void _showAddFoodBottomSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg = isDarkMode ? const Color(0xFF1A1A1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C3E50);
    
    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    final proController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    
    NutritionAnalysisResult? currentResult;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(context, textColor),
              const SizedBox(height: 28),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  ),
                )
              else
                _buildACTIONButtonFull(
                  icon: Iconsax.scan_barcode,
                  label: "SCAN FOOD BARCODE",
                  subLabel: "Instant data from Edamam Database",
                  color: const Color(0xFF34495E),
                  onTap: () async {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => FoodScannerWidget(
                          onScan: (barcode) async {
                            setModalState(() => isLoading = true);
                            try {
                              final result = await _api.searchByBarcode(barcode);
                              if (result != null) {
                                setModalState(() {
                                  currentResult = result;
                                  nameController.text = result.name ?? "Product ($barcode)";
                                  calorieController.text = result.calories.toStringAsFixed(0);
                                  proController.text = result.protein.toStringAsFixed(1);
                                  carbController.text = result.carbs.toStringAsFixed(1);
                                  fatController.text = result.fat.toStringAsFixed(1);
                                });
                              }
                            } finally {
                              setModalState(() => isLoading = false);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Divider(color: textColor.withOpacity(0.1))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "QUICK LOG",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: textColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: textColor.withOpacity(0.1))),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: TextStyle(color: textColor, fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                decoration: _inputDecoration("Item Name (e.g. Chicken Salad)", isDarkMode),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                     child: TextField(
                       controller: calorieController,
                       keyboardType: TextInputType.number,
                       style: TextStyle(color: textColor, fontFamily: 'Outfit'),
                       decoration: _inputDecoration("Kcal", isDarkMode),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: TextField(
                       controller: proController,
                       keyboardType: TextInputType.number,
                       style: TextStyle(color: textColor, fontFamily: 'Outfit'),
                       decoration: _inputDecoration("Protein (g)", isDarkMode),
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                     child: TextField(
                       controller: carbController,
                       keyboardType: TextInputType.number,
                       style: TextStyle(color: textColor, fontFamily: 'Outfit'),
                       decoration: _inputDecoration("Carbs (g)", isDarkMode),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: TextField(
                       controller: fatController,
                       keyboardType: TextInputType.number,
                       style: TextStyle(color: textColor, fontFamily: 'Outfit'),
                       decoration: _inputDecoration("Fat (g)", isDarkMode),
                     ),
                   ),
                ],
              ),
              if (currentResult != null) ...[
                const SizedBox(height: 20),
                _buildMacroPreviewExtended(currentResult!, isDarkMode),
              ],
              const SizedBox(height: 32),
              _buildSubmitButton(nameController, calorieController, proController, carbController, fatController, currentResult),
            ],
          ),
        ),
      ),
    );
  }

  // --- Main Build Section ---

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF050505) : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtleTextColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "MY MEALS",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 2.0,
            color: textColor,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.calendar_edit, size: 20),
              color: textColor,
              onPressed: () {},
              tooltip: "Create Meal Plan",
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            HorizontalCalendar(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
              isDark: isDarkMode,
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NUTRITION OVERVIEW",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionDashboard(isDarkMode),
                  const SizedBox(height: 28),
                  _buildWaterTracker(isDarkMode),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S SCHEDULE",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM d').format(_selectedDate).toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subtleTextColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isEditingMeals)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: _showAddFoodBottomSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
                                  ),
                                  child: const Icon(Iconsax.add, color: Color(0xFF00C853), size: 20),
                                ),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: _isEditingMeals ? const Color(0xFFF44336) : const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isEditingMeals ? const Color(0xFFF44336) : const Color(0xFF00C853)).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isEditingMeals = !_isEditingMeals;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isEditingMeals ? Iconsax.tick_circle : Iconsax.edit_2,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isEditingMeals ? "DONE" : "MANAGE",
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTimeline(isDarkMode),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00C853),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MealPlanDiscoveryScreen(
                gymId: widget.gymId,
                memberId: widget.memberId,
                date: _selectedDate,
                mealTime: 'breakfast',
              ),
            ),
          );
        },
        child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNutritionDashboard(bool isDarkMode) {
    return StreamBuilder<DailyNutritionSummary?>(
      stream: _repo.listenSummary(_selectedDate),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        return NutritionDashboardCard(
          caloriesEaten: summary?.totalCalories ?? 0.0,
          caloriesGoal: 2000.0,
          proteinEaten: summary?.totalProtein ?? 0.0,
          proteinGoal: 150.0,
          carbsEaten: summary?.totalCarbs ?? 0.0,
          carbsGoal: 250.0,
          fatEaten: summary?.totalFat ?? 0.0,
          fatGoal: 70.0,
          isDark: isDarkMode,
        );
      },
    );
  }

  Widget _buildTimeline(bool isDarkMode) {
    return StreamBuilder<List<NutritionMeal>>(
      stream: _repo.listenMeals(_selectedDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final meals = snapshot.data!;
        return DietTimelineWidget(
          meals: meals,
          isDark: isDarkMode,
          onToggleConsumed: (meal) async {
            await _repo.toggleMealConsumption(_selectedDate, meal.mealId, !meal.isConsumed);
          },
          onDeleteMeal: _isEditingMeals ? (meal) async {
            await _repo.deleteMeal(_selectedDate, meal.mealId);
            await _repo.recalculateSummary(_selectedDate);
          } : null,
        );
      },
    );
  }

  Widget _buildWaterTracker(bool isDarkMode) {
    return StreamBuilder<DailyNutritionSummary?>(
      stream: _repo.listenSummary(_selectedDate),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final waterMl = summary?.waterMl ?? 0;
        final waterGoalMl = summary?.waterGoalMl ?? 2000;

        return FutureBuilder<List<int>>(
          future: _repo.getWeeklyWaterIntake(_selectedDate),
          builder: (context, weeklySnapshot) {
            double weeklyAvg = 0;
            if (weeklySnapshot.hasData && weeklySnapshot.data!.isNotEmpty) {
              weeklyAvg = weeklySnapshot.data!.reduce((a, b) => a + b) / weeklySnapshot.data!.length;
            }

            return CompactHydrationCard(
              currentMl: waterMl.toDouble(),
              goalMl: waterGoalMl.toDouble(),
              weeklyAverage: weeklyAvg,
              isDark: isDarkMode,
              repo: _repo,
              onAddWater: (amount) async {
                setState(() => _lastAddedAmount = amount);
                await _repo.updateWater(_selectedDate, waterMl + amount);
              },
              onGoalChange: (newGoal) async {
                await _repo.updateWaterGoal(_selectedDate, newGoal);
              },
              onReset: () async {
                setState(() => _lastAddedAmount = 0);
                await _repo.updateWater(_selectedDate, 0);
              },
              onUndo: _lastAddedAmount > 0 ? () async {
                await _repo.updateWater(_selectedDate, waterMl - _lastAddedAmount);
                setState(() => _lastAddedAmount = 0);
              } : null,
            );
          },
        );
      },
    );
  }
}