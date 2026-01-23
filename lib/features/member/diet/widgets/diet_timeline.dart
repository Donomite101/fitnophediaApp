import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../models/nutrition_models.dart';
import 'meal_item_card.dart';

class DietTimelineWidget extends StatelessWidget {
  final List<NutritionMeal> meals;
  final bool isDark;
  final Function(NutritionMeal) onToggleConsumed;

  const DietTimelineWidget({
    Key? key,
    required this.meals,
    required this.isDark,
    required this.onToggleConsumed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: [
              Icon(
                Iconsax.note_remove,
                size: 48,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                "No meals logged yet",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final isLast = index == meals.length - 1;
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Column
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      meal.timeOfDay,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _getPeriod(meal.timeOfDay),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Timeline Line
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: meal.isConsumed ? const Color(0xFF4CAF50) : (isDark ? Colors.grey[800] : Colors.grey[300]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Meal Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: MealItemCard(
                    title: meal.name,
                    calories: meal.totalCalories.toStringAsFixed(0),
                    time: meal.timeOfDay,
                    isDark: isDark,
                    isConsumed: meal.isConsumed,
                    onTap: () {},
                    onToggleConsumed: () => onToggleConsumed(meal),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPeriod(String time) {
    if (time.isEmpty) return '';
    final hour = int.tryParse(time.split(':')[0]) ?? 0;
    return hour < 12 ? 'AM' : 'PM';
  }
}
