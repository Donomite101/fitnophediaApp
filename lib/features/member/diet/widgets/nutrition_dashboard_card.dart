import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class NutritionDashboardCard extends StatelessWidget {
  final double caloriesEaten;
  final double caloriesGoal;
  final double proteinEaten;
  final double proteinGoal;
  final double carbsEaten;
  final double carbsGoal;
  final double fatEaten;
  final double fatGoal;
  final bool isDark;

  const NutritionDashboardCard({
    super.key,
    required this.caloriesEaten,
    required this.caloriesGoal,
    required this.proteinEaten,
    required this.proteinGoal,
    required this.carbsEaten,
    required this.carbsGoal,
    required this.fatEaten,
    required this.fatGoal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final remainingCalories = (caloriesGoal - caloriesEaten).clamp(0, caloriesGoal);
    final progress = (caloriesEaten / caloriesGoal).clamp(0.0, 1.0);
    
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8), // Sharp corners
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Calories Left (Focus on Goal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CALORIES LEFT",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${remainingCalories.toInt()}",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: " kcal",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Mini Circular Indicator for quick glance
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Iconsax.flash_1, 
                    size: 20, 
                    color: const Color(0xFFFF5722),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Main Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearPercentIndicator(
              lineHeight: 8.0,
              percent: progress,
              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              progressColor: const Color(0xFF00C853), // Vibrant Green
              padding: EdgeInsets.zero,
              barRadius: const Radius.circular(4),
              animation: true,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Compact Macros (Horizontal)
          Row(
            children: [
              Expanded(
                child: _buildCompactMacro(
                  "PROTEIN", 
                  proteinEaten, 
                  proteinGoal, 
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMacro(
                  "CARBS", 
                  carbsEaten, 
                  carbsGoal, 
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMacro(
                  "FATS", 
                  fatEaten, 
                  fatGoal, 
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMacro(
    String label,
    double eaten,
    double goal,
    Color color,
  ) {
    final remaining = (goal - eaten).clamp(0, goal);
    final percent = (eaten / goal).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "${remaining.toInt()}g left",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 4.0,
          percent: percent,
          backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          progressColor: color,
          padding: EdgeInsets.zero,
          barRadius: const Radius.circular(2),
          animation: true,
        ),
      ],
    );
  }
}
