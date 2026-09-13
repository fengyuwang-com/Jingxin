import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';
import 'regions.dart';

/// 「纷心雾林」——世界左/右接缝两侧的水平带（第 13 轮，第四心境区域）。
///
/// 环绕世界的 x 接缝两侧本是同一片地方：向左或向右走出中带，
/// 便走进同一座雾林（ny 0.28~0.72 的水平边缘带，[GameRegion.mistWood]）。
///
/// 视觉语言：
/// - 青灰/墨绿的雾林：2~3 层半透明「雾带」——大尺寸低频的软雾团
///   （绝不逐像素噪声），以不同视差缓慢水平漂移；
/// - 林间浮着极稀疏的「心事萤」：无规则、略急促的游移光点，
///   与荒原几乎静止的余烬恰恰相反；
/// - 色调整体偏冷，克制留白。
///
/// 核心机制「雾沉降」：雾的高度与呼吸平稳度挂钩——在雾林中持续
/// 平稳呼吸时，雾带缓缓下沉、变薄（约 45 秒沉到底），化作一层
/// 贴地的萤光薄霭，林间变透亮，心事萤的轨迹也随之变慢变柔
/// （像被安抚）；呼吸乱了雾极缓回升（约 3 分钟回满）。
/// 雾沉到最低时，林深处「墨枝」枝头的节点逐颗点亮成「雾灯笼」。
/// 全部为当次会话反馈，不做持久化。
///
/// 性能：雾团 3 层 x 6 团（大尺寸低频形状）、心事萤 ≤14、
/// 墨枝 1~2 棵，全部屏外跳过绘制。
class MistWood extends Component with HasGameReference<JingjingGame> {
  MistWood() {
    final rng = math.Random(73);
    final period = JingjingGame.worldPeriod;

    // 雾带：3 层视差（远→近），每层 6 团大而软的雾。
    for (int layer = 0; layer < 3; layer++) {
      final parallax = 0.88 + 0.06 * layer;
      for (int i = 0; i < 6; i++) {
        _blobs.add(
          _FogBlob(
            position: Vector2(
              rng.nextDouble() * period.x,
              (0.32 + rng.nextDouble() * 0.30) * period.y,
            ),
            radius: 150 + rng.nextDouble() * 170, // 大尺寸低频
            squash: 0.16 + rng.nextDouble() * 0.10, // 压扁成带状
            parallax: parallax,
            drift: (3.0 + rng.nextDouble() * 5.0) * (rng.nextBool() ? 1 : -1),
            phase: rng.nextDouble() * math.pi * 2,
            baseAlpha: 0.08 + 0.05 * layer * 0.5 + rng.nextDouble() * 0.03,
            sink: 0.55 + rng.nextDouble() * 0.45,
            layer: layer,
          ),
        );
      }
    }

    // 心事萤：14 颗，无规则略急促的游移。
    for (int i = 0; i < 14; i++) {
      _flies.add(
        _WorryFly(
          position: Vector2(
            rng.nextDouble() * period.x,
            (0.31 + rng.nextDouble() * 0.36) * period.y,
          ),
          speed: 11 + rng.nextDouble() * 11,
          f1: 0.5 + rng.nextDouble() * 0.8,
          f2: 0.9 + rng.nextDouble() * 0.9,
          p1: rng.nextDouble() * math.pi * 2,
          p2: rng.nextDouble() * math.pi * 2,
          phase: rng.nextDouble() * math.pi * 2,
          radius: 0.7 + rng.nextDouble() * 1.1,
        ),
      );
    }

    // 墨枝：雾林深处的 2 棵极简枝状星座剪影。
    for (int i = 0; i < 2; i++) {
      _trees.add(
        _InkBranch(
          position: Vector2(
            (i == 0 ? 0.06 : 0.94) * period.x +
                (rng.nextDouble() - 0.5) * 0.10 * period.x,
            (0.665 + rng.nextDouble() * 0.015) * period.y,
          ),
          seed: 900 + i * 53,
        ),
      );
    }
  }

  final List<_FogBlob> _blobs = [];
  final List<_WorryFly> _flies = [];
  final List<_InkBranch> _trees = [];

  /// 雾林地带的"地面"（归一化 y）：雾沉降与薄霭所在。
  static const double groundNy = 0.70;

  /// 雾沉降程度 0..1（0=雾满，1=雾沉到底化作薄霭）。
  /// 平稳呼吸 + 身处雾林 → 缓缓沉降；呼吸乱了 → 极缓回升。当次会话。
  double settle = 0;

  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    final depth = game.mistDepth;
    final steady = game.breathSteady;

    // 雾沉降：沉降约 45 秒、回升约 3 分钟——落下易、漫起慢。
    if (steady && depth > 0.25) {
      settle = (settle + dt / 45.0).clamp(0.0, 1.0);
    } else {
      settle = (settle - dt / 180.0).clamp(0.0, 1.0);
    }

    // 心事萤：无规则略急促的游移；雾沉降后轨迹变慢变柔、向薄霭靠近。
    final period = JingjingGame.worldPeriod;
    final calm = settle * depth;
    for (final fly in _flies) {
      final t = _elapsed;
      final wander =
          math.sin(t * fly.f1 * math.pi * 2 + fly.p1) * 1.1 +
          math.sin(t * fly.f2 * math.pi * 2 + fly.p2) * 0.8;
      final speed = fly.speed * (1.0 - 0.65 * calm);
      fly.position.x =
          (fly.position.x + math.cos(wander) * speed * dt + period.x) % period.x;
      fly.position.y += math.sin(wander * 1.3) * speed * dt;
      // 雾沉降时萤向贴地薄霭轻轻收拢；否则向各自的基准高度回漂。
      final baseY = fly.baseNy * period.y;
      final targetY = baseY + (groundNy * period.y - baseY) * calm * 0.55;
      fly.position.y += (targetY - fly.position.y) * math.min(1.0, dt * 0.4);
      if (fly.position.y < 0) fly.position.y += period.y;
      if (fly.position.y > period.y) fly.position.y -= period.y;
    }
  }

  /// 世界坐标 -> 屏幕坐标（含视差与环绕镜像最近一次）。
  Offset _toScreen(Vector2 world, double parallax) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    double dx = (world.x - game.camPos.x * parallax) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (world.y - game.camPos.y * parallax) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Offset(size.x / 2 + dx, size.y / 2 + dy);
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final depth = game.mistDepth;
    if (depth <= 0.001) return;
    final settleEase = settle * settle * (3 - 2 * settle);

    // ---- 雾林色调：青灰/墨绿沉入，冷而不重 ----
    final veil = Paint()
      ..color = const Color(0xFF0a1210).withValues(alpha: 0.44 * depth);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), veil);

    // ---- 雾带：3 层视差的大而软的雾团，随沉降下沉、变薄 ----
    // 远层先画（被近层轻掩），同层内雾团横漂。
    for (final blob in _blobs) {
      final sinkNy = blob.baseNy +
          (groundNy - blob.baseNy) * settleEase * blob.sink;
      final p = _toScreen(
        Vector2(
          (blob.position.x + _elapsed * blob.drift) %
              JingjingGame.worldPeriod.x,
          sinkNy * JingjingGame.worldPeriod.y,
        ),
        blob.parallax,
      );
      final margin = blob.radius * 1.3;
      if (p.dx < -margin ||
          p.dx > size.x + margin ||
          p.dy < -margin ||
          p.dy > size.y + margin) {
        continue;
      }
      final breathe = 0.85 + 0.15 * math.sin(_elapsed * 0.22 + blob.phase);
      final a = blob.baseAlpha * (1.0 - 0.75 * settleEase) * breathe * depth;
      if (a <= 0.004) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale(1.0, blob.squash);
      final fog = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7ea89a).withValues(alpha: a),
            const Color(0xFF4a6a60).withValues(alpha: a * 0.55),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: blob.radius));
      canvas.drawCircle(Offset.zero, blob.radius, fog);
      canvas.restore();
    }

    // ---- 贴地萤光薄霭：雾沉降后林间透亮、地面泛起一层微光 ----
    if (settleEase > 0.01) {
      final groundY = _toScreen(
        Vector2(0, groundNy * JingjingGame.worldPeriod.y),
        1.0,
      ).dy;
      if (groundY > -60 && groundY < size.y + 60) {
        final shimmer = 0.8 + 0.2 * math.sin(_elapsed * math.pi * 2 / 11.0);
        final haze = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFFbfe8d0).withValues(
                alpha: 0.10 * settleEase * shimmer * depth,
              ),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromLTWH(0, groundY - 30, size.x, 60));
        canvas.drawRect(Rect.fromLTWH(0, groundY - 30, size.x, 60), haze);
      }
    }

    // ---- 心事萤：无规则略急促的光点，沉降后变慢变柔 ----
    final calm = settleEase * depth;
    for (final fly in _flies) {
      final p = _toScreen(fly.position, 1.0);
      if (p.dx < -8 || p.dx > size.x + 8 || p.dy < -8 || p.dy > size.y + 8) {
        continue;
      }
      final flick = 0.5 + 0.5 * math.sin(_elapsed * 2.1 + fly.phase);
      // 被安抚后：更暖、更稳、更亮一点。
      var base = Color.lerp(
        const Color(0xFF9ec8b8),
        const Color(0xFFe0f4c8),
        calm,
      )!;
      final a = (0.08 + 0.16 * flick + 0.10 * calm) * depth;
      canvas.drawCircle(p, fly.radius, Paint()..color = base.withValues(alpha: a));
      if (calm > 0.3) {
        final glowA = 0.10 * calm * flick * depth;
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withValues(alpha: glowA),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: fly.radius * 6));
        canvas.drawCircle(p, fly.radius * 6, glow);
      }
    }

    // ---- 墨枝：雾沉降到最低时枝头节点逐颗点亮成雾灯笼 ----
    for (final tree in _trees) {
      final p = _toScreen(tree.position, 1.0);
      if (p.dx < -180 ||
          p.dx > size.x + 180 ||
          p.dy < -200 ||
          p.dy > size.y + 120) {
        continue;
      }
      tree.render(canvas, p, _elapsed, depth, settleEase);
    }
  }
}

/// 「心事萤」：雾林里游移的光点——轨迹无规则、略急促（与荒原余烬相反）。
class _WorryFly {
  _WorryFly({
    required this.position,
    required this.speed,
    required this.f1,
    required this.f2,
    required this.p1,
    required this.p2,
    required this.phase,
    required this.radius,
  }) : baseNy = position.y / JingjingGame.worldPeriod.y;

  Vector2 position;
  final double speed;
  final double f1;
  final double f2;
  final double p1;
  final double p2;
  final double phase;
  final double radius;
  final double baseNy;
}

/// 一团雾：大而软的低频形状（圆被压扁成带状），以固定速度横漂。
class _FogBlob {
  _FogBlob({
    required this.position,
    required this.radius,
    required this.squash,
    required this.parallax,
    required this.drift,
    required this.phase,
    required this.baseAlpha,
    required this.sink,
    required this.layer,
  }) : baseNy = position.y / JingjingGame.worldPeriod.y;

  final Vector2 position;
  final double radius;
  final double squash;
  final double parallax;
  final double drift;
  final double phase;
  final double baseAlpha;
  final double sink;
  final int layer;
  final double baseNy;
}

/// 「墨枝」：极简的枝状星座剪影——几条弧线 + 节点星。
/// 雾沉降到最低时（settle >= ~0.65 起），枝头节点逐颗点亮成「雾灯笼」；
/// 雾回升则缓缓熄回去。只做当次反馈。
class _InkBranch {
  _InkBranch({required this.position, required this.seed});

  final Vector2 position;
  final int seed;

  late final List<_BranchArc> _arcs = _build();
  late final List<Vector2> _nodes = _buildNodes();

  /// 从根到梢的几条二次贝塞尔弧（世界坐标，相对树根）。
  List<_BranchArc> _build() {
    final rng = math.Random(seed);
    final arcs = <_BranchArc>[];
    final height = 96 + rng.nextDouble() * 46;
    final lean = (rng.nextDouble() - 0.5) * 0.7;
    // 主干：两段微弯的弧。
    var tip = Offset(lean * 10, -height * 0.5);
    arcs.add(
      _BranchArc(
        Offset(0, 0),
        Offset(lean * 4 - 5, -height * 0.28),
        tip,
      ),
    );
    final upperStart = tip;
    tip = Offset(lean * 22 + 6, -height);
    arcs.add(
      _BranchArc(
        upperStart,
        Offset(lean * 16 + 2, -height * 0.78),
        tip,
      ),
    );
    // 侧枝：3 条从主干中上部斜出的短弧。
    for (int i = 0; i < 3; i++) {
      final t0 = 0.42 + i * 0.19 + rng.nextDouble() * 0.06;
      final start = Offset(
        lean * 10 + (lean * 12 + 6) * t0,
        -height * 0.5 - height * 0.5 * t0,
      );
      final side = i.isEven ? -1.0 : 1.0;
      final len = 26 + rng.nextDouble() * 20;
      final end = Offset(
        start.dx + side * (len * (0.7 + rng.nextDouble() * 0.5)),
        start.dy - len * (0.45 + rng.nextDouble() * 0.4),
      );
      arcs.add(
        _BranchArc(
          start,
          Offset(
            (start.dx + end.dx) / 2 + side * len * 0.2,
            (start.dy + end.dy) / 2 - len * 0.1,
          ),
          end,
        ),
      );
    }
    return arcs;
  }

  /// 节点星：主干梢 + 各侧枝梢（5 个），雾灯笼所在。
  List<Vector2> _buildNodes() {
    final nodes = <Vector2>[];
    // 最后一条弧的终点是树梢。
    final top = _arcs[1].b;
    nodes.add(Vector2(top.dx, top.dy));
    for (int i = 2; i < _arcs.length; i++) {
      final e = _arcs[i].b;
      nodes.add(Vector2(e.dx, e.dy));
    }
    return nodes;
  }

  void render(
    Canvas canvas,
    Offset root,
    double time,
    double depth,
    double settleEase,
  ) {
    // 枝的墨色剪影：雾越沉降越可见（雾退枝现）。
    final inkA = (0.24 + 0.34 * settleEase) * depth;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = const Color(0xFF25332c).withValues(alpha: inkA.clamp(0.0, 0.6));
    final path = Path();
    for (final arc in _arcs) {
      path.moveTo(arc.a.dx, arc.a.dy);
      path.quadraticBezierTo(arc.c.dx, arc.c.dy, arc.b.dx, arc.b.dy);
    }
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.drawPath(path, ink);

    // 根部一点极暗的底。
    canvas.drawCircle(
      Offset.zero,
      1.6,
      Paint()..color = const Color(0xFF3a4a42).withValues(alpha: 0.30 * depth),
    );

    // 雾灯笼：settle 越过 0.65 后节点逐颗点亮。
    final litT = ((settleEase - 0.65) / 0.35).clamp(0.0, 1.0);
    if (litT > 0.001) {
      final smooth = litT * litT * (3 - 2 * litT);
      final n = _nodes.length;
      for (int i = 0; i < n; i++) {
        final nodeT = (smooth * n - i).clamp(0.0, 1.0);
        if (nodeT <= 0.001) continue;
        final ease = nodeT * nodeT * (3 - 2 * nodeT);
        final c = Offset(_nodes[i].x, _nodes[i].y);
        final breathe = 0.75 + 0.25 * math.sin(time * 1.1 + i * 1.3);
        final a = ease * breathe * depth;
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFe8f6cc).withValues(alpha: 0.30 * a),
              const Color(0xFFa8c890).withValues(alpha: 0.14 * a),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: 12 + 5 * ease));
        canvas.drawCircle(c, 12 + 5 * ease, glow);
        canvas.drawCircle(
          c,
          1.5 + 0.7 * ease,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF8fb8a0),
              const Color(0xFFf4fadc),
              ease,
            )!.withValues(alpha: (0.25 + 0.6 * ease) * depth),
        );
      }
    }
    canvas.restore();
  }
}

class _BranchArc {
  _BranchArc(this.a, this.c, this.b);

  final Offset a; // 起点
  final Offset c; // 控制点
  final Offset b; // 终点
}
