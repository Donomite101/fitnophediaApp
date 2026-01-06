import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

class PlanCard extends StatelessWidget {
  final Map<String, dynamic>? workoutPlan;
  final Map<String, dynamic>? dietPlan;
  final VoidCallback onSave;

  const PlanCard({
    Key? key,
    this.workoutPlan,
    this.dietPlan,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final title = workoutPlan != null
        ? (workoutPlan!['title'] ?? 'Workout Plan')
        : (dietPlan!['title'] ?? 'Diet Plan');

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Header with Save Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.bookmark_border, size: 14),
                    label: const Text('Save', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (workoutPlan != null) _buildWorkoutSection(workoutPlan!, textColor),
          if (workoutPlan != null && dietPlan != null) Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          if (dietPlan != null) _buildDietSection(dietPlan!, textColor),
        ],
      ),
    );
  }

  Widget _buildWorkoutSection(Map<String, dynamic> plan, Color textColor) {
    final schedule = plan['schedule'] as List?;
    if (schedule == null || schedule.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.fitness_center, color: AppTheme.primaryGreen, size: 16),
          const SizedBox(width: 8),
          Text('Workout Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      initiallyExpanded: true,
      children: schedule.map((day) {
        final exercises = day['exercises'] as List?;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${day['day']} • ${day['focus']}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor.withOpacity(0.8)),
              ),
              const SizedBox(height: 4),
              ...exercises?.map((ex) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(color: AppTheme.primaryGreen)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: textColor, fontSize: 13, fontFamily: 'Poppins'),
                          children: [
                            TextSpan(text: "${ex['name']} ", style: const TextStyle(fontWeight: FontWeight.w500)),
                            TextSpan(text: "(${ex['sets']}x${ex['reps']})", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList() ?? [],
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDietSection(Map<String, dynamic> plan, Color textColor) {
    final meals = plan['meals'] as List?;
    final macros = plan['macros'] as Map?;

    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text('Diet Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      initiallyExpanded: true,
      children: [
        if (macros != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroText('Protein', macros['protein'], Colors.blue),
                _buildMacroText('Carbs', macros['carbs'], Colors.green),
                _buildMacroText('Fats', macros['fats'], Colors.orange),
              ],
            ),
          ),
        if (meals != null)
          ...meals.map((meal) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(meal['name'] ?? 'Meal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
                          const Spacer(),
                          Text('${meal['calories']} kcal', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5))),
                        ],
                      ),
                      Text(
                        (meal['items'] as List?)?.join(', ') ?? '',
                        style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
      ],
    );
  }

  Widget _buildMacroText(String label, String? value, Color color) {
    return Column(
      children: [
        Text(value ?? '-', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
      ],
    );
  }
}
