import 'dart:math' as math;

/// 渊光（第 63 轮）：焦虑之渊的缓升微光——纯函数层。
///
/// 六区域中焦虑之渊一直只有乱星与渊底心跳辉光；渊光是渊专属的环境层
/// （收官）：几簇微光自渊底极缓上浮（3~6px/s，比萤火快一线、比风痕慢
/// 许多——渊里的光只是不想沉太久），亮度随呼吸般的 8~12s 周期明灭，
/// 每簇相位错开。呼吸越平稳，光点排布越舒展（半径微增）；紊乱时收拢
/// ——**渊不吓你，只是有几缕光愿意先亮一点**。
///
/// 语义写死：渊光无声音、无碎片、无文案、不参与任何经济/进度系统——
/// 它纯粹是渊在呼吸（防后续轮误加经济/收集系统）。
///
/// 全部函数为纯函数、无类型依赖（不 import 游戏类型），便于测试。

/// 渊光亮度的硬封顶（第 64 轮随同化抬升上调一档：0.08→0.10，仍落在
/// 0.02 量化网格上——克制原则不变，只是渊底心跳多允许一线呼应）。
const double kAbyssGlowPeakAlpha = 0.10;

/// 渊光亮度的量化步长。
const double kAbyssGlowAlphaStep = 0.02;

/// 渊光颜色：渊区深青同系的微亮（渲染层使用）。
const int kAbyssGlowTintValue = 0xFF53d6c6;

/// 世界环面周期（与 JingjingGame.worldPeriod 对齐的纯数值副本）。
const double kAbyssGlowWorldW = 2400;
const double kAbyssGlowWorldH = 1800;

/// 微光上浮速度区间（px/s，3~6，方向向上：vy ∈ [-6, -3]）。
const double kAbyssGlowRiseMin = 3.0;
const double kAbyssGlowRiseMax = 6.0;

/// 上浮途中横向轻摆的速度上限（px/s，摆幅 3~6px、周期 10~16s 推导
/// 所得的包络，供测试与帧内外推误差界定）。
const double kAbyssGlowSwaySpeedMax = 4.0;

/// 明灭周期区间（秒，8~12——呼吸量级）。
const double kAbyssGlowPhaseMinSec = 8.0;
const double kAbyssGlowPhaseMaxSec = 12.0;

/// 簇内光点的基础半径区间（px）。
const double kAbyssGlowPointRadMin = 8.0;
const double kAbyssGlowPointRadMax = 22.0;

/// 长叹息触发所需的"渊内平稳停留"秒数（约 30s）。
const double kAbyssGlowSighDwellSec = 30.0;

/// 出渊/紊乱时 dwell 的退回速率（秒/秒）。
const double kAbyssGlowDwellDecayPerSecond = 0.5;

/// 一次长叹息的缓成时长（秒，60s 缓成后停住）。
const double kAbyssGlowSighEaseSec = 60.0;

/// 长叹息整簇上浮的距离（px）。
const double kAbyssGlowSighRisePx = 12.0;

/// Knuth 乘法散列（黄金比例常数），确定性参数推导。
double _hash01(int salt) {
  var h = (salt + 1) * 2654435761;
  h &= 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  return h / 4294967296.0;
}

double _fract(double v) => v - v.floorToDouble();

double _smooth(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

/// 一簇渊光在时刻 [tSec] 的确定性状态。
///
/// [x]/[y] 已 wrap 进 0..worldW/H（环面坐标，天然支持跨缝上浮与 3x3
/// 镜像）；[vx] 是轻摆的瞬时水平速度（px/s，|vx| ≤ [kAbyssGlowSwaySpeedMax]）；
/// [vy] 是上浮速度（px/s，负值向上，-6..-3）；[phase] 是明灭相位 0..1
/// （每簇由 Knuth 散列错相）；[phasePeriodSec] 是明灭周期（8~12s）。
typedef AbyssGlowState = ({
  double x,
  double y,
  double vx,
  double vy,
  double phase,
  double phasePeriodSec,
});

/// 第 [index] 簇渊光在 [tSec]（秒）的确定性簇心与相位。
///
/// 极缓自下而上漂：y 以 3~6px/s 匀速上浮（环面 wrap，浮出顶端回到渊底，
/// 周而复始）；x 叠一个确定性正弦轻摆（摆幅 3~6px、周期 10~16s），
/// [vx] 给出该摆动在 [tSec] 的瞬时导数供渲染层帧内外推。亮度 8~12s
/// 呼吸式明灭，每簇初相由 Knuth 散列错开。纯数值全部确定性。
///
/// [riseTimeSec]（第 66 轮·长夜沉底，默认 = [tSec] 即旧行为）：上浮行程
/// 的"等效时间"——渲染层传入节拍锚定的累积值（入夜后按速度乘子减速增
/// 长），只慢化 y 上浮行程；[vy] 报告该等效时刻的本征速度，供帧内外推
/// 再乘系数。明灭相位仍用 [tSec]（本增量不动相位推进）。纯函数、无状态。
AbyssGlowState abyssGlowAt(
  double tSec,
  int index,
  double worldW,
  double worldH, {
  double? riseTimeSec,
}) {
  final baseX = _hash01(index * 8 + 0) * worldW;
  final baseY = _hash01(index * 8 + 1) * worldH;
  final rise =
      kAbyssGlowRiseMin + _hash01(index * 8 + 2) * (kAbyssGlowRiseMax - kAbyssGlowRiseMin);
  final swayAmp = 3.0 + _hash01(index * 8 + 3) * 3.0; // 3~6 px
  final swayPeriod = 10.0 + _hash01(index * 8 + 4) * 6.0; // 10~16 s
  final phasePeriod =
      kAbyssGlowPhaseMinSec + _hash01(index * 8 + 5) * (kAbyssGlowPhaseMaxSec - kAbyssGlowPhaseMinSec); // 8~12 s
  final phase0 = _hash01(index * 8 + 6);

  final w = 2 * math.pi / swayPeriod;
  final swayArg = w * tSec + phase0 * 2 * math.pi;
  final riseT = riseTimeSec ?? tSec;
  final x = _fract((baseX + swayAmp * math.sin(swayArg)) / worldW) * worldW;
  final y = _fract((baseY - rise * riseT) / worldH) * worldH;
  return (
    x: x,
    y: y,
    vx: swayAmp * w * math.cos(swayArg),
    vy: -rise,
    phase: _fract(tSec / phasePeriod + phase0),
    phasePeriodSec: phasePeriod,
  );
}

/// 渊光视觉映射：呼吸平稳度 breathSteadiness（0..1，低通后的连续值）
/// → (alpha, radiusScale)。
///
/// 呼吸平稳（→1）时簇内光点排布更舒展（半径系数升至 1.0）、亮度峰值
/// 升至封顶 [kAbyssGlowPeakAlpha]；紊乱（→0）时光点自己收拢（0.85）、
/// 变淡（0.04）——渊不催你。alpha 恒 ≤ 封顶，封顶不随平稳度变化；
/// 两端 0.04/0.08 均恰在 0.02 量化网格上。
({double alpha, double radiusScale}) abyssGlowVisual(double breathSteadiness) {
  final s = breathSteadiness.clamp(0.0, 1.0);
  var a = 0.04 + 0.04 * s;
  if (a > kAbyssGlowPeakAlpha) a = kAbyssGlowPeakAlpha;
  return (
    alpha: abyssGlowQuantize(a),
    radiusScale: 0.85 + 0.15 * s,
  );
}

/// 同化抬升的最大档（第 64 轮）：渊区乱星被完全同化时，渊光在原有
/// alpha 基础上最多加亮一档（0.02）——极小的呼应，不是新进度条。
const double kAbyssGlowAssimLiftMax = 0.02;

/// 判定"渊区被完全同化"、可重置长叹息闸门的同化度阈值。
const double kAbyssGlowFullAssimilation = 0.95;

/// 渊底心跳与缓升光的呼应（第 64 轮）：渊区乱星被同化的程度
/// assimilation（0..1，即 AnxietyAbyss.calm）→ 额外亮度抬升。
///
/// 0→0、1→[kAbyssGlowAssimLiftMax]（恰为一档量化步进），smoothstep
/// 单调过渡；渲染层把 lift 叠进簇亮度后再走 [abyssGlowQuantize]——
/// 只在原有 alpha 基础上加档，紊乱收拢语义不变，总封顶相应提到 0.10
/// （仍落在 0.02 网格上）。语义写死：这不是新进度条、不加任何数字/
/// UI 提示、不参与经济系统——念头归于一致时，渊底的微光愿意多亮一线。
double abyssGlowAssimilationLift(double assimilation) {
  return kAbyssGlowAssimLiftMax * _smooth(assimilation.clamp(0.0, 1.0));
}

/// 完全同化时的长叹息闸门重置判据（纯函数）：上一拍已"见过完全同化"
/// （[wasFullyAssimilated]）或本拍同化度 ≥ [kAbyssGlowFullAssimilation]
/// → 返回 true（调用方据此清一次各簇 done 闸门，内存态、让老玩家回渊
/// 还能再看一次松气）。持续停留在完全同化态时保持 true，由调用方的
/// "全未叹则跳过"保证只重置一次；同化度退去后返回 false，重新武装。
bool abyssGlowSighResetGate({
  required bool wasFullyAssimilated,
  required double assimilation,
}) {
  if (assimilation >= kAbyssGlowFullAssimilation) return true;
  return wasFullyAssimilated && assimilation < kAbyssGlowFullAssimilation;
}

/// 簇 [clusterIndex] 内第 [pointIndex] 枚光点相对簇心的确定性排布：
/// 方向 (dx, dy) 为单位向量 × 基础半径（[kAbyssGlowPointRadMin]~
/// [kAbyssGlowPointRadMax] px）。渲染层乘 [abyssGlowVisual] 的
/// radiusScale 得到实际偏移——平稳舒展、紊乱收拢。纯函数、构造期可
/// 一次性预算好，运行期零分配。
({double dx, double dy, double radius}) abyssGlowPointOffset(
  int clusterIndex,
  int pointIndex,
) {
  final ang = _hash01(clusterIndex * 16 + pointIndex * 3 + 100) * 2 * math.pi;
  final rad = kAbyssGlowPointRadMin +
      _hash01(clusterIndex * 16 + pointIndex * 3 + 101) *
          (kAbyssGlowPointRadMax - kAbyssGlowPointRadMin);
  return (dx: math.cos(ang) * rad, dy: math.sin(ang) * rad, radius: rad);
}

/// 渊内平稳停留的"长叹息"累积（纯函数，状态在调用方，与花开 dwell 同法）：
/// 玩家在渊区且呼吸平稳 → 累积；出渊或紊乱 → 按
/// [kAbyssGlowDwellDecayPerSecond] 退回。结果恒夹在 0..[kAbyssGlowSighDwellSec]。
double abyssGlowDwellNext({
  required double dwellSeconds,
  required double dt,
  required bool inAbyss,
  required bool breathSteady,
}) {
  if (inAbyss && breathSteady) {
    return (dwellSeconds + dt).clamp(0.0, kAbyssGlowSighDwellSec);
  }
  return (dwellSeconds - kAbyssGlowDwellDecayPerSecond * dt)
      .clamp(0.0, kAbyssGlowSighDwellSec);
}

/// 一簇的长叹息进度（0..1 缓成、done 为一次性闸门，内存态）。
typedef AbyssGlowSigh = ({double progress, bool done});

/// 推进一簇的长叹息（纯函数）：
/// - [trigger] 仅在 dwell 到点那一拍给出 true，点亮闸门；
/// - 未触发且尚未开始（progress==0 且 !done）→ 原样返回（一次性：done
///   之后永远原样返回，每簇至多一次直到长夜重置由调用方负责）；
/// - 一旦开始就以 [kAbyssGlowSighEaseSec]（60s）缓推 progress 到 1 停住
///   （单调不回退、封顶），到 1 时 done 置真。
AbyssGlowSigh abyssGlowSighNext({
  required AbyssGlowSigh state,
  required bool trigger,
  required double dtSec,
}) {
  if (state.done) return state;
  final started = trigger || state.progress > 0;
  if (!started) return state;
  final p = (state.progress + dtSec / kAbyssGlowSighEaseSec).clamp(0.0, 1.0);
  return (progress: p, done: p >= 1.0);
}

/// 长叹息的上浮偏移（px，负为向上）：缓成进度 0..1 → 0..
/// -[kAbyssGlowSighRisePx]，smoothstep 缓动，界内封顶。
double abyssGlowSighOffsetPx(double progress) {
  return -kAbyssGlowSighRisePx * _smooth(progress.clamp(0.0, 1.0));
}

// ---------------------------------------------------------------------------
// 渊息（第 65 轮）：完全同化瞬间的一次集体同步脉动
// ---------------------------------------------------------------------------

/// 一次渊息的时长（毫秒，约 2.5s——一口气的量级）。
const double kAbyssPulseDurationMs = 2500.0;

/// 渊息峰值亮度抬升（alpha 档，0.03——加在原有亮度上的一小口气，
/// 渲染层叠加后仍走 [abyssGlowQuantize] 统一量化）。量化到 0.02 网格
/// 后有效形态为"轻抬一档（0.02）再落回"；峰值窗口内总 alpha 临时可
/// 到 0.12（常态封顶 0.10 不变，脉动约 2.5s 结束后自然回落）。
const double kAbyssPulsePeakAlpha = 0.03;

/// 渊息期间明灭相位向共同相位靠拢的最大趋同系数（与呼吸平稳度里
/// 的"趋同"同一手法：只是更同步地一起呼出这口气，不是新特效开关）。
const double kAbyssPulsePhasePullMax = 0.85;

/// 渊息触发的同化度阈值（与第 64 轮 resetGate 同一判据：完全同化）。
const double kAbyssPulseTriggerCalm = kAbyssGlowFullAssimilation;

/// 渊息重新武装（滞回下限）：触发后 calm 须回落到 <0.90 才允许再脉。
const double kAbyssPulseRearmCalm = 0.90;

/// 渊息包络（纯函数）：tMs ∈ [0, kAbyssPulseDurationMs] 上的 sin 半波
/// ——两端恰落 0、峰值 [kAbyssPulsePeakAlpha]（0→升→回落，一口气的形）。
/// 界外（tMs ≤ 0 或 ≥ 时长）返回 0。结果量化到 0.02 网格（floor）：
/// 峰值段（envelope ≥ 2/3）落在 0.02 档，其余段为 0——**脉动的可见
/// 形态是"轻抬一档再落回"**，克制、无声、无奖；量化不放大原值。
double abyssPulseEnvelope(double tMs) {
  if (tMs <= 0 || tMs >= kAbyssPulseDurationMs) return 0;
  final raw =
      kAbyssPulsePeakAlpha * math.sin(math.pi * tMs / kAbyssPulseDurationMs);
  return abyssGlowQuantize(raw);
}

/// 渊息边沿触发 + 滞回防抖（纯函数，状态在调用方）：
/// - calmPrev ≥ [kAbyssPulseRearmCalm]（含已在高位的持续段）→ 永不触发
///   （首次跨到 ≥0.95 的那一拍 calmPrev 尚在 0.90 以下，可触发）；
/// - calmNow ≥ [kAbyssPulseTriggerCalm] 且 calmPrev < [kAbyssPulseRearmCalm]
///   → true（从 <0.90 跨到 ≥0.95 才 true）；
/// - 触发后 calm 须回落到 <0.90（即已满足 calmPrev < 0.90）才重新武装，
///   每次"重新武装后的再次满同化"可再脉一次，不限次。
bool abyssPulseTriggered(double calmPrev, double calmNow) {
  if (calmPrev >= kAbyssPulseRearmCalm) return false;
  return calmNow >= kAbyssPulseTriggerCalm;
}

/// 渊息期间的明灭相位趋同系数（0..[kAbyssPulsePhasePullMax]，随包络
/// 线性）：渲染层用 lerp(自身相位, 共同相位 0.5=峰, pull) 把所有簇的
/// 明灭相位瞬间拉向同一处——乱星归一，渊底一起呼出一口气。包络为 0
/// 时趋同为 0（各簇回到各自错相）。
double abyssPulsePhasePull(double envelope) {
  if (envelope <= 0) return 0;
  final e = envelope / kAbyssPulsePeakAlpha;
  return (kAbyssPulsePhasePullMax * (e > 1 ? 1 : e)).clamp(0.0, kAbyssPulsePhasePullMax);
}

/// 0.02 步进量化（向下取整；1e-9 容差防浮点误差掉步，峰值 0.08 恰
/// 是量化步长的整数倍，封顶即有效上限）。
double abyssGlowQuantize(double v) {
  if (v <= 0) return 0;
  return ((v + 1e-9) / kAbyssGlowAlphaStep).floorToDouble() *
      kAbyssGlowAlphaStep;
}
