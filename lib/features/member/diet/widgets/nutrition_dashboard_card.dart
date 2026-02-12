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
    final subTextColor = (isDark ? Colors.grey[500] : Colors.grey[600]) ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Calories Ring
          _buildCaloriesRing(progress, remainingCalories.toDouble(), textColor, subTextColor),
          const SizedBox(width: 20),
          // Middle: Macro Breakdown
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMacroLine("Protein", proteinEaten, proteinGoal, const Color(0xFF2196F3)),
                const SizedBox(height: 12),
                _buildMacroLine("Carbs", carbsEaten, carbsGoal, const Color(0xFFFF9800)),
                const SizedBox(height: 12),
                _buildMacroLine("Fats", fatEaten, fatGoal, const Color(0xFF9C27B0)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: Eaten Totals
          _buildEatenStats(caloriesEaten, caloriesGoal, isDark, textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _buildCaloriesRing(double progress, double remaining, Color textColor, Color subTextColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${remaining.toInt()}",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              "LEFT",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: subTextColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroLine(String label, double eaten, double goal, Color color) {
    final percent = (eaten / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            Text(
              "${eaten.toInt()}g / ${goal.toInt()}g",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 3,
            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildEatenStats(double eaten, double goal, bool isDark, Color textColor, Color subTextColor) {
    String statusText = "ON TRACK";
    Color statusColor = const Color(0xFF00C853);
    
    if (eaten > goal) {
      statusText = "OVER LIMIT";
      statusColor = Colors.redAccent;
    } else if (eaten > goal * 0.9) {
      statusText = "NEAR LIMIT";
      statusColor = Colors.orange;
    } else if (eaten == 0) {
      statusText = "STARTING";
      statusColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "EATEN",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: subTextColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              "${eaten.toInt()}",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              "kcal",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: subTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
