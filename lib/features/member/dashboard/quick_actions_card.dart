// lib/features/member/quick_actions_card.dart
import 'package:flutter/material.dart';

class QuickActionsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;

  const QuickActionsCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    required this.primaryGreen,
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryGreen, size: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: greyText,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_outward, size: 22, color: primaryGreen),
        ],
      ),
    );
  }
}