import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';
import 'regions.dart';

/// 「疲惫荒原」——世界上部的旷野高空带（第 9 轮，第三个心境区域）。
///
/// 它的地形隐喻是「地平线/旷野」而非深度：光灵上浮即抵达，
/// 与焦虑之渊的下行接入方式镜像对称。视觉语言：
/// - 灰蓝/暖沙的低饱和旷野感，安静、留白多、节奏最慢；
/// - 稀疏的「余烬星尘」：漂浮极慢、几乎静止的暗金微尘，
///   像疲惫到发不出光的星；
/// - 远处一条极简的「地平线微光」：黎明前的第一线光，克制的一条线。
///
/// 核心机制「重燃」：荒原里散落几座熄灭的灯台/星火堆剪影。
/// 光灵靠近并保持平稳呼吸时，灯台会缓缓重燃——一点暖光从暗烬中
/// 苏醒（累积约 2~3 个平稳循环，过程平滑可倒退但不归零）；
/// 重燃后散发微弱暖光并缓缓脉动，当次会话保留（有扎根感）。
/// 纯视觉呼应篝火声景，不强制切声景。
///
/// 性能：余烬微尘 26 颗（≤30），灯台/微尘全部屏外跳过绘制。
class WearyHeath extends Component with HasGameReference<JingjingGame> {
  WearyHeath() {
    final rng = math.Random(59);
    final period = JingjingGame.worldPeriod;

    // 余烬星尘：分布在旷野带内，几乎静止的暗金微尘。
    for (int i = 0; i < 26; i++) {
      final ny = 0.03 + rng.nextDouble() * 0.17;
      _embers.add(
        _Ember(
          position: Vector2(rng.nextDouble() * period.x, ny * period.y),
          radius: 0.5 + rng.nextDouble() * 1.0,
          phase: rng.nextDouble() * math.pi * 2,
          drift: 1.0 + rng.nextDouble() * 1.6, // 极慢漂移 px/s
          upward: rng.nextBool(),
        ),
      );
    }

    // 熄灭的灯台/星火堆：3~4 座散落在旷野带上。
    final count = 3 + rng.nextInt(2);
    for (int i = 0; i < count; i++) {
      final ny = 0.06 + rng.nextDouble() * 0.11;
      _beacons.add(
        _Beacon(
          position: Vector2(
            (0.12 + 0.76 * rng.nextDouble()) * period.x,
            ny * period.y,
          ),
          seed: 700 + i * 37,
        ),
      );
    }
  }

  final List<_Ember> _embers = [];
  final List<_Beacon> _beacons = [];

  /// 地平线所在的世界归一化 y（旷野带的"地平线"）。
  static const double horizonNy = 0.115;

  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    final depth = game.heathDepth;
    final steady = game.breathSteady;

    // 余烬星尘：极慢漂移（几乎静止）。
    for (final e in _embers) {
      final s = e.drift * dt;
      e.position.x = (e.position.x + s * 0.6) % JingjingGame.worldPeriod.x;
      e.position.y += (e.upward ? -s : s) * 0.35;
      final py = JingjingGame.worldPeriod.y;
      if (e.position.y < 0) e.position.y += py;
      if (e.position.y > py) e.position.y -= py;
    }

    // 重燃：靠近 + 平稳呼吸 → 暖光从暗烬中缓缓苏醒；
    // 离开或呼吸乱了 → 平滑倒退，但不归零（留一点余温）。
    for (final b in _beacons) {
      if (b.lit) continue; // 重燃后当次会话保留。
      final d = regionWrapDelta(b.position, game.spiritPos);
      final dist = d.length;
      final near = dist < 260.0 && depth > 0.25;
      if (near && steady) {
        b.fuel = (b.fuel + dt / 22.0).clamp(0.0, 1.0); // 约 2~3 个平稳循环
        if (b.fuel >= 1.0) b.lit = true;
      } else {
        b.fuel = (b.fuel - dt * 0.01).clamp(b.fuel > 0 ? 0.08 : 0.0, 1.0);
      }
    }
  }

  /// 归一化世界坐标 -> 屏幕坐标（视差 1，含环绕镜像最近一次）。
  Offset _toScreen(Vector2 world) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final cam = game.camPos;
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
    final depth = game.heathDepth;
    if (depth <= 0.001) return;

    // ---- 旷野色调：灰蓝低饱和沉入，留白多、从不浓重 ----
    final veil = Paint()
      ..color = const Color(0xFF0c1016).withValues(alpha: 0.42 * depth);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), veil);

    // ---- 地平线微光：黎明前的第一线光，极简的一条线 ----
    final horizonY = _toScreen(
      Vector2(0, horizonNy * JingjingGame.worldPeriod.y),
    ).dy;
    if (horizonY > -80 && horizonY < size.y + 80) {
      final glow = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFd8b98a).withValues(alpha: 0.16 * depth),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, horizonY - 22, size.x, 44));
      canvas.drawRect(Rect.fromLTWH(0, horizonY - 22, size.x, 44), glow);
      // 线本体：一条极细的暖沙色线，随呼吸般的节律极缓明灭。
      final breathe = 0.7 + 0.3 * math.sin(_elapsed * math.pi * 2 / 16.0);
      canvas.drawLine(
        Offset(0, horizonY),
        Offset(size.x, horizonY),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(
            0xFFe8d0a8,
          ).withValues(alpha: (0.10 + 0.10 * breathe) * depth),
      );
    }

    // ---- 余烬星尘：几乎静止的暗金微尘 ----
    for (final e in _embers) {
      final p = _toScreen(e.position);
      if (p.dx < -8 || p.dx > size.x + 8 || p.dy < -8 || p.dy > size.y + 8) {
        continue;
      }
      final flicker =
          0.6 + 0.4 * math.sin(_elapsed * 0.35 + e.phase); // 极缓明灭
      canvas.drawCircle(
        p,
        e.radius,
        Paint()..color = const Color(0xFFb8965c).withValues(
          alpha: (0.05 + 0.09 * flicker) * depth,
        ),
      );
    }

    // ---- 灯台：剪影 -> 重燃的暖光 ----
    for (final b in _beacons) {
      final p = _toScreen(b.position);
      if (p.dx < -70 ||
          p.dx > size.x + 70 ||
          p.dy < -70 ||
          p.dy > size.y + 70) {
        continue;
      }
      b.render(canvas, p, _elapsed, depth);
    }
  }
}

/// 熄灭的灯台/星火堆：几根暗色枝柴的剪影。
/// 重燃后：一点暖光缓缓脉动，呼应篝火声景（纯视觉）。
class _Beacon {
  _Beacon({required this.position, required this.seed});

  final Vector2 position;
  final int seed;

  /// 0..1 重燃累积（靠近+平稳呼吸缓慢上升，可倒退但不归零）。
  double fuel = 0;

  /// 是否已重燃（当次会话保留）。
  bool lit = false;

  late final List<({double angle, double len, double width})> _sticks =
      _buildSticks();

  List<({double angle, double len, double width})> _buildSticks() {
    final rng = math.Random(seed);
    return List.generate(5, (i) {
      final angle = -math.pi / 2 + (i - 2) * 0.42 + (rng.nextDouble() - 0.5) * 0.3;
      return (
        angle: angle,
        len: 9 + rng.nextDouble() * 7,
        width: 1.1 + rng.nextDouble() * 0.7,
      );
    });
  }

  void render(Canvas canvas, Offset center, double time, double depth) {
    final ease = fuel * fuel * (3 - 2 * fuel);

    // 枝柴剪影：暗灰蓝，比夜色略浅的轮廓。
    final stickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF39424f).withValues(alpha: 0.55 * depth);
    for (final s in _sticks) {
      final tip = Offset(
        center.dx + math.cos(s.angle) * s.len,
        center.dy + math.sin(s.angle) * s.len,
      );
      canvas.drawLine(center, tip, stickPaint..strokeWidth = s.width);
    }

    if (ease <= 0.004) {
      // 未燃的暗烬：一粒几乎看不见的余温。
      canvas.drawCircle(
        center,
        1.2,
        Paint()..color = const Color(0xFF8a7248).withValues(alpha: 0.18 * depth),
      );
      return;
    }

    // 暖光：从暗烬中缓缓苏醒的火色，重燃后缓缓脉动（约 5.5 秒一次）。
    final pulse = lit
        ? 0.75 + 0.25 * math.sin(time * math.pi * 2 / 5.5)
        : 0.55 + 0.45 * math.sin(time * 1.2);
    final warmA = (0.08 + 0.30 * ease) * pulse * depth;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFe8a25c).withValues(alpha: warmA),
          const Color(0xFF6a4a30).withValues(alpha: warmA * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 30 + 14 * ease));
    canvas.drawCircle(center, 30 + 14 * ease, glow);

    // 火心：重燃程度越高越亮的一小点暖光。
    canvas.drawCircle(
      center,
      1.4 + 1.2 * ease,
      Paint()..color = Color.lerp(
        const Color(0xFF8a7248),
        const Color(0xFFf4c88a),
        ease,
      )!.withValues(alpha: (0.3 + 0.55 * ease) * pulse * depth),
    );
  }
}

class _Ember {
  _Ember({
    required this.position,
    required this.radius,
    required this.phase,
    required this.drift,
    required this.upward,
  });

  Vector2 position;
  final double radius;
  final double phase;
  final double drift;
  final bool upward;
}
