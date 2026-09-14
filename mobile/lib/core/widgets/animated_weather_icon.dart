import 'package:flutter/material.dart';
import 'dart:math' as math;

enum WeatherCondition { sunny, cloudy, rainy }

class AnimatedWeatherIcon extends StatefulWidget {
  final WeatherCondition condition;
  final double size;

  const AnimatedWeatherIcon({
    super.key,
    required this.condition,
    this.size = 100,
  });

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: WeatherPainter(
              condition: widget.condition,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class WeatherPainter extends CustomPainter {
  final WeatherCondition condition;
  final double progress;

  WeatherPainter({required this.condition, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (condition == WeatherCondition.sunny) {
      _drawSun(canvas, size);
    } else if (condition == WeatherCondition.cloudy) {
      _drawCloud(canvas, size, Colors.white);
    } else if (condition == WeatherCondition.rainy) {
      _drawRainy(canvas, size);
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.25;

    // Glowing effect (pulse)
    final pulse = math.sin(progress * math.pi * 2) * 0.1 + 0.9;
    
    final glowPaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.4 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    
    canvas.drawCircle(center, radius * 1.5 * pulse, glowPaint);

    // Main sun
    final sunPaint = Paint()..color = Colors.yellowAccent.shade400;
    canvas.drawCircle(center, radius, sunPaint);

    // Rays (rotating)
    final raysPaint = Paint()
      ..color = Colors.yellowAccent.shade400
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final rayCount = 8;
    final angleStep = (math.pi * 2) / rayCount;
    // Rotate the entire canvas
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * 2);

    for (int i = 0; i < rayCount; i++) {
      canvas.drawLine(
        Offset(0, -radius * 1.3),
        Offset(0, -radius * 1.8),
        raysPaint,
      );
      canvas.rotate(angleStep);
    }
    canvas.restore();
  }

  void _drawCloud(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Slight floating effect (up and down)
    final floatOffset = math.sin(progress * math.pi * 2) * 4;

    canvas.save();
    canvas.translate(0, floatOffset);

    final basePath = Path();
    // Start drawing cloud
    final width = size.width * 0.7;
    final height = size.height * 0.35;
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.1; // lower part
    
    // Base pill
    basePath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: height * 0.8),
      Radius.circular(height * 0.4),
    ));

    // Left puff
    basePath.addOval(Rect.fromCircle(center: Offset(cx - width * 0.2, cy - height * 0.3), radius: height * 0.5));
    // Right puff
    basePath.addOval(Rect.fromCircle(center: Offset(cx + width * 0.15, cy - height * 0.4), radius: height * 0.6));

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(basePath.shift(const Offset(0, 5)), shadowPaint);
    
    canvas.drawPath(basePath, paint);

    canvas.restore();
  }

  void _drawRainy(Canvas canvas, Size size) {
    // Darker cloud
    _drawCloud(canvas, size, Colors.blueGrey.shade100);

    // Draw rain drops falling
    final dropPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dropCount = 5;
    final startY = size.height * 0.65;
    final endY = size.height;
    final dropHeight = 12.0;
    
    for (int i = 0; i < dropCount; i++) {
      // Offset progress for each drop to make them fall at different times
      final p = (progress * 2 + (i * 0.4)) % 1.0; 
      
      final x = size.width * 0.25 + (i * (size.width * 0.5 / (dropCount - 1)));
      final y = startY + (endY - startY) * p;
      
      // Fade out at the bottom
      final opacity = 1.0 - math.pow(p, 3);
      dropPaint.color = Colors.lightBlueAccent.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());

      canvas.drawLine(Offset(x, y), Offset(x, y + dropHeight), dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.condition != condition;
  }
}
