import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Draggable;

import 'jingjing_game.dart';

/// 昼夜潮汐（第 36 轮）：静境之外的一天，也在静境里有回声。
///
/// 按本地真实时刻给世界一层极缓的明暗偏移：
/// - 正午最亮（白色提亮，alpha 峰值约 0.045）；
/// - 黄昏偏暖（暖色在昼/夜 tint 里按窗函数混入，不单独叠层）；
/// - 深夜最沉（深黑蓝压暗，alpha 峰值 0.05）。
///
/// 曲线全部是连续函数（以分钟为单位的 sin 窗），跨小时平滑过渡、
/// 无跳变；总 alpha 封顶 [maxAlpha] = 0.05（≤ 0.06 的克制上限）。
/// 长夜模式优先级更高：潮汐 alpha 乘 (1 - nightAmount)，长夜完全
/// 接管时潮汐归零，不与长夜视觉叠加。
///
/// 曲线是纯函数（[tideTintAt] / [tideEffectiveAlpha]），可测；
/// 渲染层按"分钟 + 量化长夜量"缓存颜色，每帧零分配。
class DayTide {
  DayTide._();

  /// 潮汐 alpha 的硬上限（克制原则：总扰动 ≤0.06）。
  static const double maxAlpha = 0.05;

  /// 正午提亮峰值（约 4.5%）。
  static const double noonLift = 0.045;

  /// 深夜压暗峰值（5%）。
  static const double midnightSink = 0.05;

  /// 正午用的暖白（比纯白柔，不刺眼）。
  static const Color noonTint = Color(0xFFFFF6E4);

  /// 黄昏混入昼侧 tint 的暖色（落日余温）。
  static const Color duskWarmTint = Color(0xFFC07040);

  /// 深夜压暗的底色（比纯黑多一点蓝，与夜空同族）。
  static const Color nightTint = Color(0xFF020409);

  /// 黄昏混入夜侧 tint 的余烬暖（极低饱和）。
  static const Color duskEmberTint = Color(0xFF40260F);

  /// 昼光系数 d：-1..1 连续周期函数。正午=+1，午夜=-1，
  /// 6:00 与 18:00 过零（m=1440 与 m=0 处同为 -1，环绕连续）。
  static double daylight(int minutes) =>
      math.sin(math.pi * (minutes - 360) / 720);

  /// 黄昏暖度 g：0..1 的 sin 窗，只在 17:00–20:30 之间非零，
  /// 峰值 18:45，两端归零（与昼/夜 tint 的混合系数连续）。
  static double duskWarmth(int minutes) {
    const start = 1020; // 17:00
    const end = 1230; // 20:30
    if (minutes <= start || minutes >= end) return 0;
    return math.sin(math.pi * (minutes - start) / (end - start));
  }

  /// 纯函数：分钟数 → 单层 tint 颜色与 alpha。
  /// 昼侧 = 暖白提亮（黄昏混入暖色），夜侧 = 深黑蓝压暗（黄昏混入余烬）。
  /// 18:00 过零点两侧 alpha 都趋 0，颜色随 g 连续，无跳变。
  static ({Color color, double alpha}) tideTintAt(int minutes) {
    final d = daylight(minutes);
    final g = duskWarmth(minutes);
    if (d >= 0) {
      final color = Color.lerp(noonTint, duskWarmTint, g)!;
      return (color: color, alpha: noonLift * d);
    }
    final color = Color.lerp(nightTint, duskEmberTint, g)!;
    return (color: color, alpha: midnightSink * -d);
  }

  /// 纯函数：长夜让位。潮汐有效 alpha = 基础 alpha × (1 - nightAmount)，
  /// 长夜完全激活（nightAmount=1）时为 0——完全沿用长夜现有视觉。
  static double tideEffectiveAlpha(double alpha, double nightAmount) {
    final yield = 1.0 - nightAmount.clamp(0.0, 1.0);
    return (alpha * yield).clamp(0.0, maxAlpha);
  }
}

/// 潮汐渲染层（第 36 轮）：单层全屏半透明 tint，画在世界之上、
/// 声景天气层与各演出层之下（对现有视觉扰动最小的顶层方案）。
///
/// 性能纪律：颜色按"分钟数 + 量化长夜量"缓存，只有缓存键变化才
/// 重建 Color；Paint 复用；每帧零分配。
class DayTideLayer extends Component with HasGameReference<JingjingGame> {
  final Paint _paint = Paint();
  int _cacheKey = -1;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    // 长夜量按 0.02 量化进缓存键：让位过程也是平滑的，无需每帧重建。
    final nightQ = (game.nightAmount * 50).round();
    final key = minutes * 51 + nightQ;
    if (key != _cacheKey) {
      _cacheKey = key;
      final tide = DayTide.tideTintAt(minutes);
      final alpha = DayTide.tideEffectiveAlpha(tide.alpha, game.nightAmount);
      if (alpha < 0.001) {
        _paint.color = const Color(0x00000000);
      } else {
        _paint.color = tide.color.withValues(alpha: alpha);
      }
    }
    if (_paint.color.a < 0.001) return; // 完全无扰动时零绘制成本。
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);
  }
}
