import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../widgets/nutrition_dashboard_card.dart';
import '../widgets/smart_guidance_banner.dart';
import '../widgets/compact_hydration_card.dart';
import '../widgets/weight_goal_card.dart';
import '../widgets/notification_card.dart';
import '../widgets/horizontal_calendar.dart';
import '../widgets/diet_timeline.dart';
import 'add_meal_screen.dart';
import 'diet_plan_view_screen.dart';
import 'diet_plan_list_screen.dart';
import 'meal_plan_discovery_screen.dart';
import '../widgets/meal_item_card.dart';

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
  DateTime _selectedDate = DateTime.now();
  
  // Mock state for weight
  double _currentWeight = 52.1;
  double _goalWeight = 48.0;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

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
              onPressed: () {
                // Navigate to Create Meal Plan
              },
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
            
            // Date Selector
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
                  // Section Label
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
                  
                  // Nutrition Dashboard
                  _buildNutritionDashboard(isDarkMode),
                  const SizedBox(height: 28),

                  // Water Tracker (Compact)
                  _buildWaterTracker(isDarkMode),
                  const SizedBox(height: 36),

                  // Timeline Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853), // Vibrant Green
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Edit Schedule
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.edit_2,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "EDIT",
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
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
                  const SizedBox(height: 20),
                  
                  // Timeline
                  _buildTimeline(isDarkMode),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // Slightly rounded square
          color: const Color(0xFF00C853),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _onAddMealPressed,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildNutritionDashboard(bool isDarkMode) {
    return StreamBuilder<DailyNutritionSummary?>(
      stream: _repo.listenSummary(_selectedDate),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        
        // Mock data if null
        // Map model fields to widget parameters
        final caloriesEaten = summary?.totalCalories ?? 1284.0;
        final caloriesGoal = 2106.0; // TODO: Fetch from user profile
        final proteinEaten = summary?.totalProtein ?? 65.0;
        final proteinGoal = 140.0;
        final carbsEaten = summary?.totalCarbs ?? 142.0;
        final carbsGoal = 250.0;
        final fatEaten = summary?.totalFat ?? 42.0;
        final fatGoal = 70.0;

        return NutritionDashboardCard(
          caloriesEaten: caloriesEaten,
          caloriesGoal: caloriesGoal,
          proteinEaten: proteinEaten,
          proteinGoal: proteinGoal,
          carbsEaten: carbsEaten,
          carbsGoal: carbsGoal,
          fatEaten: fatEaten,
          fatGoal: fatGoal,
          isDark: isDarkMode,
        );
      },
    );
  }

  Widget _buildTimeline(bool isDarkMode) {
    return StreamBuilder<List<NutritionMeal>>(
      stream: _repo.listenMeals(_selectedDate),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading meals'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final meals = snapshot.data!;

        return DietTimelineWidget(
          meals: meals,
          isDark: isDarkMode,
          onToggleConsumed: (meal) async {
            await _repo.toggleMealConsumption(_selectedDate, meal.mealId, !meal.isConsumed);
          },
        );
      },
    );
  }



  Widget _buildWaterTracker(bool isDarkMode) {
    return StreamBuilder<DailyNutritionSummary?>(
      stream: _repo.listenSummary(_selectedDate),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final waterMl = summary?.waterMl ?? 1000; // Mock 1000 as per design if null
        final waterGoalMl = summary?.waterGoalMl ?? 2000;

        return FutureBuilder<List<int>>(
          future: _repo.getWeeklyWaterIntake(_selectedDate),
          builder: (context, weeklySnapshot) {
            double weeklyAvg = 0;
            if (weeklySnapshot.hasData && weeklySnapshot.data!.isNotEmpty) {
              final total = weeklySnapshot.data!.reduce((a, b) => a + b);
              weeklyAvg = total / weeklySnapshot.data!.length;
            }

            return CompactHydrationCard(
              currentMl: waterMl.toDouble(),
              goalMl: waterGoalMl.toDouble(),
              weeklyAverage: weeklyAvg,
              isDark: isDarkMode,
              repo: _repo, // Pass repo
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
          }
        );
      },
    );
  }

  int _lastAddedAmount = 0;

  void _onAddMealPressed() async {
    // Determine meal time based on current hour
    final hour = DateTime.now().hour;
    String mealTime = "Snack";
    if (hour < 11) mealTime = "Breakfast";
    else if (hour < 15) mealTime = "Lunch";
    else if (hour < 21) mealTime = "Dinner";

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealPlanDiscoveryScreen(
          gymId: widget.gymId,
          memberId: widget.memberId,
          date: _selectedDate,
          mealTime: mealTime,
        ),
      ),
    );
    // Refresh summary after returning (if needed)
    setState(() {});
  }
}