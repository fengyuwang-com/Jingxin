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
