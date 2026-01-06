import 'package:flutter/material.dart';
import '../models/badge_model.dart';

class BadgeUnlockDialog extends StatefulWidget {
  final BadgeModel badge;
  final bool isDarkMode;

  const BadgeUnlockDialog({
    Key? key,
    required this.badge,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor =>
      widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.badge.unlocked ? '🎉 Achievement Unlocked!' : 'Locked Badge',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                          size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Badge
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: widget.badge.unlocked
                      ? LinearGradient(
                    colors: [widget.badge.color, widget.badge.color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: widget.badge.unlocked ? null : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                  boxShadow: widget.badge.unlocked
                      ? [
                    BoxShadow(
                      color: widget.badge.color.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    widget.badge.icon,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.badge.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.badge.description,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: widget.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 32),

              // Continue button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.badge.unlocked ? const Color(0xFF2196F3) : const Color(0xFF9E9E9E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.badge.unlocked ? Icons.celebration : Icons.lock,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.badge.unlocked ? 'Continue Journey' : 'Keep Going',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}