import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class MealItemCard extends StatelessWidget {
  final String title;
  final String calories;
  final String protein;
  final String carbs;
  final String fat;
  final String time;
  final bool isDark;
  final bool isConsumed;
  final VoidCallback onTap;
  final VoidCallback onToggleConsumed;
  final VoidCallback? onDelete;

  const MealItemCard({
    super.key,
    required this.title,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
    required this.isDark,
    this.isConsumed = false,
    required this.onTap,
    required this.onToggleConsumed,
    this.onDelete,
  });

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Iconsax.trash,
                          size: 18,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (onDelete != null) const SizedBox(width: 12),
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
              ],
            ),
            const SizedBox(height: 8),
            if (calories == "0")
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildMacroBadge(calories, "kcal", const Color(0xFFFF5722)),
                      const SizedBox(width: 8),
                      _buildMacroBadge(protein, "P", const Color(0xFF2196F3)),
                      const SizedBox(width: 8),
                      _buildMacroBadge(carbs, "C", const Color(0xFFFF9800)),
                      const SizedBox(width: 8),
                      _buildMacroBadge(fat, "F", const Color(0xFF9C27B0)),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
