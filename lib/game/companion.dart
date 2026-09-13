import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';
import 'quality.dart';

/// 「同频引路」（第 27 轮）——静之径附近的指尖陪伴互动。
///
/// 理念：指尖不是操控，而是陪伴。在静之径附近长按不动（≥1.2 秒无
/// 位移）时，光灵不改变呼吸节奏，而是以极缓慢的漂移（缓动、无急
/// 加速）向指尖所在处靠近，直至 30px 内停驻；松手后光灵在原地停留
/// 2 秒，再缓缓回归呼吸驱动的巡游路径。
///
/// 靠近时身后拖出一串细小星尘尾迹（低档画质粒子减半），尾迹粒子
/// 在 2~3 秒内柔散，不遮挡星图。
///
/// 互斥：开场引导 / 相会演出进行中不触发（[CompanionGuide.update]
/// 的 blocked 入参）。
///
/// 结构：[CompanionGuide] 是纯逻辑状态机（可测，不依赖 Flame）；
/// [CompanionDust] 是渲染层（星尘尾迹，粒子池固定，零每帧分配）。
///
/// 性能：粒子池固定、屏外跳过、画笔预建；状态机每帧只有常数次
/// 比较，无 List/Random 分配。

/// 同频引路的状态。
enum CompanionState {
  /// 未激活（默认）：一切照旧。
  idle,

  /// 接近中：光灵以极缓漂移向指尖靠近。
  approaching,

  /// 松手后的停驻：光灵在原地停留 [CompanionGuide.restDuration]
  /// 后回到 idle。
  resting,
}

/// 同频引路的状态机（纯逻辑，无 Flame 依赖，可测）。
///
/// 用法：每帧调用 [update]，传入当前是否按住、光灵到指尖是否已
/// 进入停驻距离、以及演出互斥标记（开场引导 / 相会中为 true）。
class CompanionGuide {
  CompanionState state = CompanionState.idle;

  /// 触发长按所需的最短持续按住时长（秒）。
  static const double holdThreshold = 1.2;

  /// 光灵与指尖距离小于此值即停驻（世界单位，逻辑像素）。
  static const double stopDistance = 30;

  /// 松手后光灵在原地停留的时长（秒）。
  static const double restDuration = 2.0;

  double _holdTime = 0;
  double _restTime = 0;

  /// 接近中是否正在移动（进入停驻距离后为 false，光灵悬停）。
  bool moving = false;

  /// 每帧推进状态机。dt 为帧间隔（秒）。
  ///
  /// - [holding]：用户当前是否按住屏幕。
  /// - [withinStopDistance]：光灵到指尖是否已在 [stopDistance] 内。
  /// - [blocked]：演出互斥（开场引导 / 相会演出进行中为 true）。
  void update({
    required bool holding,
    required bool withinStopDistance,
    required bool blocked,
    required double dt,
  }) {
    moving = false;
    switch (state) {
      case CompanionState.idle:
        if (blocked) {
          _holdTime = 0; // 演出中：长按计时清零，演出结束重新起算。
          return;
        }
        if (holding) {
          _holdTime += dt;
          if (_holdTime >= holdThreshold) {
            state = CompanionState.approaching;
            moving = !withinStopDistance; // 阈值帧即给出正确的移动标记。
          }
        } else {
          _holdTime = 0;
        }
      case CompanionState.approaching:
        if (!holding) {
          state = CompanionState.resting;
          _restTime = 0;
          return;
        }
        if (blocked) {
          // 演出中途开始：立刻退场，不与演出争光灵。
          state = CompanionState.idle;
          _holdTime = 0;
          return;
        }
        moving = !withinStopDistance;
      case CompanionState.resting:
        if (holding) {
          // 再次按住：回到 idle 重新起算长按（不瞬切，须再等满阈值）。
          state = CompanionState.idle;
          _holdTime = dt;
          return;
        }
        _restTime += dt;
        if (_restTime >= restDuration) {
          state = CompanionState.idle;
          _holdTime = 0;
        }
    }
  }
}

/// 同频引路的星尘尾迹（第 27 轮）：光灵缓慢靠近指尖时，身后留下
/// 一串细小星尘，在 2~3 秒内柔散。粒子池固定（低档画质减半，
/// 复用 quality 档位），屏外跳过，零每帧分配；不遮挡星图——
/// alpha 峰值仅 0.14，半径 ≤1.6。
class CompanionDust extends Component with HasGameReference<JingjingGame> {
  CompanionDust() {
    for (int i = 0; i < Quality.current.companionDust; i++) {
      _pool.add(_Dust());
    }
  }

  /// 尾迹粒子柔散时长（秒，2~3 秒区间取中）。
  static const double fadeDuration = 2.5;

  /// 发射间隔（秒）：光灵缓慢漂移，尾迹稀疏即可。
  static const double emitInterval = 0.07;

  final List<_Dust> _pool = [];
  int _next = 0;
  double _emitTimer = 0;
  final Paint _paint = Paint();

  // 尾迹的极缓漂散速度（每颗一个小随机量，构造时定死，运行期零随机）。
  final math.Random _rng = math.Random(27);

  @override
  void update(double dt) {
    final active = game.companion.state == CompanionState.approaching &&
        game.spiritVelocity.length > 2;
    if (!active) return;

    _emitTimer += dt;
    while (_emitTimer >= emitInterval) {
      _emitTimer -= emitInterval;
      final d = _pool[_next];
      _next = (_next + 1) % _pool.length;
      d.pos.setFrom(game.spiritPos);
      d.age = 0;
      d.vx = (_rng.nextDouble() - 0.5) * 3.0; // 极缓的柔散漂移
      d.vy = (_rng.nextDouble() - 0.5) * 3.0 - 1.2; // 微微上浮
    }
    for (final d in _pool) {
      if (d.age < fadeDuration) {
        d.age += dt;
        d.pos.x += d.vx * dt;
        d.pos.y += d.vy * dt;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final cam = game.camPos;
    final cx = size.x / 2;
    final cy = size.y / 2;
    final period = JingjingGame.worldPeriod;

    for (final d in _pool) {
      if (d.age <= 0 || d.age >= fadeDuration) continue;
      // 环绕最短差到相机。
      var sx = d.pos.x - cam.x;
      var sy = d.pos.y - cam.y;
      if (sx > period.x / 2) sx -= period.x;
      if (sx < -period.x / 2) sx += period.x;
      if (sy > period.y / 2) sy -= period.y;
      if (sy < -period.y / 2) sy += period.y;
      final px = cx + sx;
      final py = cy + sy;
      if (px < -4 || px > size.x + 4 || py < -4 || py > size.y + 4) continue;

      // 柔散：alpha 与半径随年龄缓缓收束（sin 起落，两端归零，不闪烁）。
      final t = d.age / fadeDuration;
      final a = math.sin(math.pi * t) * 0.14 * game.introEase;
      if (a <= 0.002) continue;
      _paint.color = const Color(0xFFcfeee2).withValues(alpha: a);
      canvas.drawCircle(Offset(px, py), 1.6 * (1 - 0.4 * t), _paint);
    }
  }
}

/// 单颗星尘（池化复用，构造期零分配）。
class _Dust {
  final Vector2 pos = Vector2.zero();
  double age = 0;
  double vx = 0;
  double vy = 0;
}
