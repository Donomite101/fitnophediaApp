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
    
    // Gradient backgrounds for types
    LinearGradient _getGradient() {
      switch (type.toLowerCase()) {
        case 'count_workouts':
        case 'workout':
          return const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 'diet':
          return const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        case 'streak':
          return const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        default:
          return const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      }
    }

    return Semantics(
      button: true,
      label: 'Challenge card: $title, status $status, $participants participants',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER with Gradient
              Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: _getGradient(),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getTypeIcon(type), size: 16, color: Colors.white),
                        ),
                        if (xpReward > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.flash_1, size: 10, color: Color(0xFFFFD700)),
                                const SizedBox(width: 4),
                                Text(
                                  '+$xpReward',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(
                      _getTypeLabel(type).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              // BODY
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      
                      Row(
                        children: [
                          Icon(Iconsax.people, size: 14, color: _muted),
                          const SizedBox(width: 4),
                          Text(
                            '$participants joined',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$percentage%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                            ),
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