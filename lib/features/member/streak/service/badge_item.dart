import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../models/streak_view_model.dart';

class BadgeItem extends StatelessWidget {
  final BadgeModel badge;
  final StreakViewModel viewModel;

  const BadgeItem({
    Key? key,
    required this.badge,
    required this.viewModel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: badge.unlocked
                    ? badge.color
                    : (viewModel.isDarkMode ? const Color(0xFF000000) : const Color(0xFFE0E0E0)),
                shape: BoxShape.circle,
                boxShadow: badge.unlocked
                    ? [
                  BoxShadow(
                    color: badge.color.withOpacity(viewModel.isDarkMode ? 0.3 : 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
                border: Border.all(
                  color: viewModel.isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  badge.icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            if (badge.isNew && badge.unlocked)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (!badge.unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.5 : 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            badge.title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: badge.unlocked ? viewModel.textColor : viewModel.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}