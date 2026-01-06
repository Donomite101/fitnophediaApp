import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/streak_view_model.dart';

// Model for challenge data
class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final int targetValue;
  final int currentValue;
  final String icon;
  final bool isActive;
  final DateTime? endDate;
  final int rewardXP;
  final bool isCompleted;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.icon,
    required this.isActive,
    this.endDate,
    required this.rewardXP,
    required this.isCompleted,
  });

  factory ChallengeModel.fromMap(Map<String, dynamic> data, String id) {
    return ChallengeModel(
      id: id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? 'No Description',
      type: data['type'] ?? 'general',
      targetValue: (data['targetValue'] ?? 0).toInt(),
      currentValue: (data['currentValue'] ?? 0).toInt(),
      icon: data['icon'] ?? 'fitness_center',
      isActive: data['isActive'] ?? false,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      rewardXP: (data['rewardXP'] ?? 0).toInt(),
      isCompleted: (data['isCompleted'] ?? false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'icon': icon,
      'isActive': isActive,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'rewardXP': rewardXP,
      'isCompleted': isCompleted,
    };
  }

  double get progress => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

class ChallengesSection extends StatelessWidget {
  final StreakViewModel viewModel;
  final String gymId;
  final String memberId;

  const ChallengesSection({
    Key? key,
    required this.viewModel,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('global_challenges')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSection();
        }

        if (snapshot.hasError) {
          return _buildErrorSection(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptySection();
        }

        final challenges = snapshot.data!.docs.map((doc) {
          return ChallengeModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        // Fetch member's progress for each challenge
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('gyms')
              .doc(gymId)
              .collection('members')
              .doc(memberId)
              .collection('challenge_progress')
              .doc('current')
              .snapshots(),
          builder: (context, progressSnapshot) {
            if (progressSnapshot.hasData && progressSnapshot.data!.exists) {
              final progressData = progressSnapshot.data!.data() as Map<String, dynamic>;

              // Update challenges with member's progress
              final updatedChallenges = challenges.map((challenge) {
                final progress = progressData[challenge.id] ?? {};
                final currentValue = progress['currentValue'] ?? challenge.currentValue;
                final isCompleted = progress['isCompleted'] ?? challenge.isCompleted;

                return ChallengeModel(
                  id: challenge.id,
                  title: challenge.title,
                  description: challenge.description,
                  type: challenge.type,
                  targetValue: challenge.targetValue,
                  currentValue: currentValue is num ? currentValue.toInt() : 0,
                  icon: challenge.icon,
                  isActive: challenge.isActive,
                  endDate: challenge.endDate,
                  rewardXP: challenge.rewardXP,
                  isCompleted: isCompleted is bool ? isCompleted : false,
                );
              }).toList();

              return _buildSectionContent(updatedChallenges);
            }

            return _buildSectionContent(challenges);
          },
        );
      },
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Weekly Challenges',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: viewModel.textColor,
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChallengeItemSkeleton(),
          const SizedBox(height: 12),
          _buildChallengeItemSkeleton(),
          const SizedBox(height: 12),
          _buildChallengeItemSkeleton(),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Weekly Challenges',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: viewModel.textColor,
                  ),
                ),
              ),
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load challenges. Please try again.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: viewModel.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Weekly Challenges',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: viewModel.textColor,
                  ),
                ),
              ),
              Icon(
                Icons.emoji_events_outlined,
                color: viewModel.primaryBlue,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: viewModel.isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : viewModel.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: viewModel.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : viewModel.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: viewModel.secondaryTextColor,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'No Active Challenges',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: viewModel.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New challenges will appear here soon!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
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

  Widget _buildSectionContent(List<ChallengeModel> challenges) {
    // Calculate completed challenges count
    final completedCount = challenges.where((c) => c.isCompleted).length;
    final totalCount = challenges.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Weekly Challenges',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: viewModel.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [viewModel.primaryBlue, viewModel.darkBlue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount/$totalCount Complete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...challenges.map((challenge) {
            return Column(
              children: [
                _buildChallengeItem(challenge),
                if (challenge != challenges.last) const SizedBox(height: 12),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildChallengeItemSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: viewModel.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: viewModel.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeItem(ChallengeModel challenge) {
    final progress = challenge.progress;
    final completed = challenge.isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? viewModel.primaryBlue.withOpacity(0.3)
              : (viewModel.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          width: 1,
        ),
        boxShadow: completed
            ? [
          BoxShadow(
            color: viewModel.primaryBlue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: completed
                  ? LinearGradient(
                colors: [viewModel.primaryBlue, viewModel.darkBlue],
              )
                  : null,
              color: completed ? null : (viewModel.isDarkMode ? const Color(0xFF333333) : viewModel.lightGrey),
              borderRadius: BorderRadius.circular(12),
              boxShadow: completed
                  ? [
                BoxShadow(
                  color: viewModel.primaryBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Icon(
              completed ? Icons.check_circle : _getIcon(challenge.icon),
              color: completed ? Colors.white : viewModel.secondaryTextColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: viewModel.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: viewModel.secondaryTextColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: viewModel.isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed ? viewModel.primaryBlue : viewModel.primaryBlue.withOpacity(0.6),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${challenge.currentValue}/${challenge.targetValue}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: completed ? viewModel.primaryBlue : viewModel.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                if (challenge.rewardXP > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${challenge.rewardXP} XP',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                      if (challenge.endDate != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.timer,
                          color: viewModel.secondaryTextColor,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeLeft(challenge.endDate!),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: viewModel.secondaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'local_fire_department':
      case 'fire':
        return Icons.local_fire_department;
      case 'wb_sunny':
      case 'sun':
        return Icons.wb_sunny_outlined;
      case 'fitness_center':
      case 'fitness':
        return Icons.fitness_center;
      case 'timer':
      case 'time':
        return Icons.timer;
      case 'directions_run':
      case 'run':
        return Icons.directions_run;
      case 'speed':
      case 'bolt':
        return Icons.bolt;
      case 'water':
      case 'water_drop':
        return Icons.water_drop;
      case 'check':
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.emoji_events_outlined;
    }
  }

  String _formatTimeLeft(DateTime endDate) {
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m left';
    } else {
      return 'Ending soon';
    }
  }
}