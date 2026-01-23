import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class HorizontalCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool isDark;

  const HorizontalCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Calculate start of the week (Monday)
    final startDate = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (index) => startDate.add(Duration(days: index)));
    final days = ["M", "T", "W", "T", "F", "S", "S"];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(7, (index) {
              final date = weekDays[index];
              final isSelected = _isSameDay(date, selectedDate);
              final isToday = _isSameDay(date, now);
              final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected(date),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        days[index],
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: isSelected 
                              ? const Color(0xFF4CAF50) 
                              : (isDark ? Colors.grey : Colors.grey[600]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected 
                              ? const Color(0xFF4CAF50) 
                              : (isPast 
                                  ? (isDark ? Colors.white10 : Colors.grey[200]) 
                                  : Colors.transparent),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF4CAF50) 
                                : (isDark ? Colors.white24 : Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: isSelected
                              ? Text(
                                  "${date.day}",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : (isPast 
                                  ? Icon(Iconsax.tick_circle, size: 14, color: isDark ? Colors.white : Colors.black)
                                  : Text(
                                      "${date.day}",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    )),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
