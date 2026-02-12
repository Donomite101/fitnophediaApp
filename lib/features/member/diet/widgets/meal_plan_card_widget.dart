import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../models/meal_plan_model.dart';

class MealPlanCard extends StatelessWidget {
  final MealPlan mealPlan;
  final VoidCallback onTap;
  final bool isDark;
  final double? width;

  const MealPlanCard({
    Key? key,
    required this.mealPlan,
    required this.onTap,
    required this.isDark,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header with Badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.asset(
                    _getMealImage(),
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Gradient Overlay for text contrast if needed, or just style
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
                // Difficulty Badge (Top Left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.chart,
                          size: 10,
                          color: _getDifficultyColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mealPlan.difficulty.displayName,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Duration Badge (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.calendar_1,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${mealPlan.durationDays} Days',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content Section
            // Content Section
            Padding(
              padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      mealPlan.name,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Description
                    Text(
                      mealPlan.description,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Stats Row (Calories & Protein if available, or just Calories)
                    Row(
                      children: [
                        _buildStat(
                          Iconsax.flash_1,
                          '${mealPlan.targetCaloriesMin.toInt()}-${mealPlan.targetCaloriesMax.toInt()} kcal',
                          const Color(0xFFFF9800),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Tags Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: mealPlan.tags.take(3).map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // View Details Button
                    Container(
                      width: double.infinity,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Text(
                              'View Details',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  String _getMealImage() {
    // Check tags to return appropriate image
    // PRIORITY: Vegetarian/Vegan first to ensure correct visual indication
    if (mealPlan.tags.contains('vegetarian') || mealPlan.tags.contains('vegan')) {
      return 'assets/images/meals/vegetarian.png';
    } else if (mealPlan.tags.contains('keto') || mealPlan.tags.contains('low-carb')) {
      return 'assets/images/meals/keto.png';
    } else if (mealPlan.tags.contains('high-protein') || mealPlan.tags.contains('muscle-gain')) {
      return 'assets/images/meals/highprotein.png';
    } else if (mealPlan.tags.contains('mediterranean')) {
      return 'assets/images/meals/mediterranean.png';
    } else if (mealPlan.tags.contains('quick') || mealPlan.tags.contains('easy')) {
      return 'assets/images/meals/quick.png';
    } else {
      // Default to non-veg or generic if no specific tag matches
      return 'assets/images/meals/nonveg.png';
    }
  }

  Color _getDifficultyColor() {
    switch (mealPlan.difficulty) {
      case DifficultyLevel.beginner:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.intermediate:
        return const Color(0xFFFF9800);
      case DifficultyLevel.advanced:
        return const Color(0xFFE91E63);
    }
  }
}
