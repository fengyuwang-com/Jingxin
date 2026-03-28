import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class Starfield extends StatefulWidget {
  final double mouseX;
  final double mouseY;
  final Color? primaryColor;
  final bool isDarkMode;

  const Starfield({
    super.key,
    this.mouseX = 0,
    this.mouseY = 0,
    this.primaryColor,
    this.isDarkMode = true,
  });

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> {
  late Timer _timer;
  late List<Star> _stars;
  final _random = math.Random();
  double _time = 0;

  @override
  void initState() {
    super.initState();
    // 10fps - smooth parallax, still low GPU load
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() => _time = (_time + 0.016) % 1.0);
      }
    });

    // 30 stars instead of 80
    _stars = List.generate(
      30,
      (_) => Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 0.5,
        brightness: _random.nextDouble() * 0.5 + 0.3,
        twinkleOffset: _random.nextDouble() * math.pi * 2,
        twinkleSpeed: _random.nextDouble() * 2 + 1,
        hueOffset: _random.nextDouble() * 60 - 30,
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? ZenTheme.nebulaCyan;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: StarfieldPainter(
          stars: _stars,
          time: _time,
          mouseX: widget.mouseX,
          mouseY: widget.mouseY,
          primaryColor: primaryColor,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }
}

class Star {
  double x, y, size, brightness, twinkleOffset, twinkleSpeed, hueOffset;
  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.brightness,
    required this.twinkleOffset,
    required this.twinkleSpeed,
    required this.hueOffset,
  });
}

class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final double time;
  final double mouseX;
  final double mouseY;
  final Color primaryColor;
  final bool isDarkMode;

  StarfieldPainter({
    required this.stars,
    required this.time,
    required this.mouseX,
    required this.mouseY,
    required this.primaryColor,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isDarkMode
        ? ZenTheme.voidBlack
        : HSLColor.fromColor(primaryColor).withLightness(0.95).toColor();
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (!isDarkMode) {
      final dayGradient = RadialGradient(
        center: Alignment((mouseX - 0.5) * 0.2, (mouseY - 0.5) * 0.2),
        radius: 1.5,
        colors: [primaryColor.withValues(alpha: 0.15), bgColor],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = dayGradient.createShader(Offset.zero & size),
      );
    } else {
      final gradient = RadialGradient(
        center: Alignment((mouseX - 0.5) * 0.2, (mouseY - 0.5) * 0.2),
        radius: 1.5,
        colors: [ZenTheme.deepSpace.withValues(alpha: 0.8), ZenTheme.voidBlack],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    }

    final baseHue = HSLColor.fromColor(primaryColor).hue;
    final baseSat = isDarkMode ? 0.3 : 0.5;
    final baseLight = isDarkMode ? 0.9 : 0.7;

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

      final starColor = HSLColor.fromAHSL(
        opacity,
        (baseHue + star.hueOffset) % 360,
        baseSat,
        baseLight,
      ).toColor();

      // No blur - just solid circles for performance
      final starPaint = Paint()..color = starColor;

      canvas.drawCircle(
        Offset(parallaxX * size.width, parallaxY * size.height),
        star.size * (0.8 + twinkle * 0.4),
        starPaint,
      );

      // Simple glow for larger stars - no blur filter
      if (star.size > 1.5) {
        final glowColor = primaryColor.withValues(alpha: opacity * 0.2);
        final glowPaint = Paint()..color = glowColor;
        canvas.drawCircle(
          Offset(parallaxX * size.width, parallaxY * size.height),
          star.size * 1.5,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.mouseX != mouseX ||
        oldDelegate.mouseY != mouseY ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
