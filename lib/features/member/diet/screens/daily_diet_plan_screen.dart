import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import 'add_meal_screen.dart';
import 'diet_plan_view_screen.dart';

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
  final Color _primaryColor = Colors.green;
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  // Sample banners data
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Personalise Meal Plan',
      'description': 'To personalize your menu, we still need information.',
      'buttonText': 'Fill in Data',
      'color': Colors.blue,
    },
    {
      'title': 'New Recipes Available',
      'description': 'Discover 20+ new healthy recipes added this week.',
      'buttonText': 'Explore',
      'color': Colors.orange,
    },
    {
      'title': 'Weekly Challenge',
      'description': 'Drink 8 glasses of water daily for 7 days.',
      'buttonText': 'Join Challenge',
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );

    // Auto-scroll banners
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startBannerAutoScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Diet Plan',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_outlined, color: textColor),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Header
              _buildUserHeader(textColor),
              const SizedBox(height: 16),

              // Banner Section
              _buildBannerSection(),
              const SizedBox(height: 24),

              // Calendar Section
              _buildCalendarSection(textColor),
              const SizedBox(height: 24),

              // Stats and Diet Plan Section
              _buildStatsAndDietSection(isDarkMode, textColor, cardColor),
              const SizedBox(height: 24),

              // Current Meal Plan Section
              _buildCurrentMealPlanSection(textColor, cardColor),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        onPressed: _onAddMealPressed,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Meal',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alex Jemison',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMMM yyyy').format(_selectedDate),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerSection() {
    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: _bannerController,
        itemCount: _banners.length,
        onPageChanged: (index) {
          setState(() {
            _currentBannerIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: banner['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: banner['color'].withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner['title'],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  banner['description'],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: banner['color'],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    banner['buttonText'],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarSection(Color textColor) {
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    // Find the starting day (Sunday before 1st of month)
    DateTime startDate = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    // Generate 42 days (6 weeks)
    List<DateTime> calendarDays = [];
    for (int i = 0; i < 42; i++) {
      calendarDays.add(startDate.add(Duration(days: i)));
    }

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((day) {
            return SizedBox(
              width: 40,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar grid
        Wrap(
          children: calendarDays.map((date) {
            final isCurrentMonth = date.month == _selectedDate.month;
            final isSelected = _isSameDay(date, _selectedDate);
            final isToday = _isSameDay(date, DateTime.now());

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _primaryColor :
                  isToday ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: isCurrentMonth ? textColor : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsAndDietSection(bool isDarkMode, Color textColor, Color? cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Card
        StreamBuilder<DailyNutritionSummary?>(
          stream: _repo.listenSummary(_selectedDate),
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final totalCalories = summary?.totalCalories ?? 0;
            final protein = summary?.totalProtein ?? 0;
            final carbs = summary?.totalCarbs ?? 0;
            final fat = summary?.totalFat ?? 0;
            final sugar = summary?.totalSugar ?? 0;
            final waterMl = summary?.waterMl ?? 0;
            final waterGoalMl = summary?.waterGoalMl ?? 2500;

            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Stats',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Calories Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calories',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${totalCalories.toStringAsFixed(0)} kcal',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '1920 kcal',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nutrients Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildNutrientCard('Protein', '${protein.toStringAsFixed(1)}g', Colors.blue),
                      _buildNutrientCard('Carbs', '${carbs.toStringAsFixed(1)}g', Colors.orange),
                      _buildNutrientCard('Fat', '${fat.toStringAsFixed(1)}g', Colors.red),
                      _buildNutrientCard('Sugar', '${sugar.toStringAsFixed(1)}g', Colors.purple),
                      _buildNutrientCard('Water', '${waterMl}ml', Colors.cyan),
                      _buildNutrientCard('Goal', '${waterGoalMl}ml', Colors.green),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Diet Plan Card
        StreamBuilder<List<NutritionMeal>>(
          stream: _repo.listenMeals(_selectedDate),
          builder: (context, snapshot) {
            final meals = snapshot.data ?? [];
            final upcomingMeals = meals.where((meal) {
              final mealTime = meal.timeOfDay.toLowerCase();
              return mealTime.contains('lunch') || mealTime.contains('dinner');
            }).toList();

            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Diet Plan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: _openFullPlanView,
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (upcomingMeals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No upcoming meals scheduled',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    ...upcomingMeals.take(2).map((meal) {
                      return _buildMealCard(meal, textColor);
                    }).toList(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNutrientCard(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(NutritionMeal meal, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meal.timeOfDay} • ${meal.totalCalories?.toStringAsFixed(0) ?? '0'} kcal',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '20 min', // This would come from meal data in a real app
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Start',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMealPlanSection(Color textColor, Color? cardColor) {
    return StreamBuilder<List<NutritionMeal>>(
      stream: _repo.listenMeals(_selectedDate),
      builder: (context, snapshot) {
        final meals = snapshot.data ?? [];
        final currentTime = TimeOfDay.now();

        // Find current or next meal
        NutritionMeal? currentMeal;

        for (final meal in meals) {
          // This is simplified - in a real app, you'd parse meal.timeOfDay to TimeOfDay
          if (meal.timeOfDay.toLowerCase().contains('breakfast') &&
              currentTime.hour < 11) {
            currentMeal = meal;
            break;
          } else if (meal.timeOfDay.toLowerCase().contains('lunch') &&
              currentTime.hour >= 11 && currentTime.hour < 17) {
            currentMeal = meal;
            break;
          } else if (meal.timeOfDay.toLowerCase().contains('dinner') &&
              currentTime.hour >= 17) {
            currentMeal = meal;
            break;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Current Meal',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ongoing',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (currentMeal != null)
                _buildCurrentMealCard(currentMeal, textColor)
              else if (meals.isNotEmpty)
                _buildNextMealCard(meals.first, textColor)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No meals planned for today',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _onAddMealPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                          ),
                          child: Text(
                            'Plan Your First Meal',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentMealCard(NutritionMeal meal, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 32,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meal.timeOfDay} • ${meal.totalCalories?.toStringAsFixed(0) ?? '0'} kcal',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '50%', // This would be dynamic in a real app
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.5, // This would be dynamic in a real app
                backgroundColor: Colors.grey[300],
                color: _primaryColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextMealCard(NutritionMeal meal, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Meal',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                meal.timeOfDay,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                meal.name,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _openFullPlanView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DietPlanViewScreen(
          gymId: widget.gymId,
          memberId: widget.memberId,
          date: _selectedDate,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onAddMealPressed() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMealScreen(
          gymId: widget.gymId,
          memberId: widget.memberId,
          date: _selectedDate,
        ),
      ),
    );

    if (saved == true) {
      // streams auto-update
    }
  }
}