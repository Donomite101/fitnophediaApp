import 'package:flutter/material.dart';
import '../../models/badge_model.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';

class BadgeUnlockOverlay extends StatefulWidget {
  final List<BadgeModel> unlockedBadges;
  final VoidCallback onDismiss;

  const BadgeUnlockOverlay({
    Key? key,
    required this.unlockedBadges,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends State<BadgeUnlockOverlay> {
  late ConfettiController _confettiController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _nextBadge() {
    if (_currentIndex < widget.unlockedBadges.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _confettiController.play(); // Play confetti again for next badge
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unlockedBadges.isEmpty) return const SizedBox.shrink();

    final badge = widget.unlockedBadges[_currentIndex];

    return Stack(
      children: [
        // Blur Background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.black.withOpacity(0.6),
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),

        // Content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: badge.color.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          badge.icon,
                          style: const TextStyle(fontSize: 80),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Badge Unlocked!",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: badge.color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          badge.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextBadge,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: badge.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "AWESOME!",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
