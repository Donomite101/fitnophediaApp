import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'water_glass_widget.dart';
import '../services/hydration_alarm_service.dart';
import '../services/notification_service.dart';

import '../repository/nutrition_repository.dart';

class CompactHydrationCard extends StatelessWidget {
  final double currentMl;
  final double goalMl;
  final double weeklyAverage;
  final bool isDark;
  final NutritionRepository repo; // Add repo
  final Function(int) onAddWater;
  final Function(int) onGoalChange;
  final VoidCallback onReset;
  final VoidCallback? onUndo;

  const CompactHydrationCard({
    super.key,
    required this.currentMl,
    required this.goalMl,
    this.weeklyAverage = 0,
    required this.isDark,
    required this.repo, // Add repo
    required this.onAddWater,
    required this.onGoalChange,
    required this.onReset,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final remainingMl = (goalMl - currentMl).clamp(0, goalMl);
    final progress = (currentMl / goalMl).clamp(0.0, 1.0);
    
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20), // Slightly more compact corners
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFF2196F3).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(isDark ? 0.05 : 0.08),
            blurRadius: 15, // Reduced blur
            offset: const Offset(0, 6), // Reduced offset
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Water Glass (Compact but taller)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: WaterGlassWidget(
              percentage: progress,
              height: 65, // Reduced from 80
              width: 40,  // Reduced from 45
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 16),
          
          // Right: Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row (Title + Reset + Undo + Count)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Hydration",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(width: 2), // Reduced from 4
                        // Reset Button
                        InkWell(
                          onTap: onReset,
                          child: Padding(
                            padding: const EdgeInsets.all(2.0), // Reduced from 4.0
                            child: Icon(
                              Icons.refresh,
                              size: 20,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        if (onUndo != null) ...[
                          const SizedBox(width: 2), // Reduced from 4
                          // Undo Button
                          InkWell(
                            onTap: onUndo,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0), // Reduced from 4.0
                              child: Icon(
                                Icons.undo,
                                size: 20,
                                color: subTextColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Count & Goal Setting (Liters)
                    Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: (currentMl / 1000).toStringAsFixed(1),
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  height: 1.0,
                                ),
                              ),
                              TextSpan(
                                text: " / ${(goalMl / 1000).toStringAsFixed(1)} L",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showGoalDialog(context),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Iconsax.setting_2,
                                size: 18,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8), // Reduced from 12
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearPercentIndicator(
                    lineHeight: 6.0, // Reduced from 8.0
                    percent: progress,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    progressColor: _getStatusColor(currentMl, goalMl),
                    padding: EdgeInsets.zero,
                    barRadius: const Radius.circular(4),
                    animation: true,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                
                const SizedBox(height: 8), // Reduced from 12
                
                // Smart Message (Compact)
                if (_getSmartMessage(currentMl, goalMl).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.info_circle,
                          size: 12,
                          color: isDark ? Colors.blue[200] : Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getSmartMessage(currentMl, goalMl),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.blue[100] : Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Quick Add Buttons (Inline Row)
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAddButton(context, 250, isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickAddButton(context, 500, isDark),
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

  Widget _buildQuickAddButton(BuildContext context, int amount, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (currentMl >= goalMl) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Daily hydration goal already reached!")),
          );
          return;
        }
        
        double amountToAdd = amount.toDouble();
        if (currentMl + amount > goalMl) {
          amountToAdd = goalMl - currentMl;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Goal reached! Capped at limit.")),
          );
        }
        onAddWater(amountToAdd.toInt());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 10
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(isDark ? 0.05 : 0.03),
          borderRadius: BorderRadius.circular(12), // More compact
          border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(isDark ? 0.15 : 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.add_square,
              size: 14, // Reduced from 16
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(width: 4), // Reduced from 8
            Text(
              "${amount}ml",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12, // Reduced from 13
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: (goalMl / 1000).toStringAsFixed(1),
    );
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: repo.getReminderSettings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          bool enableReminders = snapshot.data!['enabled'] ?? true; 
          bool isRepeating = snapshot.data!['isRepeating'] ?? true;
          TimeOfDay startTime = TimeOfDay(
            hour: snapshot.data!['startHour'] ?? 8,
            minute: snapshot.data!['startMinute'] ?? 0,
          );
          TimeOfDay endTime = TimeOfDay(
            hour: snapshot.data!['endHour'] ?? 20,
            minute: snapshot.data!['endMinute'] ?? 0,
          );

          return StatefulBuilder(
            builder: (context, setState) => Dialog(
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with subtle gradient/accent
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Hydration Goal",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Iconsax.drop, size: 24, color: Color(0xFF2196F3)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Customize your daily intake & reminders",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Liters Input Section
                            Text(
                              "Daily Target",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                        letterSpacing: -0.5,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "0.0",
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Liters",
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Recommended Presets
                            Row(
                              children: [
                                _buildGoalPreset("2.0 L", () => controller.text = "2.0"),
                                const SizedBox(width: 8),
                                _buildGoalPreset("3.0 L", () => controller.text = "3.0"),
                                const SizedBox(width: 8),
                                _buildGoalPreset("4.0 L", () => controller.text = "4.0"),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            Divider(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                            const SizedBox(height: 24),

                            // Reminders Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Hydration Reminders",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      "Push notifications to stay hydrated",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Transform.scale(
                                  scale: 0.85,
                                  child: Switch(
                                    value: enableReminders,
                                    onChanged: (val) => setState(() => enableReminders = val),
                                    activeColor: const Color(0xFF2196F3),
                                    trackColor: MaterialStateProperty.resolveWith((states) {
                                      if (states.contains(MaterialState.selected)) {
                                        return const Color(0xFF2196F3).withOpacity(0.5);
                                      }
                                      return isDark ? Colors.white10 : Colors.black12;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            
                            if (enableReminders) ...[
                              const SizedBox(height: 20),
                              // Daily Repeat Button/Toggle
                              InkWell(
                                onTap: () => setState(() => isRepeating = !isRepeating),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isRepeating 
                                      ? const Color(0xFF2196F3).withOpacity(0.1) 
                                      : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100]),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isRepeating 
                                        ? const Color(0xFF2196F3).withOpacity(0.2) 
                                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isRepeating ? Iconsax.refresh_2 : Iconsax.calendar_1,
                                        size: 18,
                                        color: isRepeating ? const Color(0xFF2196F3) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isRepeating ? "Remind Daily" : "Remind Today Only",
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isRepeating ? const Color(0xFF2196F3) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isRepeating)
                                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF2196F3)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimePicker(
                                      context,
                                      "Active From",
                                      startTime,
                                      (t) => setState(() => startTime = t),
                                      isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTimePicker(
                                      context,
                                      "Active Until",
                                      endTime,
                                      (t) => setState(() => endTime = t),
                                      isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 32),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text(
                                      "Discard",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final val = double.tryParse(controller.text);
                                      if (val == null || val < 1.0 || val > 15.0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Enter a valid goal between 1L and 15L",
                                              style: TextStyle(
                                                color: isDark ? Colors.black : Colors.white,
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                            backgroundColor: isDark ? Colors.white : Colors.black,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      await repo.saveReminderSettings(
                                        enableReminders,
                                        startTime.hour,
                                        startTime.minute,
                                        endTime.hour,
                                        endTime.minute,
                                        isRepeating,
                                      );

                                      onGoalChange((val * 1000).toInt());
                                      Navigator.pop(context);
                                      
                                      // Trigger scheduling
                                      final alarmService = HydrationAlarmService();
                                      if (enableReminders) {
                                        alarmService.initialize().then((_) {
                                          return alarmService.scheduleHydrationReminders(
                                            startTime: startTime,
                                            endTime: endTime,
                                          );
                                        });
                                      } else {
                                        alarmService.cancelReminders();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2196F3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Save Changes",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildGoalPreset(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context,
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF2196F3),
                      brightness: isDark ? Brightness.dark : Brightness.light,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onTimeChanged(picked);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Iconsax.clock,
                    size: 16,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTime12Hrs(time),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime12Hrs(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $period";
  }

  Color _getStatusColor(double current, double goal) {
    final percentage = (current / goal).clamp(0.0, 1.0);
    final hour = DateTime.now().hour;

    // Warning color (Orange) if behind schedule
    if (hour >= 10 && hour < 14 && percentage < 0.4) return Colors.orange;
    if (hour >= 14 && hour < 18 && percentage < 0.6) return Colors.orange;
    if (hour >= 18 && percentage < 0.8) return Colors.orange;

    // Default success/progress color (Blue)
    return const Color(0xFF2196F3);
  }

  String _getSmartMessage(double current, double goal) {
    final percentage = (current / goal).clamp(0.0, 2.0); // Allow up to 200% for logic
    final hour = DateTime.now().hour;

    // Over-hydration Warning
    if (current > goal + 500) {
      return "Whoa! You've exceeded your goal significantly. Don't overdo it!";
    }

    if (percentage >= 1.0) {
      // Weekly comparison if available
      if (weeklyAverage > 0 && current > weeklyAverage) {
        return "Goal hit! You're beating your weekly average! 🎉";
      }
      return "You hit your hydration goal! Great job! 🎉";
    }

    // Weekly comparison for lower intake
    if (weeklyAverage > 0 && current < weeklyAverage * 0.5 && hour > 18) {
       return "Lower than your usual intake. Sip some water.";
    }

    if (hour < 10) {
      if (percentage < 0.1) return "Start your day with a glass of water!";
      return "Good start! Keep sipping.";
    } else if (hour < 14) {
      if (percentage < 0.4) return "You're a bit behind. Drink up!";
      return "Stay hydrated to keep your energy up.";
    } else if (hour < 18) {
      if (percentage < 0.6) return "Don't forget to drink water this afternoon.";
      return "You're doing well, keep it up!";
    } else {
      if (percentage < 0.8) return "Catch up on your hydration before bed.";
      return "Almost there! Finish strong.";
    }
  }
}


