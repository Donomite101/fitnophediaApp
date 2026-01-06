import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// Badge related imports
import '../models/badge_dialog.dart';
import '../models/badge_model.dart';
import '../models/streak_view_model.dart';
import '../service/all_badges_screen.dart';
import '../service/badge_item.dart';

// Model for the stats data
class MemberStats {
  final int bonusXP;
  final int totalCalories;
  final int totalReps;
  final int totalSets;
  final int totalWorkoutTime;
  final int totalWorkouts;
  final int totalXP;
  final DateTime? lastUpdated;

  MemberStats({
    required this.bonusXP,
    required this.totalCalories,
    required this.totalReps,
    required this.totalSets,
    required this.totalWorkoutTime,
    required this.totalWorkouts,
    required this.totalXP,
    this.lastUpdated,
  });

  factory MemberStats.fromMap(Map<String, dynamic> data) {
    return MemberStats(
      bonusXP: (data['bonusXP'] ?? 0).toInt(),
      totalCalories: (data['totalCalories'] ?? 0).toInt(),
      totalReps: (data['totalReps'] ?? 0).toInt(),
      totalSets: (data['totalSets'] ?? 0).toInt(),
      totalWorkoutTime: (data['totalWorkoutTime'] ?? 0).toInt(),
      totalWorkouts: (data['totalWorkouts'] ?? 0).toInt(),
      totalXP: (data['totalXP'] ?? data['totalXp'] ?? 0).toInt(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bonusXP': bonusXP,
      'totalCalories': totalCalories,
      'totalReps': totalReps,
      'totalSets': totalSets,
      'totalWorkoutTime': totalWorkoutTime,
      'totalWorkouts': totalWorkouts,
      'totalXP': totalXP,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }
}

class StreakHeader extends StatelessWidget {
  final StreakViewModel viewModel;
  final String gymId;
  final String memberId;

  const StreakHeader({
    super.key,
    required this.viewModel,
    required this.gymId,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(context),
          const SizedBox(height: 20),
          _buildStreakCounter(context),
          const SizedBox(height: 20),
          _buildStatsGrid(context),
          const SizedBox(height: 20),
          _buildAchievementsPreview(context),
          const SizedBox(height: 14),
          _buildBadgesRow(context),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Streak Dashboard',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: viewModel.textColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: viewModel.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.emoji_events_outlined,
                color: viewModel.accentOrange, size: 20),
            onPressed: () => _showAllBadges(context),
            padding: EdgeInsets.zero,
            iconSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCounter(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;
    final isMediumScreen = MediaQuery.of(context).size.width < 450;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: viewModel.isDarkMode
              ? [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E40AF),
            viewModel.primaryBlue,
          ]
              : [
            const Color(0xFFDBEAFE),
            const Color(0xFFE0F2FE),
            viewModel.lightBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: viewModel.primaryBlue.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STREAK',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: viewModel.isDarkMode
                            ? const Color(0xFF93C5FD)
                            : viewModel.darkBlue,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            '${viewModel.currentStreak}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: isSmallScreen ? 42 : isMediumScreen ? 46 : 52,
                              fontWeight: FontWeight.bold,
                              color: viewModel.textColor,
                              height: 0.9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'days',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: viewModel.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
            ],
          ),
          const SizedBox(height: 16),
          _buildResponsiveStatChips(context),
        ],
      ),
    );
  }

  Widget _buildResponsiveStatChips(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Wrap(
      spacing: isSmallScreen ? 6 : 8,
      runSpacing: isSmallScreen ? 6 : 8,
      alignment: WrapAlignment.start,
      children: [
        _buildStatChip(
          icon: Icons.star,
          text: 'Longest: ${viewModel.longestStreak}',
          color: viewModel.accentOrange,
          isSmallScreen: isSmallScreen,
        ),
        _buildStatChip(
          icon: Icons.bolt,
          text: 'Total: ${viewModel.totalWorkouts}',
          color: viewModel.accentGreen,
          isSmallScreen: isSmallScreen,
        ),
        if (MediaQuery.of(context).size.width > 320)
          _buildStatChip(
            icon: Icons.emoji_events,
            text: 'Badges: ${_getUnlockedBadgesCount()}',
            color: viewModel.primaryBlue,
            isSmallScreen: isSmallScreen,
          ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 11 : 12,
            color: color,
          ),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: viewModel.textColor,
            ),
          ),
        ],
      ),
    );
  }

  int _getUnlockedBadgesCount() {
    return viewModel.badges.where((badge) => badge.unlocked).length;
  }

  Widget _buildStatsGrid(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('totals')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingStats(context);
        }

        if (snapshot.hasError) {
          return _buildErrorStats(context, snapshot.error.toString());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyStats(context);
        }

        final stats = MemberStats.fromMap(
          snapshot.data!.data() as Map<String, dynamic>,
        );

        return _buildStatsContent(context, stats);
      },
    );
  }

  Widget _buildLoadingStats(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.textColor,
                ),
              ),
              SizedBox(
                width: isSmallScreen ? 14 : 16,
                height: isSmallScreen ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: viewModel.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              childAspectRatio: isSmallScreen ? 2.2 : 2.5,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return _buildStatItemSkeleton(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStats(BuildContext context, String error) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.textColor,
                ),
              ),
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: isSmallScreen ? 18 : 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // The stream will automatically retry on rebuild
            },
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Failed to load stats',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isSmallScreen ? 11 : 12,
                        color: viewModel.textColor,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Icon(
                    Icons.refresh,
                    color: Colors.red,
                    size: isSmallScreen ? 14 : 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStats(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.textColor,
                ),
              ),
              Icon(
                Icons.insights,
                color: viewModel.primaryBlue,
                size: isSmallScreen ? 18 : 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: viewModel.isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : viewModel.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: viewModel.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : viewModel.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  color: viewModel.secondaryTextColor,
                  size: isSmallScreen ? 30 : 36,
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                Text(
                  'No stats yet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: viewModel.textColor,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3 : 4),
                Text(
                  'Complete your first workout to see stats',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmallScreen ? 10 : 11,
                    color: viewModel.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(BuildContext context, MemberStats stats) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.textColor,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: viewModel.primaryBlue,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  if (stats.lastUpdated != null)
                    Text(
                      'Updated ${_formatTimeAgo(stats.lastUpdated!)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isSmallScreen ? 9 : 10,
                        color: viewModel.secondaryTextColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              childAspectRatio: isSmallScreen ? 2.2 : 2.5,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return _buildStatItem(index, stats, context);
            },
          ),
          const SizedBox(height: 12),
          // Copy stats button
          GestureDetector(
            onTap: () => _copyStatsToClipboard(context, stats),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8 : 10,
                horizontal: isSmallScreen ? 12 : 0,
              ),
              decoration: BoxDecoration(
                color: viewModel.isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : viewModel.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: viewModel.isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : viewModel.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.copy,
                    color: viewModel.primaryBlue,
                    size: isSmallScreen ? 12 : 14,
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  Text(
                    'Copy Stats',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: viewModel.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int index, MemberStats stats, BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    final Map<int, Map<String, dynamic>> statConfig = {
      0: {
        'title': 'Total XP',
        'value': stats.totalXP,
        'icon': Icons.stars,
        'color': viewModel.accentOrange,
        'unit': 'XP',
      },
      1: {
        'title': 'Workouts',
        'value': stats.totalWorkouts,
        'icon': Icons.fitness_center,
        'color': viewModel.accentGreen,
        'unit': '',
      },
      2: {
        'title': 'Calories',
        'value': stats.totalCalories,
        'icon': Icons.local_fire_department,
        'color': Colors.red,
        'unit': 'cal',
      },
      3: {
        'title': 'Workout Time',
        'value': _formatTime(stats.totalWorkoutTime),
        'icon': Icons.timer,
        'color': viewModel.primaryBlue,
        'unit': '',
      },
      4: {
        'title': 'Total Reps',
        'value': stats.totalReps,
        'icon': Icons.repeat,
        'color': Colors.purple,
        'unit': '',
      },
      5: {
        'title': 'Total Sets',
        'value': stats.totalSets,
        'icon': Icons.format_list_numbered,
        'color': Colors.amber,
        'unit': '',
      },
      6: {
        'title': 'Bonus XP',
        'value': stats.bonusXP,
        'icon': Icons.bolt,
        'color': Colors.teal,
        'unit': 'XP',
      },
    };

    final config = statConfig[index]!;
    final value = config['value'];
    final title = config['title'] as String;
    final icon = config['icon'] as IconData;
    final color = config['color'] as Color;
    final unit = config['unit'] as String;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: viewModel.isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: isSmallScreen ? 12 : 14,
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: viewModel.secondaryTextColor,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 1 : 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value.toString(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: viewModel.textColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      SizedBox(width: isSmallScreen ? 1 : 2),
                      Text(
                        unit,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isSmallScreen ? 9 : 10,
                          color: viewModel.secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemSkeleton(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: viewModel.isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 24 : 26,
            height: isSmallScreen ? 24 : 26,
            decoration: BoxDecoration(
              color: viewModel.isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isSmallScreen ? 35 : 40,
                  height: isSmallScreen ? 8 : 10,
                  decoration: BoxDecoration(
                    color: viewModel.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),
                Container(
                  width: isSmallScreen ? 50 : 60,
                  height: isSmallScreen ? 12 : 14,
                  decoration: BoxDecoration(
                    color: viewModel.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _copyStatsToClipboard(BuildContext context, MemberStats stats) async {
    final statsText = '''
🏆 Your Stats Summary:

🔥 Current Streak: ${viewModel.currentStreak} days
⚡ Total XP: ${stats.totalXP}
💪 Workouts Completed: ${stats.totalWorkouts}
🔥 Calories Burned: ${stats.totalCalories}
⏱️ Total Workout Time: ${_formatTime(stats.totalWorkoutTime)}
🔄 Total Reps: ${stats.totalReps}
📊 Total Sets: ${stats.totalSets}
⭐ Bonus XP: ${stats.bonusXP}
🚀 Longest Streak: ${viewModel.longestStreak} days

Keep up the amazing work! 💪
''';

    await Clipboard.setData(ClipboardData(text: statsText));

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stats copied to clipboard!',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
        ),
        backgroundColor: viewModel.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAchievementsPreview(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Recent Achievements',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: viewModel.textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => _showAllBadges(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: viewModel.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmallScreen ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: viewModel.primaryBlue,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 3 : 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isSmallScreen ? 9 : 10,
                  color: viewModel.primaryBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesRow(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;
    final featuredBadges = viewModel.badges
        .where((b) => b.category == 'Featured')
        .take(4)
        .toList();

    return SizedBox(
      height: isSmallScreen ? 90 : 99,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: featuredBadges.length,
        itemBuilder: (context, index) {
          final badge = featuredBadges[index];
          return GestureDetector(
            onTap: () => _showBadgeDetails(context, badge),
            child: Container(
              margin: EdgeInsets.only(right: isSmallScreen ? 10 : 12),
              child: BadgeItem(badge: badge, viewModel: viewModel),
            ),
          );
        },
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: BadgeUnlockDialog(badge: badge, isDarkMode: viewModel.isDarkMode),
      ),
    );
  }

  void _showAllBadges(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllBadgesScreen(
          badges: viewModel.badges,
          isDarkMode: viewModel.isDarkMode,
        ),
      ),
    );
  }
}