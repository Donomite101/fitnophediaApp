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
    final double progress = targetValue > 0 ? (currentValue / targetValue).clamp(0, 1) : 0.0;
    final statusChipColor = _statusColor(status);
    final typeColor = _typeColor;

    return Semantics(
      button: true,
      label: 'Challenge card: $title, status $status, $participants participants',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: typeColor.withOpacity(0.12),
        child: Container(
          width: 420,
          height: 340, // Increased from 300 to 340 (+40px)
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.grey.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP SECTION: Header (70px) - Increased
              Container(
                width: double.infinity,
                height: 70, // Increased from 60 to 70
                padding: const EdgeInsets.all(14), // Increased padding
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor.withOpacity(0.12), typeColor.withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 42, // Increased from 36 to 42
                      width: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeColor.withOpacity(0.18), typeColor.withOpacity(0.06)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12), // Increased radius
                      ),
                      child: Icon(_getTypeIcon(type), size: 20, color: typeColor), // Increased icon size
                    ),
                    const SizedBox(width: 12), // Increased spacing
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16, // Increased from 14 to 16
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3), // Increased spacing
                          Text(
                            _getTypeLabel(type),
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12, // Increased from 10 to 12
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (xpReward > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Increased padding
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10), // Increased radius
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, size: 14, color: Colors.orange), // Increased icon
                            const SizedBox(width: 5), // Increased spacing
                            Text(
                              '$xpReward XP',
                              style: const TextStyle(
                                fontSize: 12, // Increased from 10 to 12
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // MIDDLE SECTION: Content (200px) - Increased from 160px
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14), // Increased padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description - More space
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13.5, // Increased from 12 to 13.5
                            height: 1.5, // Increased line height
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 5, // Increased from 4 to 5 lines
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 14), // Increased spacing

                      // Progress section - Larger
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progress',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12.5, // Increased from 11 to 12.5
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      targetValue > 0 ? '$currentValue/$targetValue' : '—',
                                      style: TextStyle(
                                        color: _textPrimary,
                                        fontSize: 13.5, // Increased from 12 to 13.5
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5), // Increased spacing
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6), // Increased radius
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8, // Increased from 6 to 8
                                    backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14), // Increased spacing

                          // Right side badges - Larger
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Increased padding
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10), // Increased radius
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Iconsax.people, size: 10, color: Colors.purple), // Increased icon
                                    const SizedBox(width: 6), // Increased spacing
                                    Text(
                                      '$participants',
                                      style: TextStyle(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5, // Increased from 11 to 12.5
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4), // Increased spacing
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Increased padding
                                decoration: BoxDecoration(
                                  color: statusChipColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10), // Increased radius
                                  border: Border.all(
                                    color: statusChipColor.withOpacity(0.18),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusChipColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9, // Increased from 10 to 12
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}