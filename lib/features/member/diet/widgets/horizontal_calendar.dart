import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class HorizontalCalendar extends StatefulWidget {
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
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar> {
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.selectedDate;
  }

  void _onPreviousWeek() {
    setState(() {
      _focusedDate = _focusedDate.subtract(const Duration(days: 7));
    });
  }

  void _onNextWeek() {
    setState(() {
      _focusedDate = _focusedDate.add(const Duration(days: 7));
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate start of the week for the focused date (Sunday based)
    final startDate = _focusedDate.subtract(Duration(days: _focusedDate.weekday % 7));
    final weekDays = List.generate(7, (index) => startDate.add(Duration(days: index)));
    final days = ["S", "M", "T", "W", "T", "F", "S"];

    final textColor = widget.isDark ? Colors.white : Colors.black;
    final subTextColor = widget.isDark ? Colors.grey[500] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final isSelected = _isSameDay(date, widget.selectedDate);
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                widget.onDateSelected(date);
                setState(() {
                  _focusedDate = date;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFF00C853) // Primary Green
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      days[index],
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: isSelected 
                            ? Colors.white.withOpacity(0.9) 
                            : subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
