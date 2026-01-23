import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class MealItemCard extends StatelessWidget {
  final String title;
  final String calories;
  final String time;
  final bool isDark;
  final bool isConsumed;
  final VoidCallback onTap;
  final VoidCallback onToggleConsumed;

  const MealItemCard({
    Key? key,
    required this.title,
    required this.calories,
    required this.time,
    required this.isDark,
    this.isConsumed = false,
    required this.onTap,
    required this.onToggleConsumed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      decoration: isConsumed ? TextDecoration.lineThrough : null,
                      decorationColor: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onToggleConsumed,
                  child: Icon(
                    isConsumed ? Icons.check_circle : Icons.circle_outlined,
                    color: isConsumed ? const Color(0xFF4CAF50) : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Placeholder for "No food added" or actual food items
            // For now, showing "Add Food" prompt if calories is 0/empty
            if (calories == "0" || calories.startsWith("0/"))
              Text(
                "Tap to add food",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: subTextColor?.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Banana, Shoko milk vegan...", // Mock data
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$calories kcal",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF5722), // Deep Orange
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
