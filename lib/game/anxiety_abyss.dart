import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';
import 'regions.dart';

/// 「焦虑之渊」——海的更深处（第 7 轮，第二个心境区域）。
///
/// 视觉语言与失眠之海截然不同：
/// - 细密、快速明灭的「乱星」：纷乱念头，闪烁频率高但亮度低、从不刺眼；
///   色调偏冷灰紫，混极少量暗红微光。
/// - 渊底的「心跳微光」：极慢脉动的暗玫瑰色辉光，深处的温柔。
/// - 核心隐喻：玩家持续平稳呼吸时，附近的乱星被逐渐"同化"——
///   闪烁频率慢慢趋同、相位靠拢，最终同步成一次温柔的呼吸脉动；
///   离开后以极缓速度恢复杂乱。
/// - 渊底散布几朵「星花」（闭合花苞状星点簇），在乱星被同化程度高
///   的区域缓缓张开（呼吸辉光）。只做当次反馈，不做永久解锁。
///
/// 区域过渡：深度带 [GameRegion.anxietyAbyss]（归一化 y 0.80→0.93），
/// 全屏色调按光灵所在深度淡入淡出，无加载无传送门，漫游即到达。
/// 性能：乱星 36 颗（≤40），屏外整体跳过绘制。
class AnxietyAbyss extends Component with HasGameReference<JingjingGame> {
  AnxietyAbyss() {
    final rng = math.Random(23);
    final band = GameRegion.anxietyAbyss;
    final period = JingjingGame.worldPeriod;

    // 乱星：分布在渊的深度带内，各有个的纷乱频率。
    for (int i = 0; i < 36; i++) {
      final ny = band.depthStart + rng.nextDouble() * (1.0 - band.depthStart);
      _stars.add(
        _ChaosStar(
          position: Vector2(rng.nextDouble() * period.x, ny * period.y),
          radius: 0.6 + rng.nextDouble() * 1.3,
          baseFreq: 1.2 + rng.nextDouble() * 2.0, // 细密快速明灭（Hz）
          phase: rng.nextDouble() * math.pi * 2,
          redHint: rng.nextDouble() < 0.22, // 少量暗红微光
        ),
      );
    }

    // 星花：渊底的闭合花苞，等呼吸来唤醒。
    for (int i = 0; i < 5; i++) {
      final ny = band.depthStart + 0.03 + rng.nextDouble() * 0.15;
      _flowers.add(
        _StarFlower(
          position: Vector2(
            (0.1 + 0.8 * rng.nextDouble()) * period.x,
            ny * period.y,
          ),
          seed: 300 + i * 31,
        ),
      );
    }

    // 心跳微光：渊底两盏极慢脉动的暗玫瑰辉光。
    _heartLights.add(
      _HeartLight(
        position: Vector2(period.x * 0.30, period.y * 0.955),
        phase: 0,
      ),
    );
    _heartLights.add(
      _HeartLight(
        position: Vector2(period.x * 0.72, period.y * 0.965),
        phase: math.pi * 0.7,
      ),
    );
  }

  final List<_ChaosStar> _stars = [];
  final List<_StarFlower> _flowers = [];
  final List<_HeartLight> _heartLights = [];

  /// 渊的整体"被同化"程度 0..1：平稳呼吸且在渊中时缓慢上升，
  /// 离开或呼吸乱了则极缓退去。
  double calm = 0;

  double _elapsed = 0;

  // ---- 第 16 轮性能审计：画笔预建 + 全屏渐变着色器按量化深度缓存
  //（渊的 bottomGlow 原每帧重建 LinearGradient 着色器——全屏绘制
  // 每帧新建着色器是最贵的一类分配）。depth 变化平缓，缓存命中率高。
  final Paint _veilPaint = Paint();
  final Paint _bottomGlowPaint = Paint();
  final Paint _starPaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _corePaint = Paint();
  Shader? _bottomGlowShader;
  int _bottomGlowKey = -1;
  Shader? _heartShader;
  int _heartKey = -1;

  /// 呼吸目标频率（与自动呼吸引导同周期：8 秒一次温柔脉动）。
  static const double breathFreq = 1 / 8.0;

  @override
  void update(double dt) {
    _elapsed += dt;
    final depth = game.abyssDepth;
    final steady = game.breathSteady;

    // 整体同化程度：平稳呼吸 + 身处渊中 → 缓慢同化；否则极缓恢复杂乱。
    if (steady && depth > 0.25) {
      calm = (calm + dt * 0.045).clamp(0.0, 1.0);
    } else {
      calm = (calm - dt * 0.008).clamp(0.0, 1.0);
    }

    // 共享的"温柔一致相位"（呼吸节律）。
    final sharedPhase = _elapsed * breathFreq * math.pi * 2;

    for (final star in _stars) {
      // 光灵与乱星的环绕最短距离（乱星视差 1，跟随世界）。
      final d = regionWrapDelta(star.position, game.spiritPos);
      final dist = d.length;
      final influence =
          (1.0 - dist / 560.0).clamp(0.0, 1.0) * (steady ? 1.0 : 0.0) * depth;

      // 同化：靠近 + 平稳呼吸 → sync 上升；离开 → 极缓恢复杂乱。
      if (influence > 0) {
        star.sync = (star.sync + influence * dt * 0.09).clamp(0.0, 1.0);
      } else {
        star.sync = (star.sync - dt * 0.012).clamp(0.0, 1.0);
      }

      // 闪烁频率：从各自纷乱的快频，慢慢趋同到呼吸频率。
      final freq = star.baseFreq + (breathFreq - star.baseFreq) * star.sync;
      star.phase += freq * math.pi * 2 * dt;
      // 相位靠拢：sync 越高，越向共享相位收拢（最短角差）。
      final shared = sharedPhase % (math.pi * 2);
      double phaseDiff = (star.phase % (math.pi * 2)) - shared;
      while (phaseDiff > math.pi) {
        phaseDiff -= math.pi * 2;
      }
      while (phaseDiff < -math.pi) {
        phaseDiff += math.pi * 2;
      }
      star.phase -= phaseDiff * star.sync * dt * 0.35;
    }

    // 星花绽放程度：取附近乱星的平均同化度（念头归于一致，花才肯开）。
    for (final flower in _flowers) {
      var sum = 0.0;
      var count = 0;
      for (final star in _stars) {
        final d = regionWrapDelta(flower.position, star.position);
        if (d.length < 420) {
          sum += star.sync;
          count++;
        }
      }
      final local = count > 0 ? sum / count : 0.0;
      final target = (local * 1.5).clamp(0.0, 1.0) * depth;
      // 开得慢、合得也慢（呼吸辉光的节奏）。
      final rate = target > flower.bloom ? 0.25 : 0.10;
      flower.bloom += (target - flower.bloom) * math.min(1.0, dt * rate * 3);
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
    final depth = game.abyssDepth;
    if (depth <= 0.001) return;

    // ---- 渊的色调：全屏冷灰紫沉入 + 底部暗红微光 ----
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      _veilPaint
        ..color = const Color(0xFF0b0a14).withValues(alpha: 0.52 * depth),
    );
    // 底部暗红渐变：着色器按量化深度缓存（0.01 步进）。
    final depthQ = (depth * 100).round();
    if (depthQ != _bottomGlowKey) {
      _bottomGlowKey = depthQ;
      _bottomGlowShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF1c0f1c).withValues(alpha: 0.34 * depth),
        ],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    }
    _bottomGlowPaint.shader = _bottomGlowShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _bottomGlowPaint);

    // ---- 心跳微光：极慢脉动（约 9 秒一次），从不刺眼 ----
    for (final heart in _heartLights) {
      final p = _toScreen(heart.position);
      if (p.dx < -120 ||
          p.dx > size.x + 120 ||
          p.dy < -120 ||
          p.dy > size.y + 120) {
        continue;
      }
      final pulse =
          0.5 + 0.5 * math.sin(_elapsed * math.pi * 2 / 9.0 + heart.phase);
      final alpha = (0.08 + 0.13 * pulse) * depth;
      // 心跳辉光着色器按量化 alpha 缓存（脉动极慢，命中率高）。
      final alphaQ = (alpha * 100).round();
      if (alphaQ != _heartKey) {
        _heartKey = alphaQ;
        _heartShader = RadialGradient(
          colors: [
            const Color(0xFFa4526b).withValues(alpha: alpha),
            const Color(0xFF4a2438).withValues(alpha: alpha * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 64));
      }
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.drawCircle(Offset.zero, 64, _glowPaint..shader = _heartShader);
      canvas.drawCircle(
        Offset.zero,
        1.6,
        _corePaint
          ..color = const Color(0xFFd8a0b0).withValues(alpha: alpha * 1.6),
      );
      canvas.restore();
    }

    // ---- 乱星：细密快速明灭，同化后归于温柔的呼吸脉动 ----
    for (final star in _stars) {
      final p = _toScreen(star.position);
      if (p.dx < -12 ||
          p.dx > size.x + 12 ||
          p.dy < -12 ||
          p.dy > size.y + 12) {
        continue;
      }
      final flick = 0.5 + 0.5 * math.sin(star.phase);
      // 同化后亮度更柔更稳（一致脉动），杂乱时低亮快闪。
      final bright =
          0.10 + 0.16 * flick + star.sync * 0.10 * (0.6 + 0.4 * flick);
      // 色调：冷灰紫为主，少量暗红微光；同化越高越偏温柔的紫白。
      var base = star.redHint ? const Color(0xFFa06a78) : const Color(0xFF8f86ad);
      base = Color.lerp(base, const Color(0xFFc9c2e0), star.sync * 0.5)!;
      canvas.drawCircle(
        p,
        star.radius,
        _starPaint..color = base.withValues(alpha: bright.clamp(0.0, 0.34)),
      );
      // 同化高时的极柔小晕（呼吸辉光感）。
      if (star.sync > 0.35) {
        final glowA = (star.sync - 0.35) * 0.22 * flick;
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withValues(alpha: glowA.clamp(0.0, 0.2)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: star.radius * 6));
        canvas.drawCircle(p, star.radius * 6, glow);
      }
    }

    // ---- 星花：闭合花苞 -> 乱星同化处缓缓张开 ----
    for (final flower in _flowers) {
      final p = _toScreen(flower.position);
      if (p.dx < -60 ||
          p.dx > size.x + 60 ||
          p.dy < -60 ||
          p.dy > size.y + 60) {
        continue;
      }
      flower.render(canvas, p, _elapsed, depth);
    }
  }
}

class _ChaosStar {
  _ChaosStar({
    required this.position,
    required this.radius,
    required this.baseFreq,
    required this.phase,
    required this.redHint,
  });

  final Vector2 position;
  final double radius;
  final double baseFreq;
  final bool redHint;

  double phase;

  /// 0..1 被呼吸同化程度（频率趋同 + 相位靠拢 + 亮度变柔）。
  double sync = 0;
}

class _HeartLight {
  _HeartLight({required this.position, required this.phase});

  final Vector2 position;
  final double phase;
}

/// 渊底的「星花」：闭合花苞状星点簇。
/// 绽放程度只随当次乱星同化度起伏，不做永久解锁。
class _StarFlower {
  _StarFlower({required this.position, required this.seed});

  final Vector2 position;
  final int seed;

  /// 0..1 绽放程度。
  double bloom = 0;

  // 花苞画笔复用（第 16 轮）。
  final Paint _budPaint = Paint();

  late final List<_FlowerPetal> _petals = _buildPetals();

  List<_FlowerPetal> _buildPetals() {
    final rng = math.Random(seed);
    return List.generate(7, (i) {
      final angle = (i / 7) * math.pi * 2 + rng.nextDouble() * 0.5;
      return _FlowerPetal(
        angle: angle,
        openDist: 13 + rng.nextDouble() * 9,
        radius: 1.0 + rng.nextDouble() * 1.1,
        sway: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  void render(Canvas canvas, Offset center, double time, double depth) {
      if (bloom <= 0.004) {
        // 未醒的花苞：极暗的一小簇，几乎只是渊底的一粒尘。
        canvas.drawCircle(
          center,
          1.4,
          _budPaint..color = const Color(0xFF6a6280).withValues(alpha: 0.14 * depth),
        );
        return;
      }
    final ease = bloom * bloom * (3 - 2 * bloom);
    final breathe = 0.75 + 0.25 * math.sin(time * 1.1);

    // 花心微光：呼吸辉光。
    final heartA = (0.10 + 0.26 * ease) * breathe * depth;
    final heart = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFe8c4d0).withValues(alpha: heartA),
          const Color(0xFF9b8fb8).withValues(alpha: heartA * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 26 + 10 * ease));
    canvas.drawCircle(center, 26 + 10 * ease, heart);

    // 花瓣星点：闭合时聚在花心，绽放时缓缓张开、微微摇曳。
    for (final petal in _petals) {
      final sway = 0.06 * math.sin(time * 0.7 + petal.sway);
      final angle = petal.angle + sway;
      final dist = 3.0 + petal.openDist * ease;
      final p = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.9,
      );
      final a = (0.18 + 0.55 * ease) * breathe * depth;
      canvas.drawCircle(
        p,
        petal.radius,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF9b8fb8),
            const Color(0xFFf0d8e2),
            ease,
          )!.withValues(alpha: a.clamp(0.0, 0.8)),
      );
    }
  }
}

class _FlowerPetal {
  _FlowerPetal({
    required this.angle,
    required this.openDist,
    required this.radius,
    required this.sway,
  });

  final double angle;
  final double openDist;
  final double radius;
  final double sway;
}
