import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';

/// 「失眠之海」——海平面之下的星海（第 3 轮）。
///
/// 程序生成：正弦叠加的层次星潮（不引入新依赖），远处星层随光灵
/// 漂移做视差缓动；近处漂浮少量"失眠星屑"。色调深夜靛蓝/墨绿，
/// 延续 ZenTheme。无边界：一切坐标按 [JingjingGame.worldPeriod] 环绕。
class InsomniaSea extends Component with HasGameReference<JingjingGame> {
  InsomniaSea() {
    final rng = math.Random(7);
    // 失眠星屑：近景漂浮微粒，数量克制（移动端帧率友好）。
    for (int i = 0; i < 26; i++) {
      motes.add(
        SeaMote(
          position: Vector2(
            rng.nextDouble() * JingjingGame.worldPeriod.x,
            rng.nextDouble() * JingjingGame.worldPeriod.y,
          ),
          radius: 0.8 + rng.nextDouble() * 1.8,
          driftPhase: rng.nextDouble() * math.pi * 2,
          driftSpeed: 0.2 + rng.nextDouble() * 0.5,
          parallax: 0.55 + rng.nextDouble() * 0.3,
        ),
      );
    }
  }

  final List<SeaMote> motes = [];
  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
  }

  /// 把世界坐标按环绕周期折算到相机附近的屏幕坐标。
  Offset _wrapToScreen(Vector2 world, double parallax) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final cam = game.camPos * parallax;
    double dx = (world.x - cam.x) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (world.y - cam.y) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Offset(size.x / 2 + dx, size.y / 2 + dy);
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final aw = game.awakeningValue.value;
    final cam = game.camPos;

    // ---- 层次星潮：3 层正弦叠加的"海底星带" ----
    // 色调：深夜靛蓝 -> 墨绿，苏醒度越高越微亮。
    final bandColors = [
      Color.lerp(const Color(0xFF0d1626), const Color(0xFF12203a), aw)!,
      Color.lerp(const Color(0xFF0c1f22), const Color(0xFF123033), aw)!,
      Color.lerp(const Color(0xFF0a1420), const Color(0xFF10263c), aw)!,
    ];
    const bandParallax = [0.15, 0.3, 0.5];
    const bandBase = [0.42, 0.58, 0.74]; // 各层基准高度（屏幕比例）
    const bandAmp = [26.0, 34.0, 44.0];

    for (int layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.y);
      const steps = 24;
      for (int i = 0; i <= steps; i++) {
        final sx = size.x * i / steps;
        final wx = sx + cam.x * bandParallax[layer];
        final wave = _tideWave(wx * 0.008 + layer * 13.7, _elapsed * (0.12 + 0.05 * layer));
        final sy = size.y * bandBase[layer] + wave * bandAmp[layer];
        path.lineTo(sx, sy);
      }
      path.lineTo(size.x, size.y);
      path.close();
      canvas.drawPath(path, Paint()..color = bandColors[layer].withValues(alpha: 0.5));

      // 星带脊线上的微光点缀：每层少量星点，随波形起伏。
      for (int i = 0; i < 8; i++) {
        final sx = size.x * (i + 0.5) / 8;
        final wx = sx + cam.x * bandParallax[layer];
        final wave = _tideWave(wx * 0.008 + layer * 13.7, _elapsed * (0.12 + 0.05 * layer));
        final sy = size.y * bandBase[layer] + wave * bandAmp[layer];
        final tw = 0.5 + 0.5 * math.sin(_elapsed * 0.8 + i * 2.1 + layer * 3.3);
        canvas.drawCircle(
          Offset(sx, sy - 3 - 6 * tw),
          0.8 + 0.7 * tw,
          Paint()
            ..color = ZenTheme.nebulaCyan.withValues(
              alpha: (0.10 + 0.16 * aw) * (0.4 + 0.6 * tw),
            ),
        );
      }
    }

    // ---- 失眠星屑：近景视差漂浮 ----
    for (final mote in motes) {
      final drift = math.sin(_elapsed * mote.driftSpeed + mote.driftPhase);
      final p = _wrapToScreen(
        Vector2(
          mote.position.x + drift * 18,
          mote.position.y + math.cos(_elapsed * mote.driftSpeed * 0.7 + mote.driftPhase) * 14,
        ),
        mote.parallax,
      );
      if (p.dx < -20 || p.dx > size.x + 20 || p.dy < -20 || p.dy > size.y + 20) {
        continue;
      }
      final tw = 0.5 + 0.5 * math.sin(_elapsed * 1.1 + mote.driftPhase * 3);
      canvas.drawCircle(
        p,
        mote.radius,
        Paint()
          ..color = Color.lerp(
            ZenTheme.nebulaCyan,
            const Color(0xFF34d399),
            mote.parallax - 0.55,
          )!.withValues(alpha: (0.12 + 0.22 * tw * (0.5 + aw * 0.5)).clamp(0.0, 1.0)),
      );
    }
  }

  /// 正弦叠加的潮汐波（-1..1），代替值噪声，无新依赖。
  static double _tideWave(double x, double t) {
    return (math.sin(x * 1.0 + t * 2.0) * 0.5 +
            math.sin(x * 2.3 - t * 1.3 + 1.7) * 0.3 +
            math.sin(x * 4.7 + t * 0.7 + 4.1) * 0.2)
        .clamp(-1.0, 1.0);
  }
}

class SeaMote {
  SeaMote({
    required this.position,
    required this.radius,
    required this.driftPhase,
    required this.driftSpeed,
    required this.parallax,
  });

  final Vector2 position;
  final double radius;
  final double driftPhase;
  final double driftSpeed;
  final double parallax;
}

/// 「沉睡的星岛/星礁」剪影：光灵靠近且呼吸平稳时微微亮起（呼吸辉光）。
/// 本轮只做亮起反馈，不做永久解锁。
class StarIsle extends Component with HasGameReference<JingjingGame> {
  StarIsle({
    required this.position,
    required this.radius,
    required this.shapeSeed,
    required this.tint,
  });

  /// 世界坐标（环绕周期内）。
  final Vector2 position;
  final double radius;
  final int shapeSeed;
  final Color tint;

  /// 0..1 辉光程度：靠近+平稳呼吸时缓慢上升，远离时极缓退去。
  double glow = 0;

  late final List<Offset> _silhouette = _buildSilhouette();
  late final List<_IsleStar> _isleStars = _buildStars();

  List<Offset> _buildSilhouette() {
    final rng = math.Random(shapeSeed);
    final points = <Offset>[];
    const n = 9;
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2;
      final r = radius * (0.65 + rng.nextDouble() * 0.5);
      points.add(Offset(math.cos(angle) * r, math.sin(angle) * r * 0.72));
    }
    return points;
  }

  List<_IsleStar> _buildStars() {
    final rng = math.Random(shapeSeed + 100);
    return List.generate(4, (_) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = rng.nextDouble() * radius * 0.55;
      return _IsleStar(
        offset: Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.72),
        phase: rng.nextDouble() * math.pi * 2,
        radius: 0.9 + rng.nextDouble() * 1.3,
      );
    });
  }

  @override
  void update(double dt) {
    // 距离按环绕周期最短路径计算。
    final period = JingjingGame.worldPeriod;
    final spirit = game.spiritPos;
    double dx = (position.x - spirit.x) % period.x;
    if (dx > period.x / 2) dx -= period.x;
    if (dx < -period.x / 2) dx += period.x;
    double dy = (position.y - spirit.y) % period.y;
    if (dy > period.y / 2) dy -= period.y;
    if (dy < -period.y / 2) dy += period.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    const nearRange = 300.0;
    final near = dist < nearRange;
    if (near && game.breathSteady) {
      glow = (glow + dt * 0.22).clamp(0.0, 1.0);
    } else {
      glow = (glow - dt * 0.10).clamp(0.0, 1.0);
    }
  }

  void _renderAt(Canvas canvas, Offset center, double scale) {
    final aw = game.awakeningValue.value;

    // 苏醒辉光（呼吸辉光）：靠近且平稳呼吸时从内部微微透亮。
    if (glow > 0.01) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.30 * glow),
            const Color(0xFF34d399).withValues(alpha: 0.12 * glow),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius * 1.5 * scale),
        );
      canvas.drawCircle(center, radius * 1.5 * scale, glowPaint);
    }

    // 星岛剪影（深夜靛蓝，比海稍深）。
    final path = Path();
    final last = _silhouette.last;
    path.moveTo(center.dx + last.dx * scale, center.dy + last.dy * scale);
    for (final p in _silhouette) {
      path.lineTo(center.dx + p.dx * scale, center.dy + p.dy * scale);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF0a101c),
          const Color(0xFF13253f),
          0.3 * aw + 0.25 * glow,
        )!,
    );

    // 岛内"沉睡星点"：随辉光逐个亮起。
    for (final star in _isleStars) {
      final lit = (glow * _isleStars.length).clamp(0.0, _isleStars.length.toDouble());
      final index = _isleStars.indexOf(star);
      final a = (lit - index).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final tw = 0.6 + 0.4 * math.sin(game.time * 1.4 + star.phase);
      canvas.drawCircle(
        center + star.offset * scale,
        star.radius * scale,
        Paint()..color = ZenTheme.starWhite.withValues(alpha: 0.75 * a * tw),
      );
    }

    // 剪影边缘微光：辉光高时轮廓泛起青绿。
    if (glow > 0.05) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = tint.withValues(alpha: 0.35 * glow),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final parallax = 0.85;

    // 环绕绘制：本体 + 相邻镜像，保证漫游穿越边界时无缝。
    for (int ox = -1; ox <= 1; ox++) {
      for (int oy = -1; oy <= 1; oy++) {
        final world = position +
            Vector2(ox * period.x, oy * period.y) -
            game.camPos * parallax;
        final center = Offset(size.x / 2 + world.x, size.y / 2 + world.y);
        if (center.dx < -radius * 2 ||
            center.dx > size.x + radius * 2 ||
            center.dy < -radius * 2 ||
            center.dy > size.y + radius * 2) {
          continue;
        }
        _renderAt(canvas, center, 1.0);
      }
    }
  }
}

class _IsleStar {
  _IsleStar({required this.offset, required this.phase, required this.radius});

  final Offset offset;
  final double phase;
  final double radius;
}
