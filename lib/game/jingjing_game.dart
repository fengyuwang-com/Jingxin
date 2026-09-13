import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;

import '../core/theme.dart';

/// 静境（Jingjing）游戏循环骨架。
///
/// 第 1 轮：星空背景 + 一个可呼吸脉动的"光灵"原型。
/// 呼吸节奏由正弦手动驱动；下一轮接入呼吸输入层（按住=吸气、松开=呼气）。
class JingjingGame extends FlameGame {
  JingjingGame({this.seedColor = ZenTheme.nebulaCyan});

  final Color seedColor;

  final math.Random _random = math.Random(42);
  late final LightSpirit _spirit;
  double _time = 0;

  /// 呼吸阶段周期（秒），呼应 breathing_orb 的舒缓节奏。
  static const double breathPeriod = 8.0;

  @override
  Future<void> onLoad() async {
    // 星空背景：散布静态星辰 + 少量缓慢闪烁的星。
    final stars = <_Star>[];
    for (int i = 0; i < 90; i++) {
      stars.add(
        _Star(
          position: Vector2(
            _random.nextDouble(),
            _random.nextDouble(),
          ),
          radius: 0.4 + _random.nextDouble() * 1.2,
          twinklePhase: _random.nextDouble() * math.pi * 2,
          twinkleSpeed: 0.5 + _random.nextDouble() * 1.5,
        ),
      );
    }
    add(_Starfield(stars));

    _spirit = LightSpirit(tint: seedColor);
    add(_spirit);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    // 正弦驱动呼吸：0..1，吸气时上升、呼气时回落。
    final phase =
        (math.sin(math.pi * 2 * _time / breathPeriod - math.pi / 2) + 1) / 2;
    _spirit.breatheProgress = phase;
  }
}

/// 星空背景层，把归一化坐标铺满视口。
class _Starfield extends Component
    with HasGameReference<JingjingGame> {
  _Starfield(this.stars);

  final List<_Star> stars;
  double _elapsed = 0;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    // 深空底色。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = ZenTheme.voidBlack,
    );

    // 中央星云微光。
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          ZenTheme.deepSpace.withValues(alpha: 0.9),
          ZenTheme.voidBlack,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.x / 2, size.y / 2),
          radius: size.length / 1.5,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      nebulaPaint,
    );

    for (final star in stars) {
      final twinkle =
          0.55 + 0.45 * math.sin(_elapsed * star.twinkleSpeed * 2 + star.twinklePhase);
      final paint = Paint()
        ..color = ZenTheme.starWhite.withValues(alpha: 0.25 + 0.6 * twinkle);
      canvas.drawCircle(
        Offset(star.position.x * size.x, star.position.y * size.y),
        star.radius,
        paint,
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
  }
}

class _Star {
  _Star({
    required this.position,
    required this.radius,
    required this.twinklePhase,
    required this.twinkleSpeed,
  });

  final Vector2 position;
  final double radius;
  final double twinklePhase;
  final double twinkleSpeed;
}

/// "光灵"原型：呼吸脉动的光球。
/// 吸气（progress 上升）时扩张上升并更亮，呼气时凝聚下沉。
class LightSpirit extends Component with HasGameReference<JingjingGame> {
  LightSpirit({required this.tint});

  final Color tint;

  /// 0..1，由游戏循环以正弦驱动（下一轮改为呼吸输入驱动）。
  double breatheProgress = 0;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final center = Offset(size.x / 2, size.y / 2 - size.y * 0.04);

    // 呼吸派生量。
    final expansion = 0.55 + 0.45 * breatheProgress;
    final rise = -size.y * 0.05 * breatheProgress;
    final orbCenter = Offset(center.dx, center.dy + rise);
    final maxRadius = math.min(size.x, size.y) * 0.18;
    final radius = maxRadius * expansion;
    final glow = 0.35 + 0.65 * breatheProgress;

    // 多层呼吸光晕。
    for (int i = 5; i >= 0; i--) {
      final layerRadius = radius * 1.2 + i * radius * 0.28 * (0.5 + glow);
      final opacity = (0.12 - i * 0.018) * glow;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: opacity * 2),
            ZenTheme.nebulaPurple.withValues(alpha: opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: layerRadius));
      canvas.drawCircle(orbCenter, layerRadius, paint);
    }

    // 光球本体。
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          ZenTheme.starWhite.withValues(alpha: 0.92),
          tint.withValues(alpha: 0.75),
          ZenTheme.nebulaPurple.withValues(alpha: 0.4),
          ZenTheme.voidBlack.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: radius));
    canvas.drawCircle(orbCenter, radius, bodyPaint);

    // 环绕微粒：吸气时外扩、呼气时收拢。
    final rng = math.Random(42);
    const particleCount = 18;
    for (int i = 0; i < particleCount; i++) {
      final angle =
          (i / particleCount) * math.pi * 2 + rng.nextDouble() * 0.5;
      final distance =
          radius * 1.25 + breatheProgress * radius * 0.9 * (0.5 + rng.nextDouble() * 0.5);
      final p = Offset(
        orbCenter.dx + math.cos(angle) * distance,
        orbCenter.dy + math.sin(angle) * distance,
      );
      final opacity = (0.75 - breatheProgress * 0.45) * (0.4 + glow * 0.6);
      canvas.drawCircle(
        p,
        1.5 + rng.nextDouble() * 2.5,
        Paint()..color = ZenTheme.starWhite.withValues(alpha: opacity),
      );
    }

    // 底部提示文字随呼吸微弱明灭。
    final textPainter = TextPainter(
      text: TextSpan(
        text: '光灵 · 随呼吸起伏',
        style: TextStyle(
          color: ZenTheme.textMuted.withValues(alpha: 0.55 + 0.3 * glow),
          fontSize: 13,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        orbCenter.dx - textPainter.width / 2,
        orbCenter.dy + radius + 42,
      ),
    );
  }
}
