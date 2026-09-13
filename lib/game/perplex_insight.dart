/// 惑星「通达」（第 52 轮）——迷失处的第二次机遇。
///
/// 理念：惑星是"困住与迷失"的心境化身。光灵停在它近旁、保持平稳
/// 呼吸足够久（约 [kInsightFillSeconds] 秒），不必攒满循环数，也能
/// 短暂"解开通达"——惑星提前化作一圈灰紫光尘散去，落下一枚
/// 「惑语」碎片。迷失本身，也是路。
///
/// 全部纯函数；驻留秒数等状态由调用方（PerplexPlanet）持有。
/// 每颗惑星生命周期至多一次通达——由状态机 `triggerInsight` 的
/// drifting-only + 一次性闸门天然保证（有断言测试）。

/// 「惑语」碎片等常量与映射见下。
library;

import 'dart:math' as math;

/// 注满通达所需的有效驻留秒数（约 35s，平稳呼吸近旁）。
const double kInsightFillSeconds = 35.0;

/// 呼吸乱时的通达流失速度（dwell 秒/秒）——快。
const double kInsightBrokenDecayPerSecond = 1.2;

/// 平稳离开时的通达流失速度（dwell 秒/秒）——慢，像雾慢慢合拢。
const double kInsightLeftDecayPerSecond = 0.35;

/// 通达触发阈值：progress 注满到 ≥ 此值即触发一次。
const double kInsightTriggerThreshold = 0.95;

/// 轮廓微亮的起步阈值：progress 越过 0.5 惑星轮廓开始微亮。
const double kInsightGlowThreshold = 0.5;

/// 通达光尘消散时长（秒）：盖在 dissolving 星花之上，随化解收散。
const double kInsightDustSeconds = 2.4;

/// 「惑语」碎片的收录区域名（自由字符串，走既有拾忆/merge 通道）。
const String perplexInsightRegion = '惑';

/// 通达短语池（主题：迷失也是路）。
const List<String> kInsightPhrases = [
  '迷路的地方，也开着花。',
  '绕远的那条路，也通向这里。',
  '迷失不是错过，是另一种抵达。',
  '雾里走的每一步，都算数。',
  '看不清方向时，就先看清呼吸。',
  '惑本身，也是路标。',
  '没有白走的夜。',
];

double _smooth(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

/// 单帧推进通达的有效驻留秒数（纯函数，状态在调用方）。
///
/// 近旁且平稳 → 累积；平稳地离开 → 按 [kInsightLeftDecayPerSecond]
/// 慢退；呼吸乱 → 按 [kInsightBrokenDecayPerSecond] 快退。
/// 结果恒夹在 0..[kInsightFillSeconds]。
double perplexInsightDwellNext({
  required double dwellSeconds,
  required double dt,
  required bool near,
  required bool breathSteady,
}) {
  if (near && breathSteady) {
    return (dwellSeconds + dt).clamp(0.0, kInsightFillSeconds);
  }
  final rate =
      breathSteady ? kInsightLeftDecayPerSecond : kInsightBrokenDecayPerSecond;
  return (dwellSeconds - rate * dt).clamp(0.0, kInsightFillSeconds);
}

/// 通达进度映射（纯函数）。
///
/// [dwellSeconds] 为"有效驻留秒数"；[breathSteadiness] 0..1 为低通后
/// 的连续平稳度（绝不瞬跳），失稳时对进度软压低——与 dwell 快速
/// 流失叠加，保证"呼吸乱 10s 内进度掉一半"。
double perplexInsightProgress({
  required double dwellSeconds,
  required double breathSteadiness,
}) {
  final p = _smooth((dwellSeconds / kInsightFillSeconds).clamp(0.0, 1.0));
  final s = breathSteadiness.clamp(0.0, 1.0);
  return p * (0.55 + 0.45 * s);
}

/// 轮廓微亮映射（纯函数）：progress → 0..1，低于 [kInsightGlowThreshold]
/// 恒 0，之后随注满平滑变亮，输出按 0.04 步进量化（渲染端直接用作
/// alpha 分量，符合量化纪律）。
double perplexInsightGlow(double progress) {
  if (progress <= kInsightGlowThreshold) return 0;
  final t =
      ((progress - kInsightGlowThreshold) / (1 - kInsightGlowThreshold))
          .clamp(0.0, 1.0);
  final s = _smooth(t);
  return (s * 25).round() / 25.0; // 0.04 步进量化
}

/// 通达光尘包络（纯函数）：[kInsightDustSeconds] 内 sin 起落，两端归零。
double perplexInsightDustEnvelope(double t) {
  if (t <= 0 || t >= kInsightDustSeconds) return 0;
  return math.sin(math.pi * t / kInsightDustSeconds);
}

/// 通达短语选取（纯函数）：从固定小池轮换；距上次浮出不足 15s 时
/// 绝不重复上句（换邻位即可——每颗惑星至多一次通达，池远大于此）。
/// [roll] 为任意非负整数（调用方用 RNG 提供）。
int perplexInsightPhraseIndex(int roll, int lastIndex, double sinceLastSeconds) {
  final n = kInsightPhrases.length;
  var i = roll % n;
  if (sinceLastSeconds < 15.0 && i == lastIndex) {
    i = (i + 1) % n;
  }
  return i;
}
