import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int participants;
  final String status;
  final String type;
  final String section;
  final int xpReward;
  final int targetValue;
  final int currentValue; // current progress
  final VoidCallback onTap;
  final bool isDarkMode;

  const ChallengeCard({
    Key? key,
    required this.title,
    required this.description,
    this.startDate,
    this.endDate,
    required this.participants,
    required this.status,
    required this.type,
    this.section = 'starter',
    this.xpReward = 0,
    this.targetValue = 0,
    this.currentValue = 0,
    required this.onTap,
    required this.isDarkMode,
  }) : super(key: key);

  Color get _cardBackground => isDarkMode ? const Color(0xFF0F1722) : Colors.white;
  Color get _textPrimary => isDarkMode ? Colors.white : Colors.black87;
  Color get _muted => isDarkMode ? Colors.white70 : Colors.black54;

  Color get _typeColor {
    switch (type.toLowerCase()) {
      case 'count_workouts':
      case 'workout':
        return Colors.blue;
      case 'diet':
        return Colors.green;
      case 'streak':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('active') || s.contains('ongoing')) return Colors.green;
    if (s.contains('upcoming') || s.contains('start')) return Colors.blue;
    if (s.contains('paused')) return Colors.orange;
    if (s.contains('ended') || s.contains('finished')) return Colors.red;
    return Colors.grey;
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'count_workouts':
        return 'Workouts';
      case 'diet':
        return 'Diet';
      case 'streak':
        return 'Streak';
      default:
        final withSpaces = type.replaceAll('_', ' ');
        return withSpaces.splitMapJoin(
          RegExp(r'(^\w)|(_\w)'),
          onMatch: (m) => m[0]!.replaceAll('_', '').toUpperCase(),
          onNonMatch: (n) => n,
        );
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'count_workouts':
      case 'workout':
        return Iconsax.weight;
      case 'diet':
        return Iconsax.menu_board;
      case 'streak':
        return Iconsax.like;
      default:
        return Iconsax.award;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
    final int percentage = (progress * 100).round();
    final typeColor = _typeColor;

    return Semantics(
      button: true,
      label: 'Challenge card: $title, status $status, $participants participants',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: typeColor.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Badge & XP
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getTypeLabel(type).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: typeColor,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    if (xpReward > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconsax.flash_1, size: 10, color: Color(0xFFFFD700)),
                            const SizedBox(width: 4),
                            Text(
                              '+$xpReward XP',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // MAIN CONTENT: Title & Participants
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Iconsax.people, size: 14, color: _muted),
                        const SizedBox(width: 6),
                        Text(
                          '$participants participants',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // FOOTER: Clean Progress Section
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}