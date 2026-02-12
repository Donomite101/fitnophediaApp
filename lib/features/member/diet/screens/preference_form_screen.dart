import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../models/meal_preference_model.dart';
import '../repository/nutrition_repository.dart';

class PreferenceFormScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const PreferenceFormScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<PreferenceFormScreen> createState() => _PreferenceFormScreenState();
}

class _PreferenceFormScreenState extends State<PreferenceFormScreen> {
  final PageController _pageController = PageController();
  late final NutritionRepository _repo;
  
  int _currentStep = 0;
  final int _totalSteps = 7;

  // User selections
  DietType _selectedDietType = DietType.balanced;
  FitnessGoal _selectedGoal = FitnessGoal.maintenance;
  List<Allergen> _selectedAllergies = [];
  List<String> _dislikedFoods = [];
  MealFrequency _selectedMealFrequency = MealFrequency.threeMeals;
  CookingTime _selectedCookingTime = CookingTime.moderate;
  BudgetLevel _selectedBudget = BudgetLevel.medium;
  List<CuisineType> _selectedCuisines = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    try {
      final prefs = await _repo.getMealPreferences();
      if (prefs != null) {
        setState(() {
          _currentStep = 1; // Skip welcome screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(1);
            }
          });
          
          // Pre-fill existing values
          if (prefs['dietType'] != null) {
            _selectedDietType = DietType.values.firstWhere(
              (e) => e.name == prefs['dietType'],
              orElse: () => DietType.balanced,
            );
          }
          if (prefs['goal'] != null) {
            _selectedGoal = FitnessGoal.values.firstWhere(
              (e) => e.name == prefs['goal'],
              orElse: () => FitnessGoal.maintenance,
            );
          }
          // Load other preferences if needed
        });
      }
    } catch (e) {
      print('Error checking preferences: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _savePreferences();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);

    final preference = MealPreference(
      userId: widget.memberId,
      dietType: _selectedDietType,
      goal: _selectedGoal,
      allergies: _selectedAllergies,
      dislikedFoods: _dislikedFoods,
      mealFrequency: _selectedMealFrequency,
      cookingTime: _selectedCookingTime,
      budget: _selectedBudget,
      cuisinePreferences: _selectedCuisines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _repo.saveMealPreferences(preference.toMap());
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate completion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(textColor),
            
            // Progress indicator
            _buildProgressIndicator(isDark),
            
            const SizedBox(height: 24),
            
            // Page view
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(textColor, isDark),
                  _buildDietTypeStep(textColor, isDark),
                  _buildGoalStep(textColor, isDark),
                  _buildAllergiesStep(textColor, isDark),
                  _buildDislikesStep(textColor, isDark),
                  _buildEatingHabitsStep(textColor, isDark),
                  _buildCuisineStep(textColor, isDark),
                ],
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: _previousStep,
            ),
          const SizedBox(width: 8),
          Text(
            'Meal Preferences',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4CAF50)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      _currentStep == _totalSteps - 1 ? 'Complete' : 'Continue',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Welcome
  Widget _buildWelcomeStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF45A049).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Iconsax.note_favorite,
                  size: 64,
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                Text(
                  'Personalize Your Nutrition',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Answer a few quick questions to get meal plans tailored to your goals, preferences, and lifestyle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Iconsax.heart,
            'Personalized Plans',
            'Get meal plans that match your dietary needs',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Iconsax.flash_1,
            'Quick & Easy',
            'Takes less than 2 minutes to complete',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Iconsax.edit,
            'Always Editable',
            'Change your preferences anytime',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: Diet Type
  Widget _buildDietTypeStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your diet type?',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the diet that best matches your lifestyle',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ...DietType.values.map((type) => _buildDietTypeCard(type, isDark)),
        ],
      ),
    );
  }

  Widget _buildDietTypeCard(DietType type, bool isDark) {
    final isSelected = _selectedDietType == type;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedDietType = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4CAF50)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Iconsax.tick_circle5 : Iconsax.note_favorite,
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey[600]),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Goal
  Widget _buildGoalStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your primary goal?',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us recommend the right calorie and macro targets',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ...FitnessGoal.values.map((goal) => _buildGoalCard(goal, isDark)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(FitnessGoal goal, bool isDark) {
    final isSelected = _selectedGoal == goal;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4CAF50)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Iconsax.tick_circle5 : Iconsax.flag,
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey[600]),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.displayName,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goal.description,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Allergies
  Widget _buildAllergiesStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Any food allergies?',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply (or skip if none)',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Allergen.values
                .where((a) => a != Allergen.none)
                .map((allergen) => _buildAllergyChip(allergen, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyChip(Allergen allergen, bool isDark) {
    final isSelected = _selectedAllergies.contains(allergen);
    
    return FilterChip(
      label: Text(allergen.displayName),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedAllergies.add(allergen);
          } else {
            _selectedAllergies.remove(allergen);
          }
        });
      },
      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4CAF50),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
      labelStyle: TextStyle(
        fontFamily: 'Outfit',
        color: isSelected
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.white : Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
      ),
    );
  }

  // Step 5: Dislikes with text field input
  Widget _buildDislikesStep(Color textColor, bool isDark) {
    final TextEditingController foodController = TextEditingController();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foods you dislike?',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll avoid these in your meal plans (optional)',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Text field to add foods
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
              ),
            ),
            child: TextField(
              controller: foodController,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: textColor,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Type a food (e.g., "Broccoli")',
                hintStyle: TextStyle(
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Iconsax.add_circle,
                    color: const Color(0xFF4CAF50),
                  ),
                  onPressed: () {
                    final food = foodController.text.trim();
                    if (food.isNotEmpty && !_dislikedFoods.contains(food)) {
                      setState(() {
                        _dislikedFoods.add(food);
                        foodController.clear();
                      });
                    }
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onSubmitted: (value) {
                final food = value.trim();
                if (food.isNotEmpty && !_dislikedFoods.contains(food)) {
                  setState(() {
                    _dislikedFoods.add(food);
                    foodController.clear();
                  });
                }
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Display added foods as chips
          if (_dislikedFoods.isNotEmpty) ...[
            Text(
              'Your disliked foods:',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dislikedFoods.map((food) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.red.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        food,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.red[300] : Colors.red[700],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _dislikedFoods.remove(food);
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDark ? Colors.red[300] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Optional skip message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.info_circle,
                  size: 20,
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is optional. You can skip or add foods later in settings.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 6: Eating Habits
  Widget _buildEatingHabitsStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your eating habits',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Meal Frequency
          Text(
            'Meal Frequency',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...MealFrequency.values.map((freq) => _buildHabitOption(
            freq.displayName,
            freq.description,
            _selectedMealFrequency == freq,
            () => setState(() => _selectedMealFrequency = freq),
            isDark,
          )),
          
          const SizedBox(height: 24),
          
          // Cooking Time
          Text(
            'Cooking Time',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...CookingTime.values.map((time) => _buildHabitOption(
            time.displayName,
            '',
            _selectedCookingTime == time,
            () => setState(() => _selectedCookingTime = time),
            isDark,
          )),
          
          const SizedBox(height: 24),
          
          // Budget
          Text(
            'Budget Level',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...BudgetLevel.values.map((budget) => _buildHabitOption(
            budget.displayName,
            '',
            _selectedBudget == budget,
            () => setState(() => _selectedBudget = budget),
            isDark,
          )),
        ],
      ),
    );
  }

  Widget _buildHabitOption(String title, String subtitle, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Iconsax.tick_circle5 : Iconsax.record_circle,
              color: isSelected ? const Color(0xFF4CAF50) : (isDark ? Colors.white54 : Colors.grey[400]),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 7: Cuisine Preferences
  Widget _buildCuisineStep(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuisine preferences',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your favorite cuisines (choose multiple)',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CuisineType.values
                .map((cuisine) => _buildCuisineChip(cuisine, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCuisineChip(CuisineType cuisine, bool isDark) {
    final isSelected = _selectedCuisines.contains(cuisine);
    
    return FilterChip(
      label: Text(cuisine.displayName),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCuisines.add(cuisine);
          } else {
            _selectedCuisines.remove(cuisine);
          }
        });
      },
      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4CAF50),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
      labelStyle: TextStyle(
        fontFamily: 'Outfit',
        color: isSelected
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.white : Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
      ),
    );
  }
}
