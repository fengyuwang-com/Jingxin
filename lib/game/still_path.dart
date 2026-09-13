import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';

/// 「静之径」——区域间的旅程线（第 14 轮）。
///
/// 一条蜿蜒的淡光路径，像雪地上前人走过的旧迹：从「疲惫荒原」
/// （顶部旷野带）出发，穿过「纷心雾林」的一侧接缝、掠过海的中带
/// （途经星兽上空），最终沉入「焦虑之渊」。它不是导航、不是任务
/// 路线——只是世界本身的一道旧痕，玩家可以顺着走，也可以完全无视。
///
/// 几何：6 个锚点的 Catmull-Rom 平滑曲线，采样为折线后缓存为一条
/// 静态 Path。世界是 2400x1800 环绕环面，路径锚点按连续坐标展开
/// （允许 x 为负——即从接缝 x=0 穿过去），渲染时按最短环绕距离
/// 平移绘制、对另一侧接缝再补画镜像副本（与星岛镜像绘制同思路），
/// 保证穿越接缝时路径在两侧都无缝连续。
///
/// 回应（轻）：光灵在径上（<40px）且平稳呼吸时，走过的那一段会
/// 短暂亮起——余温式微光，约 16 秒缓缓褪去，像有人在雪上又踩了一脚。
/// 无成就、无计数、无提示。
///
/// 长线巧思：路径整体透明度与「世界苏醒度」轻联动（幅度极小）——
/// 世界越醒，旧迹越清晰一点点。
///
/// 性能：基础路径是一条缓存的静态 Path（每帧至多 2 次平移描边），
/// 余温叠加复用同一个可重置 Path；径上尘 10 颗（≤10），全部屏外
/// 跳过；每帧零 List/Random 分配。
class StillPath extends Component with HasGameReference<JingjingGame> {
  StillPath() {
    // 锚点（世界坐标，x 允许为负=从接缝 x=0 穿过）：
    // 荒原顶部 -> 向接缝下行 -> 穿过雾林接缝 -> 回到海的中带
    // -> 掠过星兽上空（锚点 ny 0.78）-> 沉入渊底。
    const anchors = <Offset>[
      Offset(816, 150), // 疲惫荒原（ny≈0.083）
      Offset(384, 452), // 向接缝缓缓下行
      Offset(-120, 762), // 穿过「纷心雾林」接缝（x=0）
      Offset(312, 1098), // 回到海的中带
      Offset(192, 1360), // 掠过星兽上空（ny≈0.756）
      Offset(528, 1626), // 沉入「焦虑之渊」（ny≈0.903）
    ];

    // Catmull-Rom 采样：首尾补控制点，每段 16 个样本。
    final ctrl = <Offset>[anchors.first, ...anchors, anchors.last];
    for (int s = 0; s < anchors.length - 1; s++) {
      final p0 = ctrl[s];
      final p1 = ctrl[s + 1];
      final p2 = ctrl[s + 2];
      final p3 = ctrl[s + 3];
      for (int i = 0; i < samplesPerSegment; i++) {
        final t = i / samplesPerSegment;
        final t2 = t * t;
        final t3 = t2 * t;
        final x =
            0.5 *
            (2 * p1.dx +
                (-p0.dx + p2.dx) * t +
                (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);
        final y =
            0.5 *
            (2 * p1.dy +
                (-p0.dy + p2.dy) * t +
                (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);
        _points.add(Offset(x, y));
        _warmth.add(0);
      }
    }
    _points.add(anchors.last);
    _warmth.add(0);

    // 静态基础路径（缓存，渲染时只平移不重建）。
    _basePath = Path()..moveTo(_points.first.dx, _points.first.dy);
    for (int i = 1; i < _points.length; i++) {
      _basePath.lineTo(_points[i].dx, _points[i].dy);
    }
    _minX = _points.first.dx;
    _maxX = _minX;
    _minY = _points.first.dy;
    _maxY = _minY;
    for (final p in _points) {
      if (p.dx < _minX) _minX = p.dx;
      if (p.dx > _maxX) _maxX = p.dx;
      if (p.dy < _minY) _minY = p.dy;
      if (p.dy > _maxY) _maxY = p.dy;
    }

    // 径上尘：沿途点缀的极稀疏微尘，缓慢明灭、沿径极慢游移。
    final rng = math.Random(14);
    for (int i = 0; i < dustCount; i++) {
      _dust.add(
        _PathDust(
          t: rng.nextDouble() * (_points.length - 1),
          dir: rng.nextBool() ? 1.0 : -1.0,
          speed: 0.05 + rng.nextDouble() * 0.08, // 采样索引/秒，极慢
          phase: rng.nextDouble() * math.pi * 2,
          radius: 0.7 + rng.nextDouble() * 0.7,
          side: (rng.nextDouble() - 0.5) * 14,
        ),
      );
    }
  }

  /// 每段 Catmull-Rom 的采样数。
  static const int samplesPerSegment = 16;

  /// 同频引路（第 27 轮）：长按点落在径上时，给该段路径「续余温」。
  ///
  /// 沿用既有余温机制——同样的累积速率（dt/1.8）与褪去速率（16 秒
  /// 缓褪），只调本接口不改数值；视觉即该段路径像被走过一样微亮。
  /// [worldPoint] 为长按点的世界坐标，[radius] 内的采样点获得续温。
  void warmNearPoint(Vector2 worldPoint, double dt, {double radius = 80}) {
    final period = JingjingGame.worldPeriod;
    final r2 = radius * radius;
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      var dx = p.dx - worldPoint.x;
      var dy = p.dy - worldPoint.y;
      if (dx > period.x / 2) dx -= period.x;
      if (dx < -period.x / 2) dx += period.x;
      if (dy > period.y / 2) dy -= period.y;
      if (dy < -period.y / 2) dy += period.y;
      if (dx * dx + dy * dy < r2) {
        _warmth[i] = (_warmth[i] + dt / 1.8).clamp(0.0, 1.0);
      }
    }
  }

  /// 世界点到径的最短环绕距离（同频引路的「在径上」判定用，第 27 轮）。
  double distanceToPoint(Vector2 p, {Vector2? period}) {
    final per = period ?? JingjingGame.worldPeriod;
    var best = double.infinity;
    for (int i = 0; i < _points.length; i++) {
      final pt = _points[i];
      var dx = pt.dx - p.x;
      var dy = pt.dy - p.y;
      if (dx > per.x / 2) dx -= per.x;
      if (dx < -per.x / 2) dx += per.x;
      if (dy > per.y / 2) dy -= per.y;
      if (dy < -per.y / 2) dy += per.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < best) best = d2;
    }
    return math.sqrt(best);
  }

  /// 采样点数量（测试用）。
  int get sampleCount => _points.length;

  /// 第 [index] 个采样点的当前余温 0..1（测试用）。
  double warmthAt(int index) => _warmth[index];

  /// 径上尘数量（≤10）。
  static const int dustCount = 10;

  /// 径上判定距离（光灵离径多近算"在径上"）。
  static const double onPathDistance = 40;

  final List<Offset> _points = [];
  final List<double> _warmth = [];
  final List<_PathDust> _dust = [];
  late final Path _basePath;
  // 注意：bbox 在构造函数里先置首点再被 min/max 循环复赋——不能是
  // late final（late final 二次赋值会抛 LateInitializationError，
  // 第 27 轮测试构造第二个实例时暴露的潜在缺陷）。
  double _minX = 0;
  double _maxX = 0;
  double _minY = 0;
  double _maxY = 0;

  // ---- 相会回应（第 18 轮）：眠与惘在附近相会时，径短暂亮起、
  // 径上尘聚拢成一小圈——像径在为它们高兴。由 ReunionEvent 驱动。
  /// 0..1 径的亮起程度（演出期才有值）。
  double reunionGlow = 0;

  /// 径上尘聚拢的目标点（世界坐标；null=不聚拢）。
  Vector2? reunionGather;

  // 复用的画笔与余温叠加 Path（每帧零分配）。
  final Paint _widePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 26;
  final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 7;
  final Paint _warmPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 9;
  final Paint _dustPaint = Paint();
  final Path _warmPath = Path();

  @override
  void update(double dt) {
    // 径上尘：沿径极慢游移（采样索引上往返漂移）。
    for (final d in _dust) {
      d.t += d.dir * d.speed * dt;
      if (d.t > _points.length - 1) {
        d.t = _points.length - 1;
        d.dir = -1;
      } else if (d.t < 0) {
        d.t = 0;
        d.dir = 1;
      }
    }

    // 余温式微光：光灵在径上且平稳呼吸 → 走过的那一段缓缓亮起；
    // 离开后约 16 秒缓缓褪去。无成就无计数，只是雪上的又一串脚印。
    final steady = game.breathSteady;
    final spirit = game.spiritPos;
    final period = JingjingGame.worldPeriod;
    final near2 = onPathDistance * onPathDistance;
    for (int i = 0; i < _points.length; i++) {
      var w = _warmth[i];
      if (w > 0) {
        w -= dt / 16.0; // 余温缓缓褪去
        if (w < 0) w = 0;
      }
      if (steady) {
        final p = _points[i];
        var dx = p.dx - spirit.x;
        var dy = p.dy - spirit.y;
        if (dx > period.x / 2) dx -= period.x;
        if (dx < -period.x / 2) dx += period.x;
        if (dy > period.y / 2) dy -= period.y;
        if (dy < -period.y / 2) dy += period.y;
        if (dx * dx + dy * dy < near2) {
          w = (w + dt / 1.8).clamp(0.0, 1.0); // 走过即留温
        }
      }
      _warmth[i] = w;
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;

    // 透明度：开场淡入 × 苏醒度轻联动（世界越醒，旧迹越清晰一点点）
    // × 相会亮起（眠与惘相会时，径短暂亮起，像在为它们高兴）。
    final scale = game.introEase *
        (0.8 + 0.2 * game.awakeningValue.value) *
        (1.0 + 1.4 * reunionGlow);
    if (scale <= 0.01) return;

    final cam = game.camPos;
    final period = JingjingGame.worldPeriod;
    final cx = size.x / 2;
    final cy = size.y / 2;
    const pad = 40.0;

    // 环绕镜像绘制：对 x/y 各自计算能把路径 bbox 带进视口的周期份数，
    // 只画看得见的副本（接缝两侧各一份，天然无缝衔接）。
    final mxLo = ((cam.x + cx - _maxX - pad) / period.x).floor();
    final mxHi = ((cam.x - cx - _minX + pad) / period.x).ceil();
    final myLo = ((cam.y + cy - _maxY - pad) / period.y).floor();
    final myHi = ((cam.y - cy - _minY + pad) / period.y).ceil();

    var anyVisible = false;
    for (int mx = mxLo; mx <= mxHi; mx++) {
      for (int my = myLo; my <= myHi; my++) {
        final ox = cx - cam.x + mx * period.x;
        final oy = cy - cam.y + my * period.y;
        // bbox 剔除：这个环绕副本根本不在屏上就整份跳过。
        if (_maxX + ox < -pad ||
            _minX + ox > size.x + pad ||
            _maxY + oy < -pad ||
            _minY + oy > size.y + pad) {
          continue;
        }
        anyVisible = true;
        canvas.save();
        canvas.translate(ox, oy);

        // 基础旧迹：宽柔光带 + 窄芯，两层叠出"渐变光带"的柔和感，
        // 峰值 alpha ≤0.12，淡到只可感知。
        _widePaint.color = const Color(
          0xFFcfeee2,
        ).withValues(alpha: 0.045 * scale);
        canvas.drawPath(_basePath, _widePaint);
        _corePaint.color = const Color(
          0xFFdff5ec,
        ).withValues(alpha: 0.075 * scale);
        canvas.drawPath(_basePath, _corePaint);

        // 余温轨迹：被光灵走过且仍有余温的段，短暂亮起后缓缓褪去。
        _warmPath.reset();
        var drawing = false;
        for (int i = 0; i < _points.length; i++) {
          final w = _warmth[i];
          if (w > 0.01) {
            final p = _points[i];
            if (!drawing) {
              _warmPath.moveTo(p.dx, p.dy);
              drawing = true;
            } else {
              _warmPath.lineTo(p.dx, p.dy);
            }
          } else {
            drawing = false;
          }
        }
        if (_warmPath.getBounds().width > 0) {
          _warmPaint.color = const Color(
            0xFFe8dcb0,
          ).withValues(alpha: 0.10 * scale);
          canvas.drawPath(_warmPath, _warmPaint);
        }
        canvas.restore();
      }
    }
    if (!anyVisible) return;

    // 径上尘：沿途极稀疏的缓慢明灭微点（≤10，屏外跳过）。
    // 相会时：尘埃向相会点聚拢成一小圈（像径在为它们高兴）。
    final t = game.time;
    final gather = reunionGather;
    double? gx;
    double? gy;
    if (gather != null && reunionGlow > 0.01) {
      var dx = gather.x - cam.x;
      var dy = gather.y - cam.y;
      if (dx > period.x / 2) dx -= period.x;
      if (dx < -period.x / 2) dx += period.x;
      if (dy > period.y / 2) dy -= period.y;
      if (dy < -period.y / 2) dy += period.y;
      gx = cx + dx;
      gy = cy + dy;
    }
    var dustIndex = 0;
    for (final d in _dust) {
      final i0 = d.t.floor();
      final i1 = math.min(i0 + 1, _points.length - 1);
      final f = d.t - i0;
      final a = _points[i0];
      final b = _points[i1];
      final wx = a.dx + (b.dx - a.dx) * f;
      final wy = a.dy + (b.dy - a.dy) * f;
      // 径向小幅侧偏，让微尘不在路正中排成一列。
      final nx = -(b.dy - a.dy);
      final ny = b.dx - a.dx;
      final nl = math.sqrt(nx * nx + ny * ny);
      final px = wx + (nl > 0.001 ? nx / nl * d.side : 0);
      final py = wy + (nl > 0.001 ? ny / nl * d.side : 0);

      // 环绕最短差到相机。
      var sx = px - cam.x;
      var sy = py - cam.y;
      if (sx > period.x / 2) sx -= period.x;
      if (sx < -period.x / 2) sx += period.x;
      if (sy > period.y / 2) sy -= period.y;
      if (sy < -period.y / 2) sy += period.y;
      final screenX = cx + sx;
      final screenY = cy + sy;
      // 相会聚拢：向相会点外的一小圈（半径 15，按序错开角度）缓移。
      double px2 = screenX;
      double py2 = screenY;
      if (gx != null && gy != null) {
        final ga = dustIndex * 2.4 + t * 0.15;
        px2 += (gx + math.cos(ga) * 15 - screenX) * reunionGlow;
        py2 += (gy + math.sin(ga) * 15 - screenY) * reunionGlow;
      }
      dustIndex++;
      if (px2 < -6 ||
          px2 > size.x + 6 ||
          py2 < -6 ||
          py2 > size.y + 6) {
        continue;
      }
      final twinkle = 0.5 + 0.5 * math.sin(t * 0.4 + d.phase);
      _dustPaint.color = const Color(
        0xFFcfeee2,
      ).withValues(alpha: 0.055 * twinkle * scale);
      canvas.drawCircle(Offset(px2, py2), d.radius, _dustPaint);
    }
  }
}

/// 径上尘：沿路径参数化位置游移的微点（预生成，渲染零分配）。
class _PathDust {
  _PathDust({
    required this.t,
    required this.dir,
    required this.speed,
    required this.phase,
    required this.radius,
    required this.side,
  });

  double t; // 沿采样点的参数（0..points.length-1）
  double dir; // 游移方向
  final double speed; // 采样索引/秒（极慢）
  final double phase; // 明灭相位
  final double radius;
  final double side; // 径向侧偏
}
