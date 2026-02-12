import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkoutCompletionOverlay extends StatelessWidget {
  final int totalDurationSeconds;
  final int totalExercises;
  final int totalSets;
  final int totalReps;
  final double totalVolume; // Total weight lifted
  final String workoutName;
  final VoidCallback onContinue;

  const WorkoutCompletionOverlay({
    Key? key,
    required this.totalDurationSeconds,
    required this.totalExercises,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
    required this.workoutName,
    required this.onContinue,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Title
              Text(
                "WORKOUT COMPLETE!",
                style: GoogleFonts.bebasNeue(
                  fontSize: 48,
                  letterSpacing: 2,
                  color: textColor,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                workoutName.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00E676),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Stats Grid
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildStat("DURATION", _formatDuration(totalDurationSeconds), Iconsax.timer_1, const Color(0xFF00E676), isDark)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildStat("EXERCISES", totalExercises.toString(), Iconsax.activity, Colors.blueAccent, isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildStat("TOTAL SETS", totalSets.toString(), Iconsax.flash_1, Colors.orangeAccent, isDark)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildStat("TOTAL REPS", totalReps.toString(), Iconsax.chart_21, Colors.purpleAccent, isDark)),
                      ],
                    ),
                    if (totalVolume > 0) ...[
                      const SizedBox(height: 24),
                      _buildStat("TOTAL VOLUME", "${totalVolume.toStringAsFixed(0)} KG", Iconsax.weight_1, const Color(0xFFFF6B6B), isDark),
                    ],
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 12,
                    shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "CONTINUE",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Iconsax.arrow_right_1, size: 20),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
