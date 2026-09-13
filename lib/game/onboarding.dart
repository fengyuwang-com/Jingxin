import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';

/// 「初次入静」（第 23 轮）——开场呼吸引导演出。
///
/// 无文字轰炸、无教程弹窗：只在光灵旁浮现一句极淡的半透明节奏提示
/// （「按住 · 吸」，用户按下时切换「松开 · 呼」），随呼吸相位淡入淡出；
/// 前 3 个平稳循环后提示渐隐谢幕。若 60 秒内完成 3 个平稳循环（复用
/// 游戏侧平稳循环判定，cycleCount 只统计时长 ≥ steadyCycleMinTime 的
/// 循环），提前谢幕，世界以一次星潮波纹回应作为"学会"的礼物。
///
/// 仅当首次进入（shared_preferences `jingxin.onboarded.v1` 不存在）
/// 且未开启随息麦克风时装配；老用户与随息用户零打扰，之后永不再现。
///
/// 结构：[OnboardingPreference]（持久化）、[OnboardingDirector]（纯逻辑
/// 状态机，可测）、[OnboardingOverlay]（Flame 渲染层）。文案渲染复用
/// 游戏内既有的 TextPainter 方式（参考光灵/惘演出层），动画克制。
/// 性能：画笔与文字预排版、done 后整体从树上移除（零渲染成本）。
/// UTF-8：本文件含中文，写入/读取均须 UTF-8。

/// 引导是否已完成的持久化标记（只写一次，之后永不再现）。
class OnboardingPreference {
  OnboardingPreference();

  static const String prefKey = 'jingxin.onboarded.v1';

  bool onboarded = false;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboarded = prefs.getBool(prefKey) ?? false;
    } catch (_) {
      onboarded = false;
    }
  }

  Future<void> markOnboarded() async {
    onboarded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
    } catch (_) {
      // 持久化失败静默忽略：本次会话内已不再打扰。
    }
  }
}

/// 引导演出的纯逻辑状态机（无渲染无副作用，方便测试）。
///
/// 驱动源：游戏侧的 [JingjingGame.cycleCount]（只统计平稳循环）。
/// 规则：
/// - 前 [requiredCycles] 个循环内为引导期（提示词可见）；
/// - 达到 3 个循环即谢幕；若此时累计引导时间 ≤ [earlyWindowSec] 秒，
///   视为"学得快"，触发提前谢幕与星潮奖励；
/// - 结束只发生一次（[finished] 锁存）。
class OnboardingDirector {
  OnboardingDirector({
    this.requiredCycles = 3,
    this.earlyWindowSec = 60,
    int startCycleCount = 0,
  }) : _lastCycleCount = startCycleCount;

  /// 谢幕所需的平稳循环数。
  final int requiredCycles;

  /// 提前谢幕（星潮奖励）的时间窗（秒）。
  final double earlyWindowSec;

  int _lastCycleCount;

  /// 引导期累计秒数（演出开始起算）。
  double elapsed = 0;

  /// 已计入的平稳循环数。
  int cycles = 0;

  /// 是否已谢幕（锁存，只置一次）。
  bool finished = false;

  /// 是否走的是"提前谢幕"分支（60s 内完成 → 星潮奖励）。
  bool earlyReward = false;

  /// 每帧推进。[cycleCount] 为游戏侧累计平稳循环总数（单调不减）。
  void tick(double dt, int cycleCount) {
    if (finished) return;
    elapsed += dt;
    while (cycleCount > _lastCycleCount) {
      _lastCycleCount++;
      onCycle();
      if (finished) break;
    }
  }

  /// 一个平稳循环完成（含外部直接调用，供测试）。
  void onCycle() {
    if (finished) return;
    cycles++;
    if (cycles >= requiredCycles) finish();
  }

  void finish() {
    if (finished) return;
    finished = true;
    earlyReward = elapsed <= earlyWindowSec;
  }
}

/// 引导演出的渲染层：极淡的节奏提示 + 谢幕短句 + 星潮波纹。
class OnboardingOverlay extends Component with HasGameReference<JingjingGame> {
  OnboardingOverlay({required this.pref, OnboardingDirector? director})
    : director = director ?? OnboardingDirector();

  final OnboardingPreference pref;
  final OnboardingDirector director;

  /// 提示渐隐时长（谢幕起，约 2.5 秒淡出）。
  static const double hintFadeDur = 2.5;

  /// 谢幕短句停留时长（之后整体退场并打标记）。
  static const double finaleDur = 7.0;

  /// 星潮波纹时长（约 3.2 秒，3 圈错落，与相会涟漪同语言）。
  static const double tideDur = 3.2;

  bool _done = false;
  double _sinceFinish = 0;

  // 预排版与预建画笔（零每帧分配）。
  TextPainter? _holdPainter;
  TextPainter? _releasePainter;
  TextPainter? _finalePainter;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  bool get _finaleStarted => director.finished;

  @override
  void update(double dt) {
    if (_done) return;
    director.tick(dt, game.cycleCount);

    if (_finaleStarted) {
      _sinceFinish += dt;
      if (_sinceFinish >= finaleDur) {
        _done = true;
        unawaitedDone();
        removeFromParent();
      }
    }
  }

  /// 谢幕：打上 onboarded 标记（永不再现）。异步 fire-and-forget。
  void unawaitedDone() {
    // ignore: discarded_futures
    pref.markOnboarded();
  }

  /// 光灵屏幕坐标（与 LightSpirit 的落屏方式一致，不含呼吸上浮）。
  Offset _spiritScreen(Vector2 size) {
    final drift = game.spiritPos - game.camPos;
    return Offset(
      size.x / 2 + drift.x,
      size.y / 2 - size.y * 0.04 + drift.y,
    );
  }

  @override
  void render(Canvas canvas) {
    if (_done) return;
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final intro = game.introEase;
    if (intro <= 0.05) return;

    final center = _spiritScreen(size);

    // ---- 节奏提示：跟随呼吸相位淡入淡出 ----
    if (!_finaleStarted) {
      // 相位包络：呼吸两端淡、中段显（sin(progress·π)），克制不刺眼。
      final phase = (0.22 + 0.5 * math.sin(game.breathPhase * math.pi))
          .clamp(0.0, 1.0);
      final alpha = 0.42 * phase * intro;
      if (alpha > 0.01) {
        final painter = game.breathPressing
            ? (_releasePainter ??= _layout('松开 · 呼'))
            : (_holdPainter ??= _layout('按住 · 吸'));
        // 提示浮在光灵下方（光灵半径随呼吸约屏高 0.18 以内，取固定偏移）。
        final dy = size.y * 0.13 + 34;
        final offset = Offset(center.dx - painter.width / 2, center.dy + dy);
        // 透明度按 0.05 档位量化缓存（呼吸准周期，暖机后零成本）。
        _paintWithAlpha(canvas, painter, offset, alpha);
      }
    } else {
      // ---- 谢幕：提示已渐隐，一句短句自 center 上方浮现又淡去 ----
      final t = (_sinceFinish / finaleDur).clamp(0.0, 1.0);
      // 淡入 1.8s → 停留 → 淡出。
      final env = t < 0.28
          ? smoothstep(t / 0.28)
          : t > 0.78
          ? smoothstep((1 - t) / 0.22)
          : 1.0;
      final painter = _finalePainter ??= _layout(
        '呼吸还在，世界就醒着。',
      );
      final alpha = 0.62 * env * intro;
      _paintWithAlpha(
        canvas,
        painter,
        Offset(center.dx - painter.width / 2, center.dy - size.y * 0.16),
        alpha,
      );

      // ---- 星潮波纹（提前谢幕的"学会"奖励）：从光灵处三圈错落扩散 ----
      if (director.earlyReward && _sinceFinish <= tideDur + 0.6) {
        final rt = (_sinceFinish / tideDur).clamp(0.0, 1.0);
        for (int i = 0; i < 3; i++) {
          final tt = rt - i * 0.12;
          if (tt <= 0 || tt >= 1) continue;
          final r = 18.0 + 190.0 * tt;
          _ringPaint.color = ZenTheme.nebulaCyan.withValues(
            alpha: 0.14 * (1 - tt) * env,
          );
          canvas.drawCircle(center, r, _ringPaint);
        }
      }
    }
  }

  // 提示文字的透明度：TextPainter 已按文字 layout 一次，透明度用
  // 量化档位（0.05 步进）重建 TextSpan——呼吸是准周期的，暖机后
  // 每档几乎零成本。
  final Map<int, TextPainter> _alphaCache = {};

  void _paintWithAlpha(
    Canvas canvas,
    TextPainter base,
    Offset offset,
    double alpha,
  ) {
    final q = (alpha * 20).round().clamp(0, 20);
    final painter = _alphaCache[q] ??= TextPainter(
      text: TextSpan(
        text: (base.text as TextSpan).text,
        style: (base.text as TextSpan).style!.copyWith(
          color: ZenTheme.textMuted.withValues(alpha: q / 20),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  TextPainter _layout(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: ZenTheme.textMuted,
        fontSize: 14,
        letterSpacing: 5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static double smoothstep(double t) => t * t * (3 - 2 * t);
}
