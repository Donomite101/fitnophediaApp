import 'dart:math';
import 'package:flutter/material.dart';

class WaterGlassWidget extends StatefulWidget {
  final double percentage; // 0.0 to 1.0
  final double height;
  final double width;
  final bool isDark;

  const WaterGlassWidget({
    Key? key,
    required this.percentage,
    this.height = 100,
    this.width = 60,
    required this.isDark,
  }) : super(key: key);

  @override
  State<WaterGlassWidget> createState() => _WaterGlassWidgetState();
}

class _WaterGlassWidgetState extends State<WaterGlassWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: CustomPaint(
        painter: _WaterGlassPainter(
          percentage: widget.percentage,
          animationValue: _controller,
          isDark: widget.isDark,
        ),
      ),
    );
  }
}

class _WaterGlassPainter extends CustomPainter {
  final double percentage;
  final Animation<double> animationValue;
  final bool isDark;

  _WaterGlassPainter({
    required this.percentage,
    required this.animationValue,
    required this.isDark,
  }) : super(repaint: animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    
    // Simple Bottle Dimensions
    final capHeight = h * 0.1;
    final neckHeight = h * 0.08;
    final neckWidth = w * 0.3;
    final bodyHeight = h - capHeight - neckHeight;
    final bodyWidth = w * 0.7;
    final capWidth = w * 0.4;
    
    final bottlePath = Path();
    
    // 1. Cap (Simple Rectangle with rounded top)
    final capRect = Rect.fromCenter(
      center: Offset(centerX, capHeight / 2),
      width: capWidth,
      height: capHeight,
    );
    bottlePath.addRRect(RRect.fromRectAndCorners(
      capRect, 
      topLeft: const Radius.circular(4), 
      topRight: const Radius.circular(4)
    ));

    // 2. Neck (Simple Rectangle)
    final neckRect = Rect.fromCenter(
      center: Offset(centerX, capHeight + neckHeight / 2),
      width: neckWidth,
      height: neckHeight,
    );
    bottlePath.addRect(neckRect);

    // 3. Body (Rounded Rectangle)
    final bodyRect = Rect.fromCenter(
      center: Offset(centerX, capHeight + neckHeight + bodyHeight / 2),
      width: bodyWidth,
      height: bodyHeight,
    );
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(10));
    bottlePath.addRRect(bodyRRect);

    // Clip for water
    canvas.save();
    canvas.clipRRect(bodyRRect);

    // Draw Water
    final waterBodyHeight = bodyHeight * percentage.clamp(0.0, 1.0);
    final waterTopY = (capHeight + neckHeight + bodyHeight) - waterBodyHeight;
    
    if (percentage > 0) {
      final waterPath = Path();
      waterPath.moveTo(centerX - bodyWidth / 2, capHeight + neckHeight + bodyHeight); // Bottom Left
      waterPath.lineTo(centerX - bodyWidth / 2, waterTopY); // Top Left
      
      // Wave effect
      final waveWidth = bodyWidth;
      final waveHeight = 2.0;
      final phase = animationValue.value * 2 * pi;
      final startX = centerX - bodyWidth / 2;
      
      for (double x = 0; x <= bodyWidth; x++) {
        final y = waterTopY + sin((x / waveWidth * 2 * pi) + phase) * waveHeight;
        waterPath.lineTo(startX + x, y);
      }
      
      waterPath.lineTo(centerX + bodyWidth / 2, capHeight + neckHeight + bodyHeight); // Bottom Right
      waterPath.close();

      // Clean Blue Gradient
      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF42A5F5).withOpacity(0.8), // Blue 400
            const Color(0xFF1976D2).withOpacity(0.9), // Blue 700
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      canvas.drawPath(waterPath, waterPaint);
      
      // Bubbles
      final random = Random(42);
      final bubblePaint = Paint()..color = Colors.white.withOpacity(0.3);
      for (int i = 0; i < 5; i++) {
        final bx = (centerX - bodyWidth / 2) + random.nextDouble() * bodyWidth;
        final by = (capHeight + neckHeight + bodyHeight) - (random.nextDouble() * waterBodyHeight);
        final bSize = random.nextDouble() * 2 + 1;
        
        final rise = (animationValue.value * bodyHeight) % bodyHeight;
        var animatedY = by - rise;
        if (animatedY < waterTopY) animatedY += waterBodyHeight;
        
        if (animatedY > waterTopY + 5 && animatedY < (capHeight + neckHeight + bodyHeight) - 5) {
           canvas.drawCircle(Offset(bx, animatedY), bSize, bubblePaint);
        }
      }
    }
    canvas.restore();

    // Draw Outlines
    final outlinePaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.5) : Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    // Cap
    canvas.drawRRect(RRect.fromRectAndCorners(
      capRect, 
      topLeft: const Radius.circular(4), 
      topRight: const Radius.circular(4)
    ), outlinePaint..style = PaintingStyle.fill..color = isDark ? Colors.grey[700]! : Colors.grey[300]!);
    
    canvas.drawRRect(RRect.fromRectAndCorners(
      capRect, 
      topLeft: const Radius.circular(4), 
      topRight: const Radius.circular(4)
    ), outlinePaint..style = PaintingStyle.stroke..color = isDark ? Colors.grey[500]! : Colors.grey[600]!);

    // Neck
    canvas.drawRect(neckRect, outlinePaint..style = PaintingStyle.stroke);
    
    // Body
    canvas.drawRRect(bodyRRect, outlinePaint..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Simple Highlight
    final highlightPath = Path();
    highlightPath.moveTo(centerX - bodyWidth * 0.25, capHeight + neckHeight + 10);
    highlightPath.lineTo(centerX - bodyWidth * 0.25, h - 15);
    
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterGlassPainter oldDelegate) {
    return oldDelegate.percentage != percentage || 
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isDark != isDark;
  }
}
