import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'water_glass_widget.dart';
import '../services/hydration_alarm_service.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
              height: 80,
              width: 45,
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
                    GestureDetector(
                      onTap: () => _showGoalDialog(context),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: (currentMl / 1000).toStringAsFixed(1), // Convert to L
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20, // Larger, more prominent
                                fontWeight: FontWeight.w600, // Premium weight
                                color: textColor,
                                height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: " / ${(goalMl / 1000).toStringAsFixed(1)} L", // Convert to L
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: subTextColor,
                              ),
                            ),
                            WidgetSpan(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.edit,
                                  size: 16, // Increased from 12
                                  color: subTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12), // Increased spacing
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearPercentIndicator(
                    lineHeight: 6.0, // Slightly thicker bar
                    percent: progress,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    progressColor: _getStatusColor(currentMl, goalMl),
                    padding: EdgeInsets.zero,
                    barRadius: const Radius.circular(4),
                    animation: true,
                  ),
                ),
                
                const SizedBox(height: 12), // Increased spacing
                
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
        padding: const EdgeInsets.symmetric(vertical: 6), // Reduced padding
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add,
              size: 14, // Smaller icon
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 1),
            Text(
              "${amount}ml",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11, // Smaller font
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDialog(BuildContext context) {
    // Initialize with current goal in Liters
    final TextEditingController controller = TextEditingController(
      text: (goalMl / 1000).toStringAsFixed(1),
    );
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: repo.getReminderSettings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(); // Wait for data

          // Initialize state from prefs
          // Default to true if null (first time)
          bool enableReminders = snapshot.data!['enabled'] ?? true; 
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Daily Hydration Goal",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Set a goal between 1.5 L and 10.0 L",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Input Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "0.0",
                            ),
                          ),
                        ),
                        Text(
                          "Liters",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Recommended Button
                  InkWell(
                    onTap: () {
                      controller.text = "3.0";
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.magic_star,
                            size: 16,
                            color: isDark ? Colors.blue[200] : Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Use Recommended (3.0 L)",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue[100] : Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                  const SizedBox(height: 16),

                  // Reminders Section
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
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            "Get notified to drink water",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: enableReminders,
                        onChanged: (val) {
                          setState(() => enableReminders = val);
                        },
                        activeColor: const Color(0xFF2196F3),
                      ),
                    ],
                  ),
                  
                  if (enableReminders) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            "Start Time",
                            startTime,
                            (t) => setState(() => startTime = t),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            "End Time",
                            endTime,
                            (t) => setState(() => endTime = t),
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final val = double.tryParse(controller.text);
                            if (val != null) {
                              if (val < 1.5) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Goal cannot be less than 1.5 Liters")),
                                );
                                return;
                              }
                              if (val > 10.0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Goal cannot exceed 10 Liters")),
                                );
                                return;
                              }
                              
                              // Handle Reminders in background
                              final alarmService = HydrationAlarmService();
                              
                              // Save Settings
                              await repo.saveReminderSettings(
                                enableReminders,
                                startTime.hour,
                                startTime.minute,
                                endTime.hour,
                                endTime.minute,
                              );

                              // Convert L to ml for storage
                              onGoalChange((val * 1000).toInt());
                              
                              // Close dialog immediately
                              Navigator.pop(context);
                              
                              // Schedule alarms in background (don't await)
                              if (enableReminders) {
                                debugPrint('Scheduling reminders in background. Start: ${startTime.format(context)}, End: ${endTime.format(context)}');
                                alarmService.initialize().then((_) {
                                  return alarmService.scheduleHydrationReminders(
                                    startTime: startTime,
                                    endTime: endTime,
                                  );
                                }).catchError((e) {
                                  debugPrint('Error scheduling reminders: $e');
                                });
                              } else {
                                alarmService.initialize().then((_) {
                                  return alarmService.cancelReminders();
                                }).catchError((e) {
                                  debugPrint('Error canceling reminders: $e');
                                });
                              }

                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Save Goal",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildTimePicker(
    BuildContext context,
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
    bool isDark,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimeChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Iconsax.clock,
                  size: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 6),
                Text(
                  time.format(context),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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


