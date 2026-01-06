import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StreakCelebrationOverlay extends StatelessWidget {
  final int currentStreak;
  final List<bool> activeDays; // can be any length, we'll normalize
  final VoidCallback onContinue;

  const StreakCelebrationOverlay({
    Key? key,
    required this.currentStreak,
    required this.activeDays,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Normalize to length 7: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    final normalizedActiveDays = _normalizeActiveDays(activeDays);

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Fire Icon/Animation
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect layers
                    Container(
                      width: 80,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6D00).withOpacity(0.4),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFAB00).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    // Fire animation
                    Lottie.asset(
                      'assets/animations/streak_fire.json',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Streak Number
              Text(
                currentStreak.toString(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 88,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00E676),
                  height: 1,
                  letterSpacing: -2,
                ),
              ),

              const SizedBox(height: 8),

              // Streak Label
              const Text(
                'DAY STREAK',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00E676),
                  letterSpacing: 3,
                ),
              ),

              const Spacer(flex: 1),

              // Week Progress Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF1A1A1A),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Days Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        return _buildDayCircle(
                          dayLabels[index],
                          normalizedActiveDays[index],
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Message
                    const Text(
                      'Keep it going!\nYou\'re building an amazing habit 💪',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Continue Button
              GestureDetector(
                onTap: onContinue,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Ensures we always have exactly 7 booleans for M–S–S.
  /// If the incoming list is shorter, it pads with false.
  /// If it is longer, it truncates to 7.
  List<bool> _normalizeActiveDays(List<bool> source) {
    if (source.length >= 7) {
      return source.sublist(0, 7);
    }

    final result = List<bool>.from(source);
    while (result.length < 7) {
      result.add(false);
    }
    return result;
  }

  Widget _buildDayCircle(String day, bool isActive) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00E676) : const Color(0xFF141414),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF00E676) : const Color(0xFF1F1F1F),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isActive
            ? const Icon(
          Icons.check_rounded,
          color: Color(0xFF000000),
          size: 20,
        )
            : Text(
          day,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF404040),
          ),
        ),
      ),
    );
  }
}
