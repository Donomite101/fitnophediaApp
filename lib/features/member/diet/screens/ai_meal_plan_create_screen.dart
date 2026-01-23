import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:iconsax/iconsax.dart';
import '../../chat/ai_service.dart';
import '../models/meal_plan_model.dart';
import '../repository/nutrition_repository.dart';
import 'meal_plan_detail_screen.dart';

class AiMealPlanCreateScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const AiMealPlanCreateScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<AiMealPlanCreateScreen> createState() => _AiMealPlanCreateScreenState();
}

class _AiMealPlanCreateScreenState extends State<AiMealPlanCreateScreen> {
  final PageController _pageController = PageController();
  late final NutritionRepository _repo;
  final AiService _aiService = AiService();

  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _isLoading = false;
  Timer? _loadingTimer;
  int _loadingMessageIndex = 0;
  final List<String> _loadingMessages = [
    'INITIATING_SEQUENCE...',
    'ANALYZING_METRICS...',
    'OPTIMIZING_MACROS...',
    'CONSULTING_DATABASE...',
    'FINALIZING_OUTPUT...',
  ];

  // Form Data
  String _selectedMealStyle = 'Quick & Easy';
  String _selectedCuisine = 'Any';
  final List<String> _cuisineOptions = [
    'Any', 'Indian', 'Asian', 'Italian', 'Mexican', 'Continental', 'Mediterranean'
  ];
  List<String> _ingredients = [];
  final TextEditingController _ingredientController = TextEditingController();
  
  // Personalization Data
  int _durationDays = 7;
  double _targetCalories = 2000;
  List<Map<String, dynamic>> _schedule = [
    {'time': '08:00 AM'},
    {'time': '01:00 PM'},
    {'time': '08:00 PM'},
  ];
  
  // Smart Suggestions
  Map<String, dynamic>? _userProfile;
  int? _recommendedCalories;

  final List<Map<String, dynamic>> _mealStyles = [
    {'title': 'Quick & Easy', 'icon': Iconsax.timer_1, 'desc': '< 30 MINS'},
    {'title': 'Chef\'s Choice', 'icon': Iconsax.star, 'desc': 'GOURMET'},
    {'title': 'Meal Prep', 'icon': Iconsax.box, 'desc': 'BATCH'},
    {'title': 'Budget Friendly', 'icon': Iconsax.wallet_money, 'desc': 'ECONOMICAL'},
  ];

  final List<String> _commonIngredients = [
    'Chicken', 'Rice', 'Eggs', 'Spinach', 'Oats', 'Milk', 'Banana', 'Potato', 'Avocado', 'Salmon'
  ];

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AiService.getFullProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _calculateRecommendedCalories();
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  void _calculateRecommendedCalories() {
    if (_userProfile == null) return;

    final weight = (_userProfile!['weightKg'] as num).toDouble();
    final height = (_userProfile!['heightCm'] as num).toDouble();
    final age = (_userProfile!['age'] as num).toInt();
    final gender = _userProfile!['gender']?.toString().toLowerCase() ?? 'male';
    final goal = _userProfile!['goal']?.toString().toLowerCase() ?? 'maintenance';
    final activity = _userProfile!['daysPerWeek']?.toString().toLowerCase() ?? '4 days';

    // Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Activity Multiplier (Approximate)
    double activityMultiplier = 1.375; // Lightly active default
    if (activity.contains('5') || activity.contains('6')) activityMultiplier = 1.55;
    if (activity.contains('7')) activityMultiplier = 1.725;

    double tdee = bmr * activityMultiplier;

    // Goal Adjustment
    if (goal.contains('gain') || goal.contains('muscle')) {
      tdee += 300;
    } else if (goal.contains('loss') || goal.contains('cut')) {
      tdee -= 400;
    }

    setState(() {
      _recommendedCalories = tdee.round();
      // Clamp between slider min/max
      _targetCalories = tdee.clamp(1200, 4000).toDouble();
    });
  }

  void _applyChefsSelection() {
    if (_userProfile == null) return;
    
    final dietType = _userProfile!['dietType']?.toString().toLowerCase() ?? 'veg';
    final isVeg = dietType.contains('veg') && !dietType.contains('non');
    
    List<String> suggestions = [];
    if (isVeg) {
      suggestions = ['Paneer', 'Lentils', 'Chickpeas', 'Spinach', 'Rice', 'Yogurt', 'Almonds'];
    } else {
      suggestions = ['Chicken', 'Eggs', 'Fish', 'Rice', 'Broccoli', 'Sweet Potato', 'Olive Oil'];
    }

    setState(() {
      // Add only if not present
      for (var s in suggestions) {
        if (!_ingredients.contains(s)) _ingredients.add(s);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added Chef\'s selection for ${isVeg ? "Veg" : "Non-Veg"} diet'),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ingredientController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _generatePlan();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);
    _startLoadingAnimation();

    try {
      final prefs = await _repo.getMealPreferences();
      
      final result = await _aiService.generatePersonalizedMealPlan(
        ingredients: _ingredients,
        mealStyle: _selectedMealStyle,
        durationDays: _durationDays,
        userPreferences: prefs,
        targetCalories: _targetCalories.toInt(),
        schedule: _schedule,
        cuisine: _selectedCuisine,
      );

      if (result != null) {
        await _repo.saveMealPlan(result.toMap());

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MealPlanDetailScreen(
                mealPlan: result,
                gymId: widget.gymId,
                memberId: widget.memberId,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generation failed. Please retry.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        _stopLoadingAnimation();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF050505) : const Color(0xFFF5F5F5);
    final surfaceColor = isDark ? const Color(0xFF111111) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[500] : Colors.grey[600];
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final accentColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          if (_isLoading)
            _buildLoadingState(surfaceColor, textColor, borderColor)
          else
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(textColor, secondaryTextColor),
                  _buildProgressBar(accentColor, borderColor),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildVibeStep(surfaceColor, textColor, secondaryTextColor, borderColor, accentColor),
                        _buildCuisineStep(surfaceColor, textColor, secondaryTextColor, borderColor, accentColor),
                        _buildPersonalizeStep(surfaceColor, textColor, secondaryTextColor, borderColor, accentColor),
                        _buildScheduleStep(surfaceColor, textColor, secondaryTextColor, borderColor, accentColor),
                        _buildPantryStep(surfaceColor, textColor, secondaryTextColor, borderColor, accentColor),
                      ],
                    ),
                  ),
                  _buildBottomBar(backgroundColor, borderColor, accentColor, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color surfaceColor, Color textColor, Color borderColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                color: textColor,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingMessages[_loadingMessageIndex],
                key: ValueKey<int>(_loadingMessageIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color? secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor, size: 20),
            onPressed: _previousStep,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Text(
            'AI CHEF',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          Text(
            'STEP ${_currentStep + 1} / $_totalSteps',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color accentColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          Container(
            height: 2,
            width: double.infinity,
            color: borderColor,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            height: 2,
            width: MediaQuery.of(context).size.width * ((_currentStep + 1) / _totalSteps),
            color: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title, String subtitle, Color textColor, Color? secondaryTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            color: secondaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVibeStep(Color surfaceColor, Color textColor, Color? secondaryTextColor, Color borderColor, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Select Style', 'Define the culinary direction', textColor, secondaryTextColor),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _mealStyles.length,
            itemBuilder: (context, index) {
              final opt = _mealStyles[index];
              final isSelected = opt['title'] == _selectedMealStyle;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedMealStyle = opt['title']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? accentColor 
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? accentColor 
                          : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        opt['icon'],
                        size: 24,
                        color: isSelected ? surfaceColor : textColor,
                      ),
                      const Spacer(),
                      Text(
                        opt['title'],
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? surfaceColor : textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt['desc'],
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          color: isSelected ? surfaceColor.withOpacity(0.6) : secondaryTextColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizeStep(Color surfaceColor, Color textColor, Color? secondaryTextColor, Color borderColor, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Parameters', 'Configure plan specifications', textColor, secondaryTextColor),
          const SizedBox(height: 40),
          
          // Duration
          _buildSectionLabel('DURATION', textColor),
          const SizedBox(height: 16),
          _buildMinimalContainer(
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_durationDays DAYS',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accentColor,
                    inactiveTrackColor: accentColor.withOpacity(0.2),
                    thumbColor: accentColor,
                    overlayColor: accentColor.withOpacity(0.1),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _durationDays.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    onChanged: (val) => setState(() => _durationDays = val.toInt()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Calories
          _buildSectionLabel('CALORIC TARGET', textColor),
          const SizedBox(height: 16),
          _buildMinimalContainer(
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_targetCalories.toInt()} KCAL',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (_recommendedCalories != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RECOMMENDED: $_recommendedCalories',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accentColor,
                    inactiveTrackColor: accentColor.withOpacity(0.2),
                    thumbColor: accentColor,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _targetCalories,
                    min: 1200,
                    max: 4000,
                    divisions: 28,
                    onChanged: (val) => setState(() => _targetCalories = val),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }



  // ... (rest of the class)

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 || date.hour == 12 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildCuisineStep(Color surfaceColor, Color textColor, Color? secondaryTextColor, Color borderColor, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Cuisine', 'Select your preferred cuisine', textColor, secondaryTextColor),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
            ),
            itemCount: _cuisineOptions.length,
            itemBuilder: (context, index) {
              final cuisine = _cuisineOptions[index];
              final isSelected = cuisine == _selectedCuisine;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedCuisine = cuisine),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? accentColor : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cuisine,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? surfaceColor : textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleStep(Color surfaceColor, Color textColor, Color? secondaryTextColor, Color borderColor, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Schedule', 'Define your daily meal times', textColor, secondaryTextColor),
          const SizedBox(height: 40),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _schedule.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final slot = _schedule[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Time Display & Picker
                        GestureDetector(
                          onTap: () async {
                            // Parse 12h time string back to DateTime for picker
                            final timeStr = slot['time'];
                            final parts = timeStr.split(' ');
                            final timeParts = parts[0].split(':');
                            int hour = int.parse(timeParts[0]);
                            final minute = int.parse(timeParts[1]);
                            final period = parts[1];

                            if (period == 'PM' && hour != 12) hour += 12;
                            if (period == 'AM' && hour == 12) hour = 0;

                            final initialDateTime = DateTime(2024, 1, 1, hour, minute);
                            
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: hour, minute: minute),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: isDark 
                                        ? ColorScheme.dark(
                                            primary: accentColor,
                                            onPrimary: surfaceColor,
                                            surface: surfaceColor,
                                            onSurface: textColor,
                                          )
                                        : ColorScheme.light(
                                            primary: accentColor,
                                            onPrimary: surfaceColor,
                                            surface: surfaceColor,
                                            onSurface: textColor,
                                          ),
                                    timePickerTheme: TimePickerThemeData(
                                      backgroundColor: surfaceColor,
                                      dialHandColor: accentColor,
                                      dialBackgroundColor: accentColor.withOpacity(0.1),
                                      hourMinuteTextColor: textColor,
                                      dayPeriodTextColor: textColor,
                                      dayPeriodBorderSide: BorderSide(color: accentColor),
                                      dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                                          states.contains(WidgetState.selected) ? accentColor.withOpacity(0.2) : Colors.transparent),
                                      entryModeIconColor: accentColor,
                                      helpTextStyle: TextStyle(fontFamily: 'Outfit', color: secondaryTextColor),
                                      hourMinuteTextStyle: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: accentColor,
                                        textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                                final now = DateTime.now();
                                final newDateTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                                setState(() {
                                  _schedule[index]['time'] = _formatTime(newDateTime);
                                });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.clock, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  slot['time'],
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Remove Button
                        if (_schedule.length > 1)
                          IconButton(
                            icon: Icon(Iconsax.minus_cirlce, color: Colors.red[400], size: 22),
                            onPressed: () => setState(() => _schedule.removeAt(index)),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          
          // Add Meal Button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _schedule.add({'time': '04:00 PM'});
                });
              },
              icon: Icon(Iconsax.add_circle, color: textColor),
              label: Text(
                'ADD MEAL SLOT',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantryStep(Color surfaceColor, Color textColor, Color? secondaryTextColor, Color borderColor, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepTitle('Inventory', 'Available ingredients', textColor, secondaryTextColor),
              TextButton.icon(
                onPressed: _applyChefsSelection,
                icon: Icon(Iconsax.magic_star, size: 16, color: textColor),
                label: Text(
                  'CHEF\'S SELECTION',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Search Input
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _ingredientController,
              style: TextStyle(fontFamily: 'Outfit', color: textColor),
              decoration: InputDecoration(
                hintText: 'Add ingredient...',
                hintStyle: TextStyle(
                  fontFamily: 'Outfit',
                  color: secondaryTextColor,
                ),
                prefixIcon: Icon(Iconsax.search_normal, color: secondaryTextColor, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(Iconsax.add, color: textColor, size: 20),
                  onPressed: _addCustomIngredient,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _addCustomIngredient(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Selected Chips
          if (_ingredients.isNotEmpty) ...[
            Text(
              'SELECTED',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ingredients.map((ing) {
                return Chip(
                  label: Text(ing),
                  backgroundColor: accentColor,
                  labelStyle: TextStyle(
                    fontFamily: 'Outfit',
                    color: surfaceColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  deleteIcon: Icon(Icons.close, size: 14, color: surfaceColor),
                  onDeleted: () => setState(() => _ingredients.remove(ing)),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Common Suggestions
          Text(
            'SUGGESTIONS',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonIngredients.map((ing) {
              final isSelected = _ingredients.contains(ing);
              return FilterChip(
                label: Text(ing),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _ingredients.add(ing);
                    } else {
                      _ingredients.remove(ing);
                    }
                  });
                },
                backgroundColor: surfaceColor,
                selectedColor: accentColor,
                checkmarkColor: surfaceColor,
                labelStyle: TextStyle(
                  fontFamily: 'Outfit',
                  color: isSelected ? surfaceColor : secondaryTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isSelected ? accentColor : borderColor,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalContainer({required Widget child, required Color surfaceColor, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildBottomBar(Color backgroundColor, Color borderColor, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: const Color(0xFF00C853), // Vibrant Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1 ? 'GENERATE PLAN' : 'CONTINUE',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomIngredient() {
    final val = _ingredientController.text.trim();
    if (val.isNotEmpty && !_ingredients.contains(val)) {
      setState(() {
        _ingredients.add(val);
        _ingredientController.clear();
      });
    }
  }

  void _startLoadingAnimation() {
    _loadingMessageIndex = 0;
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
      });
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }
}
