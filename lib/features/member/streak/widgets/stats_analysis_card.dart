import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../models/streak_view_model.dart';

class StatsAnalysisCard extends StatelessWidget {
  final StreakViewModel viewModel;

  const StatsAnalysisCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) return const SizedBox.shrink();

    // 1. Calculate Consistency Score (Workouts in last 30 days / 30)
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final workoutsLast30Days = viewModel.workoutDates
        .where((d) => d.isAfter(thirtyDaysAgo))
        .length;
    final consistencyScore = (workoutsLast30Days / 30 * 100).clamp(0, 100).toInt();

    // 2. Trend Analysis
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final workoutsLast7Days = viewModel.workoutDates
        .where((d) => d.isAfter(sevenDaysAgo))
        .length;
    
    // Previous 7 days
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    final workoutsPrevious7Days = viewModel.workoutDates
        .where((d) => d.isAfter(fourteenDaysAgo) && d.isBefore(sevenDaysAgo))
        .length;

    final trendUp = workoutsLast7Days >= workoutsPrevious7Days;
    final trendPercent = workoutsPrevious7Days == 0 
        ? (workoutsLast7Days * 100) 
        : (((workoutsLast7Days - workoutsPrevious7Days) / workoutsPrevious7Days) * 100).abs().toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: viewModel.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: viewModel.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(viewModel.isDarkMode ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stats Analysis',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: viewModel.textColor,
                    ),
                  ),
                  Text(
                    'AI-powered performance insights',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: viewModel.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: viewModel.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.radar_2, color: viewModel.primaryBlue, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Row for Progress Indicators
          Row(
            children: [
              Expanded(
                child: _buildCircularMetric(
                  context: context,
                  label: 'Consistency',
                  value: '$consistencyScore%',
                  percent: consistencyScore / 100,
                  color: viewModel.accentGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCircularMetric(
                  context: context,
                  label: 'Power Level',
                  value: _getPowerLevel(viewModel.totalWorkouts),
                  percent: (viewModel.totalWorkouts / 100).clamp(0.0, 1.0),
                  color: viewModel.accentOrange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Divider(color: viewModel.isDarkMode ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 16),
          
          // Insight Message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: trendUp ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  trendUp ? Iconsax.trend_up : Iconsax.trend_down,
                  color: trendUp ? Colors.green : Colors.orange,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trendUp 
                        ? 'Momentum is building!'
                        : 'Motivation check needed!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: viewModel.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTrendMessage(trendUp, trendPercent, workoutsLast7Days),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: viewModel.secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMetric({
    required BuildContext context,
    required String label,
    required String value,
    required double percent,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 5,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Icon(
                label == 'Consistency' ? Iconsax.activity : Iconsax.fatrows,
                size: 18,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: viewModel.textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: viewModel.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getPowerLevel(int workouts) {
    if (workouts < 5) return 'Recruit';
    if (workouts < 15) return 'Athlete';
    if (workouts < 30) return 'Elite';
    if (workouts < 50) return 'Master';
    return 'Legend';
  }

  String _getTrendMessage(bool up, int percent, int count) {
    if (up) {
      if (count == 0) return "Start a workout today to begin your analysis!";
      return "Your activity is up by $percent% compared to last week. You've hit the gym $count times in 7 days.";
    } else {
      return "You're slightly behind last week's pace. Don't break the chain now!";
    }
  }
}
