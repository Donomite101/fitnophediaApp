import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../models/meal_plan_model.dart';
import '../repository/nutrition_repository.dart';
import '../data/sample_meal_plans.dart';
import '../data/sample_meal_plans.dart';
import '../services/json_meal_plan_loader.dart';
import '../widgets/meal_plan_card_widget.dart';
import 'preference_form_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'meal_plan_view_all_screen.dart';
import 'ai_meal_plan_create_screen.dart';

class MealPlanDiscoveryScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final DateTime date;
  final String mealTime;

  const MealPlanDiscoveryScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    required this.date,
    required this.mealTime,
  }) : super(key: key);

  @override
  State<MealPlanDiscoveryScreen> createState() => _MealPlanDiscoveryScreenState();
}

class _MealPlanDiscoveryScreenState extends State<MealPlanDiscoveryScreen> {
  late final NutritionRepository _repo;
  bool _isLoading = true;
  bool _hasPreferences = false;
  List<MealPlan> _mealPlans = [];
  List<MealPlan> _recommendedPlans = [];

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _checkPreferencesAndLoadPlans();
  }

  Future<void> _checkPreferencesAndLoadPlans() async {
    setState(() => _isLoading = true);

    try {
      final hasPrefs = await _repo.hasCompletedPreferences();

      if (!hasPrefs && mounted) {
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PreferenceFormScreen(
              gymId: widget.gymId,
              memberId: widget.memberId,
            ),
          ),
        );

        if (completed != true && mounted) {
          Navigator.pop(context);
          return;
        }
      }

      await _loadMealPlans();

      if (mounted) {
        setState(() {
          _hasPreferences = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMealPlans() async {
    // Load plans from JSON instead of hardcoded samples
    final allPlans = await JsonMealPlanLoader.loadMealPlans();
    
    // If JSON load fails or is empty, fallback to samples (optional, but good for safety)
    final plansToUse = allPlans.isNotEmpty ? allPlans : SampleMealPlans.getSamplePlans();

    // Load Custom/AI Plans from Firestore
    try {
      final customPlansData = await _repo.getCustomMealPlans();
      final customPlans = customPlansData.map((data) => MealPlan.fromMap(data, data['id'])).toList();
      plansToUse.addAll(customPlans);
    } catch (e) {
      print('Error loading custom plans: $e');
    }
    
    final prefs = await _repo.getMealPreferences();

    List<MealPlan> recommended = [];
    if (prefs != null) {
      final dietType = prefs['dietType'] as String?;
      // final goal = prefs['goal'] as String?; // Goal is secondary for strict diet filtering

      if (dietType != null) {
        // STRICT FILTERING: Only show plans that match the selected diet type tag
        recommended = plansToUse.where((plan) {
          final type = dietType.toLowerCase();
          // Map UI selection to tags if needed, or assume direct match
          // 'vegetarian', 'vegan', 'keto', 'high-protein', 'mediterranean', 'quick'
          
          if (type == 'vegetarian') return plan.tags.contains('vegetarian');
          if (type == 'vegan') return plan.tags.contains('vegan');
          if (type == 'keto') return plan.tags.contains('keto');
          if (type == 'highprotein') return plan.tags.contains('high-protein'); // Handle potential naming diff
          if (type == 'mediterranean') return plan.tags.contains('mediterranean');
          if (type == 'quick') return plan.tags.contains('quick');
          
          // Fallback: check if any tag contains the diet type string
          return plan.tags.any((tag) => tag.contains(type));
        }).toList();
      }
      
      // If no strict matches found (or no diet type), fallback to some default logic or empty
      if (recommended.isEmpty) {
        // Optional: show some generic healthy plans if nothing matches strictly
        // recommended = plansToUse.take(3).toList(); 
      }
    } else {
      // No preferences set, maybe show a mix
      recommended = plansToUse.take(5).toList();
    }

    setState(() {
      _mealPlans = plansToUse..shuffle(); // Shuffle for variety in discovery
      _recommendedPlans = recommended;
    });
  }

  List<MealPlan> get _discoverPlans {
    // Plans for discovery - show a mix of different interesting categories
    // Exclude plans that are already in recommended to avoid duplicates
    final recommendedIds = _recommendedPlans.map((p) => p.id).toSet();
    
    return _mealPlans.where((plan) => 
      !recommendedIds.contains(plan.id) && // Don't show what's already recommended
      (plan.tags.contains('quick') || 
       plan.tags.contains('mediterranean') ||
       plan.tags.contains('international') ||
       plan.tags.contains('comfort-food'))
    ).take(10).toList(); // Limit to 10 for discovery
  }

  List<MealPlan> get _aiPlans {
    // AI-generated or smart plans
    return _mealPlans.where((plan) => 
      plan.tags.contains('ai-generated')
    ).toList();
  }

  List<MealPlan> get _yourPlans {
    // User's saved or favorite plans (for now, showing keto/low-carb)
    return _mealPlans.where((plan) => 
      plan.tags.contains('keto') ||
      plan.tags.contains('low-carb') ||
      plan.tags.contains('vegetarian')
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFF4CAF50),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading meal plans...',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            _buildModernHeader(textColor, isDark),
            
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMealPlans,
                color: const Color(0xFF00C853),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // Recommended Section
                    if (_recommendedPlans.isNotEmpty) ...[
                      _buildSectionHeader(
                        'RECOMMENDED', 
                        'BASED ON YOUR PREFERENCES', 
                        textColor, 
                        isDark,
                        onViewAll: () => _navigateToViewAll('Recommended', _recommendedPlans),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _recommendedPlans.length,
                          itemBuilder: (context, index) {
                            return MealPlanCard(
                              mealPlan: _recommendedPlans[index],
                              isDark: isDark,
                              onTap: () => _navigateToDetail(_recommendedPlans[index]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Discover Section
                    if (_discoverPlans.isNotEmpty) ...[
                      _buildSectionHeader(
                        'DISCOVER', 
                        'EXPLORE NEW MEAL PLANS', 
                        textColor, 
                        isDark,
                        onViewAll: () => _navigateToViewAll('Discover', _discoverPlans),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _discoverPlans.length,
                          itemBuilder: (context, index) {
                            return MealPlanCard(
                              mealPlan: _discoverPlans[index],
                              isDark: isDark,
                              onTap: () => _navigateToDetail(_discoverPlans[index]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // AI Section
                    _buildSectionHeader(
                      'AI POWERED', 
                      'SMART RECOMMENDATIONS', 
                      textColor, 
                      isDark,
                      onViewAll: _aiPlans.isNotEmpty ? () => _navigateToViewAll('AI Powered', _aiPlans) : null,
                    ),
                    const SizedBox(height: 12),
                    if (_aiPlans.isNotEmpty)
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _aiPlans.length,
                          itemBuilder: (context, index) {
                            return MealPlanCard(
                              mealPlan: _aiPlans[index],
                              isDark: isDark,
                              onTap: () => _navigateToDetail(_aiPlans[index]),
                            );
                          },
                        ),
                      )
                    else
                      _buildEmptyAiState(isDark),
                    const SizedBox(height: 32),

                    // Yours Section
                    if (_yourPlans.isNotEmpty) ...[
                      _buildSectionHeader(
                        'YOURS', 
                        'YOUR SAVED PLANS', 
                        textColor, 
                        isDark,
                        onViewAll: () => _navigateToViewAll('Yours', _yourPlans),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _yourPlans.length,
                          itemBuilder: (context, index) {
                            return MealPlanCard(
                              mealPlan: _yourPlans[index],
                              isDark: isDark,
                              onTap: () => _navigateToDetail(_yourPlans[index]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildModernFAB(isDark),
    );
  }

  Widget _buildModernHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEAL PLANS',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: textColor,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'DISCOVER PERSONALIZED NUTRITION',
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
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Iconsax.setting_2, color: textColor, size: 20),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreferenceFormScreen(
                      gymId: widget.gymId,
                      memberId: widget.memberId,
                    ),
                  ),
                );
                _loadMealPlans();
              },
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color textColor, bool isDark, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00C853),
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernFAB(bool isDark) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF00C853),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCreateOptions(context, isDark),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Iconsax.add_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'CREATE CUSTOM PLAN',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
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
    );
  }



  void _navigateToViewAll(String title, List<MealPlan> plans) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanViewAllScreen(
          title: title,
          plans: plans,
          gymId: widget.gymId,
          memberId: widget.memberId,
        ),
      ),
    );
  }
  void _showCreateOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create Meal Plan',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Iconsax.magic_star,
              title: 'GENERATE WITH AI',
              subtitle: 'Smart plan based on your needs',
              color: const Color(0xFF00C853),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiMealPlanCreateScreen(
                      gymId: widget.gymId,
                      memberId: widget.memberId,
                    ),
                  ),
                ).then((_) => _loadMealPlans());
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Iconsax.edit,
              title: 'CREATE MANUALLY',
              subtitle: 'Build your plan from scratch',
              color: Colors.blue,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual creation coming soon!')),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAiState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.magic_star,
              color: const Color(0xFF00C853),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'EXPLORE FITNOPHEDIA AI',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get personalized meal plans tailored to your ingredients and cravings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiMealPlanCreateScreen(
                    gymId: widget.gymId,
                    memberId: widget.memberId,
                  ),
                ),
              ).then((_) => _loadMealPlans());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text(
              'TRY AI PLANNER',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _navigateToDetail(MealPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanDetailScreen(
          mealPlan: plan,
          gymId: widget.gymId,
          memberId: widget.memberId,
        ),
      ),
    );
    // Reload plans when returning from detail screen (in case of deletion)
    if (mounted) {
      await _loadMealPlans();
    }
  }
}
