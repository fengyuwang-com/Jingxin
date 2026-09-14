import 'dart:math' as math;

/// 萤迹（第 61 轮）：纷心雾林的呼吸萤火——纯函数层。
///
/// 六区域中雾林有自己的雾与守林者，但夜里没有一盏"活着的光"。萤迹
/// 是雾林专属的环境层：极少数萤火在林间近乎凝滞地缓游，随呼吸般
/// 6~9s 的周期明灭。呼吸平稳时它们明灭更同步，紊乱时各自散乱——
/// **森林陪你整理呼吸，但不催促**。
///
/// 语义写死：萤迹无声音、无碎片、无文案、不参与任何经济/进度系统——
/// 它们不是收集物、不做引导、不给任何奖励，纯粹是林间的微光（防
/// 后续轮误加经济/收集系统）。
///
/// 萤火对玩家"若即若离"：玩家近旁且呼吸平稳时，最近的一只缓向光灵
/// 漂近一点（[fireflyApproach]，距离 <60px 即停）；玩家离开后缓慢
/// 漂回原轨迹（漂回由演出层对偏移做缓释实现）。**不跟随**——它只是
/// 被平静吸引了一瞬，随即回到自己的旅程。
///
/// 全部函数为纯函数、无类型依赖（不 import 游戏类型），便于测试。

/// 萤火亮度的硬封顶（克制原则，与星潮同量级略高半档）。
const double kFireflyPeakAlpha = 0.09;

/// 萤火亮度的量化步长。
const double kFireflyAlphaStep = 0.02;

/// 萤火颜色：雾林同族的暖萤绿（渲染层使用）。
const int kFireflyTintValue = 0xFFc9e37f;

/// 世界环面周期（与 JingjingGame.worldPeriod 对齐的纯数值副本）。
const double kFireflyWorldW = 2400;
const double kFireflyWorldH = 1800;

/// 萤火被吸引时向光灵漂近的速度上限（px/s，2~3px 量级）。
const double kFireflyApproachMaxSpeed = 3.0;

/// 萤火与光灵的停驻距离（px）：近于此即不再靠近——若即若离。
const double kFireflyStopDistance = 60.0;

/// Knuth 乘法散列（黄金比例常数），确定性参数推导。
double _hash01(int salt) {
  var h = (salt + 1) * 2654435761;
  h &= 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  return h / 4294967296.0;
}

double _fract(double v) => v - v.floorToDouble();

/// 一只萤火在时刻 [tSec] 的确定性状态。
///
/// [x]/[y] 已 wrap 进 0..worldW/H（环面坐标）；[vx]/[vy] 是漂移速度
/// （px/s，极慢 0.8~2.4——肉眼近凝滞，供帧内线性外推）；[phase] 是
/// 亮度相位 0..1（呼吸式的明灭周期，每只相位错开）；[glowPeriodSec]
/// 是该只的明灭周期（6~9s，供帧内相位外推）。
typedef FireflyState = ({
  double x,
  double y,
  double vx,
  double vy,
  double phase,
  double glowPeriodSec,
});

/// 第 [index] 只萤火在 [tSec]（秒）的确定性游走轨迹。
///
/// 慢速直线漂移 + 小幅正弦摆动（摆幅 ≤2px、摆周期 ≥5s），全部参数
/// 由 Knuth 散列(index) 确定，完全确定性；位置按世界环面 wrap，
/// 天然支持 3x3 环绕镜像与跨缝游走。
FireflyState fireflyGleamAt(
  double tSec,
  int index,
  double worldW,
  double worldH,
) {
  final baseX = _hash01(index * 8 + 0) * worldW;
  final baseY = _hash01(index * 8 + 1) * worldH;
  final angle = _hash01(index * 8 + 2) * 2 * math.pi;
  final speed = 0.8 + _hash01(index * 8 + 3) * 1.6; // 0.8~2.4 px/s
  final swayAmp = 0.8 + _hash01(index * 8 + 4) * 1.2; // 0.8~2.0 px
  final swayPeriod = 5.0 + _hash01(index * 8 + 5) * 4.0; // 5~9 s
  final glowPeriod = 6.0 + _hash01(index * 8 + 6) * 3.0; // 6~9 s
  final phase0 = _hash01(index * 8 + 7);

  final sw = math.sin(2 * math.pi * tSec / swayPeriod + phase0 * 2 * math.pi);
  final x = _fract((baseX + math.cos(angle) * speed * tSec + swayAmp * sw) /
          worldW) *
      worldW;
  final y = _fract((baseY + math.sin(angle) * speed * tSec + swayAmp * sw) /
          worldH) *
      worldH;
  return (
    x: x,
    y: y,
    vx: math.cos(angle) * speed,
    vy: math.sin(angle) * speed,
    phase: _fract(tSec / glowPeriod + phase0),
    glowPeriodSec: glowPeriod,
  );
}

/// 萤火视觉映射：亮度相位 phase（0..1）与呼吸平稳度 breathSteadiness
/// （0..1，低通后的连续值）→ 亮度 alpha（0..0.09 封顶，0.02 量化）。
///
/// 相位趋同系数 k = 0.12 + 0.18×平稳度：呼吸平稳（→1）时每只萤火的
/// 相位被轻拉向共同的峰值相位 0.5，明灭更同步；紊乱（→0）时各自
/// 散乱（k 回落到 0.12 的本底）。封顶 [kFireflyPeakAlpha] 恒不变：
/// 森林陪你整理呼吸，但不催促。
double fireflyVisual(double phase, double breathSteadiness) {
  final p = _fract(phase);
  final k = 0.12 + 0.18 * breathSteadiness.clamp(0.0, 1.0);
  final pulled = p + (0.5 - p) * k;
  final e = 0.5 - 0.5 * math.cos(2 * math.pi * pulled);
  var a = e * kFireflyPeakAlpha;
  if (a > kFireflyPeakAlpha) a = kFireflyPeakAlpha;
  return fireflyQuantize(a);
}

/// 萤火向光灵的若即若离漂近（纯函数）。
///
/// [cur] 是萤火当前位置，[target] 是光灵位置；仅当 [steady] > 0 时以
/// 2~3px/s（[kFireflyApproachMaxSpeed] 封顶）的速度向光灵漂近，距离
/// < [kFireflyStopDistance] 即停（不再靠近——若即若离，不跟随）；
/// steady ≤ 0 时原地不动（漂回原轨迹由演出层对偏移做缓释）。
({double x, double y}) fireflyApproach(
  ({double x, double y}) cur,
  ({double x, double y}) target,
  double steady,
  double dtMs,
) {
  if (steady <= 0 || dtMs <= 0) return cur;
  final dx = target.x - cur.x;
  final dy = target.y - cur.y;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist <= kFireflyStopDistance) return cur;
  final speed = (2.0 + 1.0 * steady.clamp(0.0, 1.0))
      .clamp(0.0, kFireflyApproachMaxSpeed);
  final step = math.min(speed * dtMs / 1000.0, dist - kFireflyStopDistance);
  final t = step / dist;
  return (x: cur.x + dx * t, y: cur.y + dy * t);
}

/// 0.02 步进量化（向下取整；1e-9 容差防浮点误差掉步，
/// 峰值 0.09 经量化后有效上限为 0.08——恰在封顶之内）。
double fireflyQuantize(double v) {
  if (v <= 0) return 0;
  return ((v + 1e-9) / kFireflyAlphaStep).floorToDouble() *
      kFireflyAlphaStep;
}
