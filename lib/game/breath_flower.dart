/// 星花开谢——呼吸的痕迹（第 55 轮，新支线）。
///
/// 理念：光灵平稳呼吸时，身后会积攒出"星花"——呼吸的痕迹在世界里
/// 开出花来。花不给碎片不给分数，纯粹是世界的美与回应（愿景支柱：
/// 温柔正反馈）。
///
/// 规则（全部纯函数，状态由游戏层内存持有，不持久化）：
/// - 光灵平稳呼吸时以约 [kFlowerBloomSeconds]（40s）注满一次"花开"；
///   注满即触发一次种花事件，随后累积归零、可循环再开；
/// - 平稳度低于阈值（呼吸不平稳）时，累积按 [kFlowerDecayPerSecond]
///   （1.5/s）退回——花还没开，就先慢慢攒不上了；
/// - 呼吸持续紊乱约 [kFlowerWitherSeconds]（12s）时，已开的花按平滑
///   曲线收拢（花谢不是惩罚——收拢后花变暗但不消失，恢复平稳后
///   缓慢重开）；
/// - 长夜时段（nightAmount）花自动闭合入眠：闭合不是消失。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 注满一次花开所需的有效平稳秒数（约 40s）。
const double kFlowerBloomSeconds = 40.0;

/// 呼吸不平稳时花累积的退回速度（秒/秒）。
const double kFlowerDecayPerSecond = 1.5;

/// 呼吸持续紊乱到花完全收拢所需秒数（约 12s）。
const double kFlowerWitherSeconds = 12.0;

/// 恢复平稳后紊乱记账的消退速度（秒/秒）——慢，花缓慢重开。
const double kFlowerWitherRecoverPerSecond = 0.6;

/// 星花定长池上限（满了最旧的花化光尘谢幕）。
const int kFlowerPoolMax = 12;

/// 花瓣张合/亮度的量化步进。
const double kFlowerVisualStep = 0.02;

double _smooth(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

double _quantize(double v) => (v * 50).round() / 50.0;

/// 单帧推进"花开累积"（纯函数，状态在调用方）。
///
/// 平稳呼吸 → 累积；不平稳 → 按 [kFlowerDecayPerSecond] 退回。
/// 结果恒夹在 0..[kFlowerBloomSeconds]。
double flowerBloomDwellNext({
  required double dwellSeconds,
  required double dt,
  required bool breathSteady,
}) {
  if (breathSteady) {
    return (dwellSeconds + dt).clamp(0.0, kFlowerBloomSeconds);
  }
  return (dwellSeconds - kFlowerDecayPerSecond * dt)
      .clamp(0.0, kFlowerBloomSeconds);
}

/// 花开进度映射（纯函数）：累积秒数 → 0..1。
///
/// [breathSteadiness] 0..1 平稳度（应为低通后的连续值，绝不瞬跳），
/// 失稳时对进度软压低（下限 0.55，绝不瞬跳），与累积退回叠加。
double flowerBloomProgress({
  required double steadySecondsAccum,
  required double breathSteadiness,
}) {
  final p =
      _smooth((steadySecondsAccum / kFlowerBloomSeconds).clamp(0.0, 1.0));
  final s = breathSteadiness.clamp(0.0, 1.0);
  return p * (0.55 + 0.45 * s);
}

/// 单帧推进"紊乱记账"（纯函数，状态在调用方）。
///
/// 呼吸紊乱 → 累积；平稳 → 按 [kFlowerWitherRecoverPerSecond] 缓慢
/// 消退（花缓慢重开）；介于两者之间 → 保持。结果恒夹在
/// 0..[kFlowerWitherSeconds]。
double flowerChaosNext({
  required double chaoticSeconds,
  required double dt,
  required bool chaotic,
  required bool breathSteady,
}) {
  if (chaotic) {
    return (chaoticSeconds + dt).clamp(0.0, kFlowerWitherSeconds);
  }
  if (breathSteady) {
    return (chaoticSeconds - kFlowerWitherRecoverPerSecond * dt)
        .clamp(0.0, kFlowerWitherSeconds);
  }
  return chaoticSeconds.clamp(0.0, kFlowerWitherSeconds);
}

/// 花谢进度映射（纯函数）：紊乱秒数 → 0..1 平滑曲线。
///
/// 0 恒 0（未紊乱）；[kFlowerWitherSeconds] 及以上恒 1（完全收拢）；
/// 中段 smoothstep——花谢是缓缓的，不是瞬间的。
double flowerWitherProgress({required double chaoticSeconds}) {
  return _smooth((chaoticSeconds / kFlowerWitherSeconds).clamp(0.0, 1.0));
}

/// 花的视觉映射（纯函数）：花瓣张合与亮度 0..1。
///
/// 张合 = 花开进度 ×（1 − 花谢）×（1 − 夜色闭合）；亮度与张合同源
/// 但稍亮（花再暗也留一点芯光——变暗但不消失）。输出按 0.02 步进
/// 量化（渲染端直接用作 alpha / 缩放，符合量化纪律）。
(double open, double glow) flowerVisual(
  double bloom,
  double wither, {
  double night = 0,
}) {
  final b = bloom.clamp(0.0, 1.0);
  final w = wither.clamp(0.0, 1.0);
  final n = night.clamp(0.0, 1.0);
  final open = (b * (1 - w) * (1 - n)).clamp(0.0, 1.0);
  // 芯光：再收拢也留 0.06 的底，"变暗但不消失"。
  final glow = (0.06 + 0.94 * open).clamp(0.0, 1.0);
  return (_quantize(open), _quantize(glow));
}

/// 花池 FIFO 槽位（纯函数）：第 [spawnCounter] 朵花落在哪个槽。
///
/// 定长池 [kFlowerPoolMax] 个槽，计数器循环取模——每次落新花占用
/// 下一个槽，覆盖的正是最旧的一朵（FIFO：满了最旧的化光尘谢幕）。
int flowerPoolNextIndex(int spawnCounter) {
  return spawnCounter % kFlowerPoolMax;
}

/// 花瓣数（纯函数）：确定性 seed → 5..7。
int flowerPetalCount(int seed) => 5 + ((seed * 2654435761) >>> 29) % 3;

/// 花色选择（纯函数）：seed → CYBER-ZEN 冷色系（青/淡紫/月白）索引。
int flowerColorIndex(int seed) => ((seed * 2654435761) >>> 27) % 3;

/// 花随呼吸相位的轻微张合系数（纯函数）：0.9..1.0，绝不瞬跳。
double flowerBreathSway(double breathPhase) {
  final t = breathPhase.clamp(0.0, 1.0);
  return 0.9 + 0.1 * (0.5 - 0.5 * math.cos(t * math.pi * 2));
}

// ---- 星花映境（第 56 轮）：花随心境区域而异 ----
//
// 花记得它出生的地方：种花瞬间按光灵当时所处的心境取一组
// 确定性调色/瓣形微调，之后花不再随光灵移动换色——出生地
// 写进花本身。全部低饱和 CYBER-ZEN 冷色/雾色，绝不刺眼。

/// 花的心境（六区域）：四个深度带区域 + 静之径（径上）+ 惘（惑星近旁）。
enum FlowerMood {
  insomniaSea, // 失眠之海
  anxietyAbyss, // 焦虑之渊
  wearyHeath, // 疲惫荒原
  mistWood, // 纷心雾林
  stillPath, // 静之径
  perplex, // 惘（惑星近旁）
}

/// 一组花的调色（不可变小结构）：花瓣色、花心色、瓣形微调。
///
/// [petalAdjust] 加到基础花瓣数（5..7）上再夹到 4..8——不同心境
/// 的花在瓣形上有极轻的差异（渊更深瓣更多、荒原疏朗瓣更少）。
class FlowerPalette {
  const FlowerPalette(this.petal, this.core, this.petalAdjust);

  final Color petal;
  final Color core;
  final int petalAdjust;
}

/// 六心境的确定性调色表（索引与 [FlowerMood] 顺序一致）。
const List<FlowerPalette> kFlowerPalettes = [
  // 失眠之海：月白蓝（海的底色稍柔）。
  FlowerPalette(Color(0xFF9fd8e8), Color(0xFFe6f5f9), 0),
  // 焦虑之渊：深青（压暗、收拢的冷）。
  FlowerPalette(Color(0xFF5f8fa8), Color(0xFFa9c8d6), 1),
  // 疲惫荒原：暖沙金（旷野的余温，仍然低饱和）。
  FlowerPalette(Color(0xFFd8c098), Color(0xFFefe4c8), -1),
  // 纷心雾林：灰青绿（雾林自身的色调）。
  FlowerPalette(Color(0xFF8fc4b0), Color(0xFFd2e8de), 0),
  // 静之径：淡金白（旧迹的雪上微光）。
  FlowerPalette(Color(0xFFddd6c2), Color(0xFFf2eee0), -1),
  // 惘：灰紫（惑星的雾紫，温柔而不艳）。
  FlowerPalette(Color(0xFF9b8fb8), Color(0xFFd0c9e2), 1),
];

/// 心境调色（纯函数）：确定性，六区域互不相同。
FlowerPalette flowerPaletteFor(FlowerMood mood) {
  return kFlowerPalettes[mood.index.clamp(0, kFlowerPalettes.length - 1)];
}

/// 同区微差（纯函数，确定性 seed）：同一心境里开的花用同色系，
/// 但亮度/相位有极轻的差别，避免整齐划一。
///
/// 返回 (brighten, phase)：brighten 0.84..1.0（向花心色微调的系数），
/// phase 0..2π（旋转相位偏移）。
(double brighten, double phase) flowerKinVariance(int seed) {
  final h = (seed * 2654435761) >>> 0;
  final brighten = 0.84 + 0.16 * ((h >>> 24) & 0xFF) / 255.0;
  final phase = ((h >>> 8) & 0xFFFF) / 65536.0 * math.pi * 2;
  return (brighten, phase);
}
