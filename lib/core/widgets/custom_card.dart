import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hasShadow;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    this.borderRadius = 16,
    this.backgroundColor,
    this.onTap,
    this.hasShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: hasShadow
              ? [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
          border: Border.all(
            color: !isDark
                ? Colors.grey.withOpacity(0.2)
                : Colors.white12,
          ),
        ),
        child: child,
      ),
    );
  }
}
