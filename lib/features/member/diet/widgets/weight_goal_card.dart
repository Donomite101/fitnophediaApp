import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class WeightGoalCard extends StatelessWidget {
  final double currentWeight;
  final double goalWeight;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onSubtract;

  const WeightGoalCard({
    Key? key,
    required this.currentWeight,
    required this.goalWeight,
    required this.isDark,
    required this.onAdd,
    required this.onSubtract,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your goal: ${goalWeight.toStringAsFixed(0)} kg",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Your current weight:",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionButton(Icons.add, onAdd),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: currentWeight.toStringAsFixed(1),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: " kg",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.remove, onSubtract),
                  ],
                ),
              ],
            ),
          ),
          // Character/Image Placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            // In a real app, this would be an asset image
            child: const Icon(Iconsax.emoji_happy, size: 40, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : const Color(0xFFEEF9F0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFF4CAF50),
        ),
      ),
    );
  }
}
