import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';
import 'mist_guardian.dart';
import 'shard.dart';
import 'star_beast.dart';
import 'still_path.dart';

/// 「相会」（第 18 轮）——眠与惘的稀有时刻。
///
/// 极稀有、完全无提示的彩蛋：当四件事恰好同时成立——
/// 眠处于全睁后的游弋期、惘完全显形（雾沉降到底）、世界苏醒度较高、
/// 且光灵恰好在两兽连线的中点附近完成一次平稳呼吸循环——
/// 眠缓缓上浮、惘从雾林边缘走出，两者向中点各移近一段（有上限），
/// 在相距最近处亮起一线极细的星光，静之径的那一段也随之短暂亮起，
/// 径上尘聚拢成一小圈；随后眠发出一次极缓的深海鸣（同心涟漪），
/// 惘竖耳凝望，各自缓缓退回。全程无文字、无锁定、无弹窗。
///
/// 唯一留念：相会时刻在光灵身旁静置一枚金色「双星碎片」，
/// 走拾取/心镜/星图全链路（region「两兽之间」，专属偈语）。
/// 同一游弋周期至多触发一次（以 swimUntilEpoch 记账）。
///
/// 触发判定是纯函数（[ReunionTrigger.shouldTrigger]），演出是一个
/// 小状态机（[ReunionPhase]），方便将来补测试。
///
/// 性能：全部用现有渲染原语（线/圆/渐变），画笔预建、无每帧分配、
/// 屏外整体跳过；对星兽/惘的位移只是给它们各自的一个 nudge 向量
/// 赋值，不新增任何渲染系统。
class ReunionTrigger {
  ReunionTrigger._();

  /// 眠须处于游弋期（由调用方传 state.swimming）。
  static const double minAwakening = 0.5;

  /// 惘须完全显形。
  static const double minGuardianReveal = 0.85;

  /// 光灵离两兽连线中点的最大距离（世界单位）。
  static const double maxSpiritDistance = 260;

  /// 纯函数触发判定（无副作用，方便测试）。
  static bool shouldTrigger({
    required bool beastSwimming,
    required double guardianReveal,
    required double awakening,
    required double spiritToMidpoint,
  }) {
    return beastSwimming &&
        guardianReveal > minGuardianReveal &&
        awakening > minAwakening &&
        spiritToMidpoint < maxSpiritDistance;
  }
}

/// 相会演出的阶段（线性小状态机）。
enum ReunionPhase { idle, approach, glow, retreat }

/// 相会演出组件：驱动两兽的 nudge、星光连线、静之径回应、
/// 深海鸣涟漪与惘的凝望，并在相距最近处放置「双星碎片」。
class ReunionEvent extends Component with HasGameReference<JingjingGame> {
  ReunionEvent({required this.beast, required this.guardian, required this.path});

  final StarBeast beast;
  final MistGuardian guardian;
  final StillPath path;

  // ---- 演出时间轴（秒）----
  /// 各自向中点移近的时长（极慢）。
  static const double approachDur = 26;

  /// 星光连线的起/落窗口。
  static const double glowInStart = 24;
  static const double glowFull = 26;
  static const double glowFadeEnd = 34;

  /// 深海鸣涟漪（从相距最近处开始，约 3.2 秒，3 圈错落）。
  static const double rippleStart = 26.8;
  static const double rippleDur = 3.2;

  /// 各自退回的时长（眠继续游弋/归位，惘退回雾里）。
  static const double retreatDur = 16;

  /// 每兽向中点移近的最大距离（世界单位）。
  static const double maxApproach = 200;

  ReunionPhase _phase = ReunionPhase.idle;
  double _t = 0;

  /// 本次游弋周期已相会过的记账（swimUntilEpoch；0=未触发过）。
  int _doneSwimEpoch = 0;

  int _lastCycleCount = -1;

  /// 相距最近处（连线中点）的世界坐标，涟漪与碎片以此为原点。
  final Vector2 _meetPoint = Vector2.zero();

  // 画笔预建（零每帧分配）。
  final Paint _lineCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7
    ..strokeCap = StrokeCap.round;
  final Paint _lineSoftPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;
  final Paint _ripplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  @override
  void onLoad() {
    _lastCycleCount = game.cycleCount;
  }

  @override
  void update(double dt) {
    if (_phase == ReunionPhase.idle) {
      _tryTrigger();
      return;
    }

    _t += dt;

    // 移近 / 退回：nudge 向量从各自基础位置指向中点（有上限）。
    if (_t < glowFadeEnd + retreatDur) {
      _applyNudges();
    } else {
      beast.reunionNudge.setZero();
      guardian.reunionNudge.setZero();
      _phase = ReunionPhase.idle;
      _t = 0;
      path.reunionGlow = 0;
      path.reunionGather = null;
      guardian.gaze = 0;
      return;
    }

    // 星光连线窗口：淡入-保持-淡出。
    final glow = _glowEnvelope();
    path.reunionGlow = glow;
    if (glow > 0.001) {
      path.reunionGather = _meetPoint;
    } else {
      path.reunionGather = null;
    }

    // 惘的凝望：星光亮起期间竖耳凝望。
    guardian.gaze = glow;

    // 相距最近处：放置双星碎片（一次）+ 深海鸣涟漪由 render 表现。
    if (_t >= glowFull && _t - dt < glowFull) {
      _placeShard();
    }
  }

  void _tryTrigger() {
    // 同一游弋周期至多一次：以游弋截止时间戳记账。
    final epoch = beast.state.swimUntilEpoch;
    if (beast.state.swimming && _doneSwimEpoch == epoch && epoch != 0) return;

    // 只在"完成一次平稳呼吸循环"的时刻评估（稀有性的核心一环）。
    if (game.cycleCount == _lastCycleCount) return;
    _lastCycleCount = game.cycleCount;

    if (!beast.state.swimming) return;

    final mid = _midpoint();
    if (mid == null) return;
    final d = game.spiritPos - mid;
    game.wrapDelta(d);

    if (ReunionTrigger.shouldTrigger(
      beastSwimming: true,
      guardianReveal: guardian.reveal,
      awakening: game.awakeningValue.value,
      spiritToMidpoint: d.length,
    )) {
      _doneSwimEpoch = beast.state.swimUntilEpoch;
      _phase = ReunionPhase.approach;
      _t = 0;
      _meetPoint.setFrom(mid);
    }
  }

  /// 两兽当前（不含 nudge）的连线中点；任一兽屏外/不可考时返回 null。
  Vector2? _midpoint() {
    final b = beast.pos - beast.reunionNudge;
    final g = guardian.pos - guardian.reunionNudge;
    final mid = Vector2(
      b.x + shortestArc(b.x, g.x, JingjingGame.worldPeriod.x) * 0.5,
      b.y + shortestArc(b.y, g.y, JingjingGame.worldPeriod.y) * 0.5,
    );
    game.wrap(mid);
    return mid;
  }

  /// a 到 b 的最短环绕差（标量版，避免每帧分配）。
  static double shortestArc(double a, double b, double period) {
    var d = b - a;
    if (d > period / 2) d -= period;
    if (d < -period / 2) d += period;
    return d;
  }

  void _applyNudges() {
    final mid = _midpoint();
    if (mid == null) return;
    _meetPoint.setFrom(mid);

    // 移近进度：0..1 平滑起落；退回期同一条曲线反向收回。
    final total = glowFadeEnd + retreatDur;
    final retreatT = ((total - _t) / retreatDur).clamp(0.0, 1.0);
    final ease = _t <= glowFadeEnd
        ? smoothstep((_t / approachDur).clamp(0.0, 1.0))
        : smoothstep(retreatT);

    _nudgeOne(beast.pos, beast.reunionNudge, mid, ease);
    _nudgeOne(guardian.pos, guardian.reunionNudge, mid, ease);
  }

  void _nudgeOne(Vector2 basePos, Vector2 nudge, Vector2 mid, double ease) {
    final period = JingjingGame.worldPeriod;
    final dx = shortestArc(basePos.x, mid.x, period.x);
    final dy = shortestArc(basePos.y, mid.y, period.y);
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) {
      nudge.setZero();
      return;
    }
    // 各移近一段（上限 maxApproach），绝不完全重合。
    final reach = math.min(maxApproach, len * 0.4) * ease;
    nudge
      ..setZero()
      ..x = dx / len * reach
      ..y = dy / len * reach;
  }

  double _glowEnvelope() {
    if (_t <= glowInStart || _t >= glowFadeEnd) return 0;
    if (_t < glowFull) {
      return smoothstep((_t - glowInStart) / (glowFull - glowInStart));
    }
    return smoothstep(((glowFadeEnd - _t) / (glowFadeEnd - glowFull))
        .clamp(0.0, 1.0));
  }

  static double smoothstep(double t) => t * t * (3 - 2 * t);

  /// 相距最近处静置一枚金色「双星碎片」（走拾取/心镜/星图全链路）。
  void _placeShard() {
    final shard = MindShard(
      // 放在光灵身旁极近处——下一次平稳呼吸自然吸入，无提示。
      position: game.spiritPos + Vector2(34, -22),
      phase: game.time % (math.pi * 2),
      tint: const Color(0xFFe8c96a),
      reunion: true,
    );
    game.shards.add(shard);
    game.add(shard);
  }

  /// 世界坐标 -> 屏幕坐标（按各自视差，环绕最近镜像）。
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
    if (_phase == ReunionPhase.idle) return;
    final glow = _glowEnvelope();
    if (glow <= 0.001) return;

    // 星光连线：两端各自按本兽的视差落到屏幕（眠 0.7 / 惘 0.8），
    // 中点即相距最近处。极细的一线 + 一层更柔的底光。
    final a = _toScreen(beast.pos, StarBeast.parallax);
    final b = _toScreen(guardian.pos, MistGuardian.parallax);
    final len = (b - a).distance;
    if (len > 1400) return;

    final soft = ZenTheme.nebulaCyan.withValues(alpha: 0.085 * glow);
    final core = ZenTheme.starWhite.withValues(alpha: 0.26 * glow);
    _lineSoftPaint.color = soft;
    _lineCorePaint.color = core;
    canvas.drawLine(a, b, _lineSoftPaint);
    canvas.drawLine(a, b, _lineCorePaint);

    // 连线中点一颗稍亮的星（相会的「灯」）。
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    canvas.drawCircle(
      mid,
      1.6,
      _lineCorePaint..color = ZenTheme.starWhite.withValues(alpha: 0.5 * glow),
    );

    // 深海鸣涟漪：眠在相距最近处发出的一次极缓同心圆（3 圈错落），
    // 青色，约 3.2 秒整体起落。
    if (_t >= rippleStart && _t < rippleStart + rippleDur + 0.6) {
      final rt = (_t - rippleStart) / rippleDur;
      for (int i = 0; i < 3; i++) {
        final t = rt - i * 0.13;
        if (t <= 0 || t >= 1) continue;
        final r = 20.0 + 240.0 * t;
        final alpha = 0.16 * (1 - t) * glow;
        _ripplePaint.color = ZenTheme.nebulaCyan.withValues(alpha: alpha);
        canvas.drawCircle(mid, r, _ripplePaint);
      }
    }
  }
}
