import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/streak_view_model.dart';

class CalendarWidget extends StatelessWidget {
  final StreakViewModel viewModel;

  const CalendarWidget({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(viewModel.selectedMonth.year, viewModel.selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(viewModel.selectedMonth.year, viewModel.selectedMonth.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final streakStart = viewModel.getStreakStartDate();

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
          _buildHeader(streakStart),
          const SizedBox(height: 20),
          _buildMonthNavigation(),
          const SizedBox(height: 20),
          _buildWeekdayHeaders(),
          const SizedBox(height: 12),
          _buildCalendarGrid(
            startingWeekday: startingWeekday,
            daysInMonth: daysInMonth,
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader(DateTime? streakStart) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Workout Calendar',
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
        if (streakStart != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [viewModel.primaryBlue, viewModel.darkBlue],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: viewModel.primaryBlue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Since ${DateFormat('MMM d').format(streakStart)}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMonthNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: viewModel.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: viewModel.secondaryTextColor, size: 20),
            onPressed: () => viewModel.updateSelectedMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Flexible(
            child: Text(
              DateFormat('MMMM yyyy').format(viewModel.selectedMonth),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: viewModel.textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: viewModel.secondaryTextColor, size: 20),
            onPressed: () => viewModel.updateSelectedMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
          .map((day) => SizedBox(
        width: 36,
        child: Center(
          child: Text(
            day,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: viewModel.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid({
    required int startingWeekday,
    required int daysInMonth,
  }) {
    return Column(
      children: List.generate(6, (weekIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - startingWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox(width: 36, height: 36);
              }

              final date = DateTime(
                viewModel.selectedMonth.year,
                viewModel.selectedMonth.month,
                dayNumber,
              );
              final hasWorkout = viewModel.hasWorkoutOnDate(date);
              final isInStreak = viewModel.isInCurrentStreak(date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: isInStreak
                      ? LinearGradient(
                    colors: [viewModel.primaryBlue, viewModel.darkBlue],
                  )
                      : null,
                  color: hasWorkout && !isInStreak
                      ? viewModel.workoutColor.withOpacity(viewModel.isDarkMode ? 0.9 : 0.8)
                      : null,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: viewModel.primaryBlue, width: 2)
                      : null,
                  boxShadow: isInStreak
                      ? [
                    BoxShadow(
                      color: viewModel.primaryBlue.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : hasWorkout
                      ? [
                    BoxShadow(
                      color: viewModel.workoutColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: (isInStreak || hasWorkout) ? Colors.white : viewModel.textColor,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendItem(viewModel.primaryBlue, 'Current Streak'),
        _buildLegendItem(viewModel.workoutColor, 'Workout Day'),
        _buildLegendItem(viewModel.textColor.withOpacity(0.1), 'Today',
            hasBorder: true),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: hasBorder ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: viewModel.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}