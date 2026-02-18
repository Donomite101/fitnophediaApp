import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MemberGuideIntroScreen extends StatefulWidget {
  final VoidCallback onStart;

  const MemberGuideIntroScreen({Key? key, required this.onStart})
      : super(key: key);

  @override
  State<MemberGuideIntroScreen> createState() =>
      _MemberGuideIntroScreenState();
}

class _MemberGuideIntroScreenState extends State<MemberGuideIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  double _buttonScale = 1.0;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat(reverse: true);

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Animated Premium Gradient Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                          const Color(0xFF1A1A1A),
                          AppTheme.primaryGreen,
                          _bgController.value * 0.2)!,
                      const Color(0xFF0F0F0F),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),

          /// Floating Glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  /// Progress Indicator
                  LinearProgressIndicator(
                    value: 0.2,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primaryGreen),
                  ),

                  const Spacer(),

                  /// Animated Icon with Hero
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Hero(
                        tag: "fit_icon",
                        child: Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.4),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            size: 70,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  /// Glassmorphism Card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Welcome to Fitnophedia',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Your journey to greatness begins now.\nLet's explore your elite fitness command center.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.white70,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  /// Premium Button with Scale + Haptic
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _buttonScale = 0.96),
                      onTapUp: (_) {
                        setState(() => _buttonScale = 1.0);
                        HapticFeedback.lightImpact();
                        widget.onStart();
                      },
                      onTapCancel: () =>
                          setState(() => _buttonScale = 1.0),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: _buttonScale,
                        child: Container(
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryGreen,
                                Color(0xFF00A86B)
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen
                                    .withOpacity(0.5),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Text(
                            "Start Tour",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Skip for now",
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          /// Close Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
