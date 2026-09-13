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

/// 按 [step] 步进量化（四舍五入），雾痕/脉冲 alpha 共用（第 54 轮
/// 收束整理：三处同款量化收敛为单一实现，行为不变）。
double _quantize(double v, double step) => (v / step).round() * step;

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

// ---------------------------------------------------------------------------
// 通达残影（第 53 轮）——"来过"的雾痕。
//
// 通达消散后，原位留一道极淡的灰紫雾痕，约 6 分钟缓淡至无；玩家回到
// 近旁且平稳呼吸时，雾痕轻微随呼吸起伏，并一次性掉落 1 枚普通心镜
// 碎片——"来过"值得一顾。状态全部在内存（惑星生命周期内），不持久化。
// ---------------------------------------------------------------------------

/// 雾痕淡出总时长（毫秒）：约 6 分钟，从通达瞬间起算。
const int kMistTraceFadeMs = 360000;

/// 雾痕起步 alpha（通达瞬间）。
const double kMistTraceStartAlpha = 0.14;

/// 雾痕 alpha 量化步进（渲染纪律：量化 alpha）。
const double kMistTraceAlphaStep = 0.02;

/// 雾痕随呼吸起伏的相对幅度（包络 ±1 时 alpha 变化 ±22%）。
const double kMistTraceBreathAmp = 0.22;

/// 雾痕碎片的收录区域名。
const String mistTraceRegion = '雾痕';

/// 雾痕一次性馈赠的碎片偈语（固定一句，走既有 mergeShards 幂等通道）。
const String mistTraceShardText = '雾散的地方，你来过。';

/// 雾痕 alpha 曲线（纯函数）：[elapsedMs] 自通达瞬间起算。
///
/// 起步 [kMistTraceStartAlpha]，约 [kMistTraceFadeMs]（6 分钟）内
/// 线性平滑淡至 0；输出按 [kMistTraceAlphaStep] 步进量化。负值
/// （同帧起点漂移）容错为 0 起；超时恒 0（调用方据此短路停止绘制）。
double mistTraceAlpha(num elapsedMs) {
  if (elapsedMs <= 0) return kMistTraceStartAlpha;
  final ms = elapsedMs.toDouble();
  if (ms >= kMistTraceFadeMs) return 0;
  final a = kMistTraceStartAlpha * (1 - ms / kMistTraceFadeMs);
  return _quantize(a, kMistTraceAlphaStep);
}

/// 雾痕的呼吸起伏映射（纯函数）：把呼吸包络 [breathEnvelope]（-1..1，
/// 调用方用 sin 相位提供）映到 alpha 上的轻微起伏。
///
/// 包络为 0 时恰返回 [alpha] 本身；alpha 为 0 恒 0；输出按
/// [kMistTraceAlphaStep] 步进量化，绝不越出 alpha 的 [1±amp] 带宽。
double mistTraceBreath(double alpha, double breathEnvelope) {
  if (alpha <= 0) return 0;
  final e = breathEnvelope.clamp(-1.0, 1.0);
  final v = alpha * (1 + kMistTraceBreathAmp * e);
  return _quantize(v, kMistTraceAlphaStep);
}

/// 雾痕一次性馈赠闸门（纯函数）：仅在"近旁 + 平稳呼吸 + 尚未掉过"
/// 时允许掉落——掉过之后呼吸再久也不再掉（只剩纯视觉雾痕直至消散）。
bool mistTraceGrantAllowed({
  required bool granted,
  required bool near,
  required bool breathSteady,
}) {
  return !granted && near && breathSteady;
}

// ---------------------------------------------------------------------------
// 雾痕道别（第 54 轮）——淡出末段的余光脉冲。
//
// 雾痕生命的最后一段里，以 seed 决定的某一刻极轻地亮一下——像花火
// 般一闪而过的"道别"。比雾痕本体还淡，一闪之后随雾痕继续淡去。
// ---------------------------------------------------------------------------

/// 道别窗口长度（毫秒）：雾痕生命末段的最后 45 秒。
const int kMistFarewellWindowMs = 45000;

/// 一次道别脉冲的时长（毫秒）：3.5s 的 sin 包络。
const int kMistFarewellPulseMs = 3500;

/// 道别脉冲的 alpha 峰值上限：比雾痕本体（0.14）还淡。
const double kMistFarewellPeakAlpha = 0.10;

/// 道别脉冲 alpha 叠加（纯函数）：[elapsedMs] 自通达瞬间起算，
/// [seed] 决定末段内伪随机的触发时刻（同 seed 同曲线，确定性）。
///
/// 仅在雾痕生命最后 [kMistFarewellWindowMs] 内、且距该触发时刻
/// 不足 [kMistFarewellPulseMs] 时给出一个 sin 起落包络 × 峰值上限；
/// 窗口外恒 0。输出按 [kMistTraceAlphaStep] 步进量化（峰值 0.10
/// 恰为 5 步），渲染端把返回值叠加到雾痕 alpha 上。
double mistFarewellPulse(num elapsedMs, {int seed = 0}) {
  final windowStart = kMistTraceFadeMs - kMistFarewellWindowMs;
  // seed → 0..1 的确定性伪随机分数（Knuth 乘法散列，纯整数运算）。
  final h = ((seed & 0xFFFFFFFF) * 2654435761) & 0x7FFFFFFF;
  final frac = h / 0x7FFFFFFF;
  // 触发时刻在窗口内、且整段脉冲（3.5s）完整落在窗口里。
  final pulseStart =
      windowStart + frac * (kMistFarewellWindowMs - kMistFarewellPulseMs);
  final t = elapsedMs.toDouble() - pulseStart;
  if (t <= 0 || t >= kMistFarewellPulseMs) return 0;
  final v =
      math.sin(math.pi * t / kMistFarewellPulseMs) * kMistFarewellPeakAlpha;
  return _quantize(v, kMistTraceAlphaStep);
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
