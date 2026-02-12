import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/exercise_model.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final String gymId;
  final String memberId;
  final Exercise exercise;
  final bool isPremade;

  const ExerciseDetailScreen({
    Key? key,
    required this.exercise, required this.gymId, required this.memberId, required this.isPremade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    final accentColor = const Color(0xFF00C853);
    final subtleTextColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          "EXERCISE PROTOCOL",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.5,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
                  // Section Label
                  const Text(
                    "EXERCISE IDENTIFICATION",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Color(0xFF00C853),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Title
                  Text(
                    exercise.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      color: textColor,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.activity, size: 12, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          exercise.category.isEmpty ? "STANDARD" : exercise.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            fontFamily: 'Outfit',
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tag Grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _premiumTagChip(exercise.bodyPart, Iconsax.user_tick, isDark),
                      _premiumTagChip(exercise.equipment, Iconsax.weight, isDark),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Video Integration (Premium Action Style)
                  if (exercise.videoUrl.isNotEmpty)
                    _premiumVideoButton(context, accentColor),

                  const SizedBox(height: 48),

                  // Training Protocol Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "EXECUTION PROTOCOL",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        "${exercise.steps.length} STEPS",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: subtleTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Column(
                    children: exercise.steps.asMap().entries.map((entry) {
                      return _premiumStepTile(entry.key + 1, entry.value, isDark, textColor, accentColor);
                    }).toList(),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
    );
  }

  Widget _premiumTagChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumVideoButton(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/exerciseVideoPlayer",
          arguments: exercise.videoUrl,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: accentColor.withOpacity(0.1),
          border: Border.all(color: accentColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WATCH DEMONSTRATION",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      color: Color(0xFF00C853),
                    ),
                  ),
                  Text(
                    "Clear visual form guidance",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: accentColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accentColor.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _premiumStepTile(int index, String step, bool isDark, Color textColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor.withOpacity(0.85),
                    height: 1.6,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (index < exercise.steps.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      height: 1,
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
