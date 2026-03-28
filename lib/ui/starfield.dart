import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class Starfield extends StatefulWidget {
  final double mouseX;
  final double mouseY;

  const Starfield({super.key, this.mouseX = 0, this.mouseY = 0});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _stars = List.generate(
      80,
      (_) => Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 0.5,
        brightness: _random.nextDouble() * 0.5 + 0.3,
        twinkleOffset: _random.nextDouble() * math.pi * 2,
        twinkleSpeed: _random.nextDouble() * 2 + 1,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: StarfieldPainter(
            stars: _stars,
            time: _controller.value,
            mouseX: widget.mouseX,
            mouseY: widget.mouseY,
          ),
        );
      },
    );
  }
}

class Star {
  double x, y, size, brightness, twinkleOffset, twinkleSpeed;
  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.brightness,
    required this.twinkleOffset,
    required this.twinkleSpeed,
  });
}

class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final double time;
  final double mouseX;
  final double mouseY;

  StarfieldPainter({
    required this.stars,
    required this.time,
    required this.mouseX,
    required this.mouseY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = ZenTheme.voidBlack;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gradient = RadialGradient(
      center: Alignment((mouseX - 0.5) * 0.2, (mouseY - 0.5) * 0.2),
      radius: 1.5,
      colors: [ZenTheme.deepSpace.withValues(alpha: 0.8), ZenTheme.voidBlack],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );

    for (final star in stars) {
      final parallaxX = (star.x + mouseX * 0.02) % 1.0;
      final parallaxY = (star.y + mouseY * 0.02) % 1.0;

      final twinkle =
          (math.sin(
                time * math.pi * 2 * star.twinkleSpeed + star.twinkleOffset,
              ) +
              1) /
          2;
      final opacity = star.brightness * (0.5 + twinkle * 0.5);

      final starPaint = Paint()
        ..color = ZenTheme.starWhite.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, star.size * 0.5);

      canvas.drawCircle(
        Offset(parallaxX * size.width, parallaxY * size.height),
        star.size * (0.8 + twinkle * 0.4),
        starPaint,
      );

      if (star.size > 1.5) {
        final glowPaint = Paint()
          ..color = ZenTheme.nebulaCyan.withValues(alpha: opacity * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, star.size * 2);
        canvas.drawCircle(
          Offset(parallaxX * size.width, parallaxY * size.height),
          star.size * 2,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.mouseX != mouseX ||
        oldDelegate.mouseY != mouseY;
  }
}
