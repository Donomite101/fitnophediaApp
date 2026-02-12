import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../diet/repository/nutrition_repository.dart';
import '../diet/models/nutrition_models.dart';
import '../diet/screens/daily_diet_plan_screen.dart';

class NextMealCard extends StatelessWidget {
  final String gymId;
  final String memberId;

  const NextMealCard({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (gymId.isEmpty || memberId.isEmpty) return const SizedBox.shrink();

    final repo = NutritionRepository(gymId: gymId, memberId: memberId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<NutritionMeal>>(
      stream: repo.listenMeals(DateTime.now()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final meals = snapshot.data!;
        // Find the first meal that is NOT consumed
        NutritionMeal? nextMeal;
        try {
          nextMeal = meals.firstWhere((m) => !m.isConsumed);
        } catch (_) {
          nextMeal = null; // All consumed
        }

        if (meals.isEmpty) {
          return _buildEmptyState(context, isDark, 'No meals planned', Iconsax.note_1);
        }

        if (nextMeal == null) {
          // All done
          return _buildEmptyState(context, isDark, 'All meals logged!', Iconsax.tick_circle, isPositive: true);
        }

        return _buildPremiumCard(context, nextMeal, repo, isDark);
      },
    );
  }

  Widget _buildPremiumCard(BuildContext context, NutritionMeal meal, NutritionRepository repo, bool isDark) {
    final formattedTime = _formatTime(meal.timeOfDay);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)] 
              : [const Color(0xFFFFFFFF), const Color(0xFFF5F5F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 1. Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Iconsax.coffee, color: Color(0xFFFF9800), size: 22),
              ),
              const SizedBox(width: 12),
              
              // 2. Meal Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            meal.name,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Calories & Macros Inline
                    Row(
                      children: [
                        Text(
                          '${meal.totalCalories.round()} kcal',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: isDark ? Colors.white24 : Colors.black12)),
                        const SizedBox(width: 8),
                        Text(
                          'P:${meal.totalProtein.round()} C:${meal.totalCarbs.round()} F:${meal.totalFat.round()}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 3. Log Action (Compact)
              InkWell(
                onTap: () => _logMeal(context, repo, meal),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Iconsax.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String time24) {
    try {
      final now = DateTime.now();
      // Expecting "HH:mm" usually, but let's be safe
      final parts = time24.split(':');
      if (parts.length == 2) {
        final dt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('h:mm a').format(dt);
      }
      return time24;
    } catch (_) {
      return time24;
    }
  }

  Widget _buildMacroItem(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String message, IconData icon, {bool isPositive = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isPositive ? Colors.green : (isDark ? Colors.white24 : Colors.black26),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logMeal(BuildContext context, NutritionRepository repo, NutritionMeal meal) async {
    try {
      await repo.toggleMealConsumption(DateTime.now(), meal.mealId, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${meal.name}!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging meal')),
      );
    }
  }
}
