import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../core/theme.dart';

class BreathingOrb extends StatefulWidget {
  final double breatheProgress;
  final String phase;
  final bool isPaused;
  final VoidCallback? onTap;

  const BreathingOrb({
    super.key,
    required this.breatheProgress,
    required this.phase,
    this.isPaused = false,
    this.onTap,
  });

  @override
  State<BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<BreathingOrb>
    with TickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _springAnimation;
  late AnimationController _timeController;
  final _spring = SpringDescription(mass: 1, stiffness: 500, damping: 15);
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);
    _springAnimation = _springController;
    _timeController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(() {
            setState(() {
              _time = _timeController.value * 10;
            });
          });
    _timeController.repeat();
  }

  @override
  void dispose() {
    _springController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _springController.animateWith(SpringSimulation(_spring, 0, 1, -5));
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _springController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    final simulation = SpringSimulation(
      _spring,
      1,
      0,
      details.velocity.pixelsPerSecond.distance / 1000,
    );
    _springController.animateWith(simulation);
    _dragOffset = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTap: widget.onTap,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _springAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(300, 300),
            painter: BreathingOrbPainter(
              progress: widget.breatheProgress,
              phase: widget.phase,
              isPaused: widget.isPaused,
              springScale: _springAnimation.value,
              dragOffset: _dragOffset,
              isDragging: _isDragging,
              time: _time,
            ),
          );
        },
      ),
    );
  }
}

class BreathingOrbPainter extends CustomPainter {
  final double progress;
  final String phase;
  final bool isPaused;
  final double springScale;
  final Offset dragOffset;
  final bool isDragging;
  final double time;

  BreathingOrbPainter({
    required this.progress,
    required this.phase,
    required this.isPaused,
    required this.springScale,
    required this.dragOffset,
    required this.isDragging,
    required this.time,
  });

  @override
  bool shouldRepaint(covariant BreathingOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.springScale != springScale ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.time != time;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + dragOffset;
    final maxRadius = size.width / 2 * 0.85;
    final minRadius = maxRadius * 0.4;

    final radius = isPaused
        ? maxRadius * 0.7
        : minRadius + (maxRadius - minRadius) * progress;

    final glowIntensity = isPaused ? 0.3 : progress;
    final bloomRadius = radius * (1 + glowIntensity * 0.5);

    for (int i = 5; i >= 0; i--) {
      final layerRadius = bloomRadius + i * 15 * (1 + glowIntensity);
      final opacity = (0.15 - i * 0.02) * glowIntensity;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            ZenTheme.nebulaCyan.withValues(alpha: opacity),
            ZenTheme.nebulaPurple.withValues(alpha: opacity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: layerRadius));
      canvas.drawCircle(center, layerRadius, paint);
    }

    final orbPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              ZenTheme.starWhite.withValues(alpha: 0.9),
              ZenTheme.nebulaCyan.withValues(alpha: 0.7),
              ZenTheme.nebulaPurple.withValues(alpha: 0.4),
              ZenTheme.voidBlack.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius * springScale),
          );

    final shadowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20)
      ..color = ZenTheme.nebulaCyan.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius * 0.8 * springScale, shadowPaint);

    canvas.drawCircle(center, radius * springScale, orbPaint);

    _drawParticles(canvas, center, radius, progress, time);
  }

  void _drawParticles(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    double time,
  ) {
    final random = math.Random(42);
    final particleCount = phase == '吸气' ? 20 : (phase == '屏息' ? 16 : 12);
    final expansion = phase == '吸气' ? progress : (1 - progress);

    for (int i = 0; i < particleCount; i++) {
      final angle =
          (i / particleCount) * 2 * math.pi + random.nextDouble() * 0.5;
      final baseDistance = radius * 1.2;
      final distance =
          baseDistance + expansion * 60 * (0.5 + random.nextDouble() * 0.5);
      final particleCenter = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final particleRadius = 2 + random.nextDouble() * 3;

      // Twinkle effect during hold phase
      double twinkle = 1.0;
      if (phase == '屏息') {
        twinkle = 0.5 + 0.5 * math.sin(time * 3.0 + i * 0.8);
      }

      final baseOpacity = (0.8 - expansion * 0.6) * progress;
      final opacity = baseOpacity * twinkle;

      final particlePaint = Paint()
        ..color = ZenTheme.starWhite.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleRadius * 0.5);
      canvas.drawCircle(
        particleCenter,
        particleRadius * (1 - expansion * 0.5),
        particlePaint,
      );
    }
  }
}
