import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';
import 'koans.dart';
import 'mist_guardian.dart';
import 'reunion.dart';
import 'star_beast.dart';

/// 「满醒」终幕（第 28 轮）——世界第一次完全苏醒的回礼。
///
/// 苏醒度 0→1 约十几分钟，满值是一次性的：世界整体提亮一档，
/// 一道"环世界光潮"自两兽相会中点向四周扩散一圈，眠与惘同时
/// 缓缓睁眼、相向各游近一段（只借相会的视觉语言，不触发相会演出、
/// 不留碎片），然后浮现一句满醒偈，停留后整体淡出。
/// 苏醒度此后自然涨落，不受任何影响。
///
/// 跨会话只演一次：偏好键 `jingxin.fullawake.v1` 记"已演过"。
/// 若苏醒度因长时间不呼吸回落到 0.9 以下后再次满值——不再重演，
/// 只做一次轻量波纹（无文字、无兽、无提亮）。
///
/// 演出中不要求呼吸、无失败；任何触摸 0.9s 快速淡出（标记照打）。
/// 与相会演出 / 晨光告别 / 开场引导互斥：同帧冲突时后到者让先。
///
/// 触发判定与"已演过"记账抽成纯函数（[FullAwakeCtl.decide]），
/// 演出本体是一个小状态机（[FullAwakePhase]），方便测试。
enum FullAwakeDecision { none, fullShow, lightRipple }

/// 满醒演出的触发判定与一次性记账（纯逻辑，无 Flame 依赖）。
class FullAwakeCtl {
  FullAwakeCtl._();

  /// 跨会话"已演过"标记（只演一次的核心）。
  static const String prefKey = 'jingxin.fullawake.v1';

  /// 回落深度：苏醒度跌破该值再回满，也只会是轻量波纹
  /// （满值演出一生只有一次，与回落深度无关——记账在先）。
  static const double redipFloor = 0.9;

  /// 纯函数触发判定：苏醒度"跨过" 1.0（上一帧还没满、这一帧满了）
  /// 才算一次满值时刻；持续停在 1.0 不重复触发。已演过 → 只波纹。
  static FullAwakeDecision decide({
    required double prev,
    required double cur,
    required bool playedEver,
  }) {
    final crossed = prev < 1.0 && cur >= 1.0;
    if (!crossed) return FullAwakeDecision.none;
    return playedEver
        ? FullAwakeDecision.lightRipple
        : FullAwakeDecision.fullShow;
  }

  /// 读取跨会话"已演过"标记（失败按未演过处理——宁可多一次回礼，
  /// 也不让一生的演出因存储故障缺席）。
  static Future<bool> loadPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打上"已演过"标记（跳过也照打——错过就是错过，不补演）。
  static Future<void> markPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
    } catch (_) {
      // 持久化失败静默忽略：本场演出照常，下次会话可能重演一次。
    }
  }
}

/// 满醒演出的阶段。
enum FullAwakePhase { idle, show, ripple }

/// 满醒演出组件：时间轴驱动提亮、环世界光潮、两兽睁眼游近与
/// 满醒偈（偈语通过 ValueNotifier 交给 UI 层呈现，与晨光告别同路）。
class FullAwakeEvent extends Component with HasGameReference<JingjingGame> {
  FullAwakeEvent({required this.beast, required this.guardian});

  final StarBeast beast;
  final MistGuardian guardian;

  // ---- 演出时间轴（秒），全部收敛在 FullAwakeCtl 的节奏常数区 ----
  /// 全屏星空整体提亮一档的时长（演出开头，缓缓亮起）。
  static const double skyLiftDur = 2.5;

  /// 环世界光潮：起点（提亮未完即起，重叠更连绵）与单圈时长。
  static const double waveStart = 1.0;
  static const double waveDur = 15.0;

  /// 两兽睁眼与相向游近的窗口。
  static const double beastStart = 3.0;
  static const double beastDur = 10.0;

  /// 满醒偈：淡入起点 / 淡入时长 / 停留时长。
  static const double koanStart = 12.0;
  static const double koanFade = 2.0;
  static const double koanHold = 8.0;

  /// 整体淡出：起点与时长（演出收束，回普通世界态）。
  static const double fadeStart = 22.0;
  static const double fadeDur = 5.0;

  /// 演出总时长（约 27s，提亮→光潮→睁眼游近→偈语→淡出）。
  static const double totalDur = fadeStart + fadeDur;

  /// 触摸跳过的快速淡出时长。
  static const double skipDur = 0.9;

  /// 轻量波纹（已演过后的再次满值）时长。
  static const double rippleDur = 3.2;

  /// 两兽相向游近的最大距离（世界单位）——只各近一段，绝不重合。
  static const double maxApproach = 120.0;

  FullAwakePhase _phase = FullAwakePhase.idle;
  double _t = 0;
  bool _playedEver = false;
  bool _koanShown = false;
  bool _fadeSignaled = false;

  /// 光潮与波纹的原点（两兽连线中点；不可考时退回相机中心）。
  final Vector2 _origin = Vector2.zero();

  bool get active => _phase != FullAwakePhase.idle;

  @override
  Future<void> onLoad() async {
    _playedEver = await FullAwakeCtl.loadPlayed();
  }

  @override
  void update(double dt) {
    final cur = game.awakeningValue.value;
    if (_phase == FullAwakePhase.idle) {
      final decision = FullAwakeCtl.decide(
        prev: _prevAwakening,
        cur: cur,
        playedEver: _playedEver,
      );
      _prevAwakening = cur;
      // 互斥（后到者让先）：开场引导 / 相会演出 / 晨光告别进行中不触发。
      if (decision == FullAwakeDecision.none ||
          game.onboarding != null ||
          game.reunion.active ||
          game.farewellPlaying) {
        return;
      }
      _begin(decision);
      return;
    }

    _t += dt;
    _prevAwakening = cur;

    if (_phase == FullAwakePhase.ripple) {
      if (_t >= rippleDur) _reset();
      return;
    }

    // 满醒偈：到点浮现（只一次），整体淡出开始时交给 UI 收走。
    if (!_koanShown && !_fadeSignaled && _t >= koanStart) {
      _koanShown = true;
      game.fullAwakeKoan.value = Koans.nextFullAwake();
    }
    if (!_fadeSignaled && _t >= fadeStart) {
      _fadeSignaled = true;
      game.fullAwakeEnding.value = true;
    }

    // 两兽：睁眼（沿用每只眼约 4s 的既有渐变）+ 相向游近一段；
    // 淡出期随整体缓缓退回，绝不瞬跳。
    final inWindow = _t >= beastStart;
    final ease = inWindow
        ? smoothstep(((_t - beastStart) / beastDur).clamp(0.0, 1.0))
        : 0.0;
    final retreat = _t > fadeStart
        ? 1.0 -
              smoothstep(
                ((_t - fadeStart) /
                        (_fadeSignaled ? skipDur : fadeDur))
                    .clamp(0.0, 1.0),
              )
        : 1.0;
    final reach = ease * retreat;
    beast.wakeOverride = reach;
    beast.reunionNudge.setFrom(_nudgeToward(beast.pos, reach));
    guardian.reunionNudge.setFrom(_nudgeToward(guardian.pos, reach));
    guardian.gaze = reach;

    if (_t >= totalDur + skipDur) _reset();
  }

  double _prevAwakening = 0;

  void _begin(FullAwakeDecision decision) {
    _t = 0;
    _koanShown = false;
    _fadeSignaled = false;
    _origin.setFrom(_meetMidpoint() ?? game.camPos.clone());
    if (decision == FullAwakeDecision.lightRipple) {
      _phase = FullAwakePhase.ripple;
      return;
    }
    _phase = FullAwakePhase.show;
    _playedEver = true; // 跳过也照打：错过就是错过。
    // ignore: discarded_futures
    FullAwakeCtl.markPlayed();
  }

  /// 演出中任何触摸：跳过——立刻进入 0.9s 快速淡出（标记已照打）。
  void skip() {
    if (_phase != FullAwakePhase.show || _fadeSignaled) return;
    _fadeSignaled = true;
    game.fullAwakeKoan.value = null;
    game.fullAwakeEnding.value = true;
    game.fullAwakeFast.value = true;
    // 快速淡出：时间轴直接跳到收束段，位移按 fadeDur 比例压缩退回。
    _t = fadeStart;
    beast.wakeOverride = 0;
    beast.reunionNudge.setZero();
    guardian.reunionNudge.setZero();
    guardian.gaze = 0;
  }

  void _reset() {
    _phase = FullAwakePhase.idle;
    _t = 0;
    _koanShown = false;
    _fadeSignaled = false;
    beast.wakeOverride = 0;
    beast.reunionNudge.setZero();
    guardian.reunionNudge.setZero();
    guardian.gaze = 0;
    game.fullAwakeKoan.value = null;
    game.fullAwakeEnding.value = false;
    game.fullAwakeFast.value = false;
  }

  /// 两兽当前连线中点（相会的"相会中点"），环绕最近差计算。
  Vector2? _meetMidpoint() {
    final b = beast.pos - beast.reunionNudge;
    final g = guardian.pos - guardian.reunionNudge;
    final mid = Vector2(
      b.x + ReunionEvent.shortestArc(b.x, g.x, JingjingGame.worldPeriod.x) * 0.5,
      b.y + ReunionEvent.shortestArc(b.y, g.y, JingjingGame.worldPeriod.y) * 0.5,
    );
    game.wrap(mid);
    return mid;
  }

  /// 从 base 朝光潮原点的游近位移（上限 maxApproach，绝不重合）。
  Vector2 _nudgeToward(Vector2 basePos, double ease) {
    if (ease <= 0.001) return Vector2.zero();
    final period = JingjingGame.worldPeriod;
    final dx = ReunionEvent.shortestArc(basePos.x, _origin.x, period.x);
    final dy = ReunionEvent.shortestArc(basePos.y, _origin.y, period.y);
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return Vector2.zero();
    final reach = math.min(maxApproach, len * 0.35) * ease;
    return Vector2(dx / len * reach, dy / len * reach);
  }

  static double smoothstep(double t) => t * t * (3 - 2 * t);

  /// 世界坐标 -> 屏幕坐标（视差 1，环绕最近镜像）。
  Offset _toScreen(Vector2 world) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    double dx = (world.x - game.camPos.x) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (world.y - game.camPos.y) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Offset(size.x / 2 + dx, size.y / 2 + dy);
  }

  final Paint _liftPaint = Paint();
  final Paint _wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    if (_phase == FullAwakePhase.idle) return;
    final size = game.size;
    final center = _toScreen(_origin);

    if (_phase == FullAwakePhase.ripple) {
      // 轻量波纹：单圈极淡涟漪，无文字无兽无提亮——世界"又满了一次"。
      final t = (_t / rippleDur).clamp(0.0, 1.0);
      final alpha = 0.10 * math.sin(math.pi * t);
      if (alpha > 0.002) {
        _wavePaint.strokeWidth = 1.1;
        _wavePaint.color = ZenTheme.nebulaCyan.withValues(alpha: alpha);
        canvas.drawCircle(center, 24.0 + 300.0 * t, _wavePaint);
      }
      return;
    }

    // 整体淡出系数（跳过时 0.9s 快速收束）。
    final fadeT = _fadeSignaled
        ? ((_t - fadeStart) / skipDur).clamp(0.0, 1.0)
        : ((_t - fadeStart) / fadeDur).clamp(0.0, 1.0);
    final fade = 1.0 - smoothstep(fadeT);

    // 全屏星空整体提亮一档：低饱和青白，alpha 峰值仅 0.05——
    // 是"世界睁开了"，不是闪光。
    final liftEnv =
        smoothstep((_t / skyLiftDur).clamp(0.0, 1.0)) * fade;
    if (liftEnv > 0.002) {
      _liftPaint.color = const Color(0xFFbcd2e8).withValues(
        alpha: 0.05 * liftEnv,
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _liftPaint);
    }

    // 环世界光潮：自相会中点向四周扩散的柔光波，单圈 15s。
    // 一条主环 + 一条更柔的跟随环（半拍之后），两端归零不闪烁。
    final wt = (_t - waveStart) / waveDur;
    if (wt > 0 && wt < 1) {
      final maxR =
          math.sqrt(size.x * size.x + size.y * size.y) + 220.0;
      final env = math.sin(math.pi * wt) * fade;
      if (env > 0.002) {
        final r = 26.0 + maxR * smoothstep(wt);
        _wavePaint.strokeWidth = 1.3;
        _wavePaint.color =
            ZenTheme.nebulaCyan.withValues(alpha: 0.14 * env);
        canvas.drawCircle(center, r, _wavePaint);
        final r2 = 26.0 + maxR * smoothstep((wt - 0.06).clamp(0.0, 1.0));
        _wavePaint.strokeWidth = 4.0;
        _wavePaint.color =
            ZenTheme.nebulaCyan.withValues(alpha: 0.05 * env);
        canvas.drawCircle(center, r2, _wavePaint);
      }
    }
  }
}
