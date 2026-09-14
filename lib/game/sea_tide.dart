import 'dart:math' as math;

/// 星潮（第 60 轮）：失眠之海的呼吸涟漪——纯函数层。
///
/// 六区域中失眠之海至今只有静态星图；星潮是海专属的环境层：
/// 缓行的涟漪相位场铺在海面上，波峰极淡地亮起（峰值 alpha 0.07 封顶、
/// 0.02 量化）。呼吸平稳时波纹更舒展（幅度微增但封顶不变），呼吸紊乱
/// 时幅度收窄——**海不惩罚你，只是陪你安静**。
///
/// 语义写死：星潮无声音、无碎片、无文案、不参与任何经济/进度系统——
/// 它纯粹是海在呼吸（防后续轮误加经济系统）。
///
/// 全部函数为纯函数、无类型依赖（不 import 游戏类型），便于测试。

/// 波峰亮度的硬封顶（克制原则）。
const double kSeaTidePeakAlpha = 0.07;

/// 波峰亮度的量化步长。
const double kSeaTideAlphaStep = 0.02;

/// 波峰颜色：与失眠之海同族的柔青（渲染层使用）。
const int kSeaTideTintValue = 0xFF67e8f9;

/// 涟漪摇曳的量化步长（px）。
const double kSeaTideSwayStep = 0.5;

/// 涟漪最大摇曳幅度（px，1~2px 量级）。
const double kSeaTideSwayMaxPx = 1.5;

/// 世界环面周期（与 JingjingGame.worldPeriod 对齐的纯数值副本，
/// 供波向量周期性推导与测试使用）。
const double kSeaTideWorldW = 2400;
const double kSeaTideWorldH = 1800;

/// 三组涟漪成分的波向量（i/x 周期数，j/y 周期数）与周期（秒）。
///
/// 以海区几何为基础：世界是 2400x1800 的环绕环面，波向量取
/// (i/W, j/H)（i、j 为整数周期数），保证相位场在环面接缝两侧
/// 天然连续——涟漪随海的几何无缝环绕，不需要任何特判。
/// 波长 = 1/√((i/W)² + (j/H)²)，三组均落在 260~420px；
/// 周期取 12 / 13 / 14 秒（9~14s 慢行；偏慢取值保证相邻 100ms
/// 采样 |Δ| < 0.05 的连续性）。
/// 参数在编译期固定（seed 写死），完全确定性。
const ({
  int i,
  int j,
  double periodSec,
}) _kWaveA = (i: 8, j: 0, periodSec: 12.0); // λ=300px，东西向长涌
const ({
  int i,
  int j,
  double periodSec,
}) _kWaveB = (i: 6, j: 4, periodSec: 13.0); // λ≈299px，东南斜行
const ({
  int i,
  int j,
  double periodSec,
}) _kWaveC = (i: 7, j: -3, periodSec: 14.0); // λ≈298px，东北斜行

/// 三组涟漪成分（公开只读副本，供测试校验波长/周期区间）。
const List<({int i, int j, double periodSec})> kSeaTideWaves = [
  _kWaveA,
  _kWaveB,
  _kWaveC,
];

/// 波长（px），供测试校验落在 260~420 区间。
double seaTideWavelength(({int i, int j, double periodSec}) w) {
  final kx = w.i / kSeaTideWorldW;
  final ky = w.j / kSeaTideWorldH;
  return 1.0 / math.sqrt(kx * kx + ky * ky);
}

double _sin2pi(double x) => math.sin(2 * math.pi * x);

/// 星潮涟漪相位场：世界坐标 (x, y) 与相位 phaseMs（毫秒）→ 场强 -1..1。
///
/// 三组不同波长/方向/周期的正弦叠加（各占 1/3，天然落在 -1..1），
/// 以海区环面几何为基础（波向量按世界周期取整周期数，接缝连续），
/// 参数确定性写死（seed 固定），纯函数无类型依赖。
double seaTideWave(double x, double y, double phaseMs) {
  final tSec = phaseMs / 1000.0;
  final a = _sin2pi(
    _kWaveA.i * x / kSeaTideWorldW +
        _kWaveA.j * y / kSeaTideWorldH -
        tSec / _kWaveA.periodSec,
  );
  final b = _sin2pi(
    _kWaveB.i * x / kSeaTideWorldW +
        _kWaveB.j * y / kSeaTideWorldH -
        tSec / _kWaveB.periodSec,
  );
  final c = _sin2pi(
    _kWaveC.i * x / kSeaTideWorldW +
        _kWaveC.j * y / kSeaTideWorldH -
        tSec / _kWaveC.periodSec,
  );
  return (a + b + c) / 3.0;
}

/// 星潮视觉映射：场强 field（-1..1）与呼吸平稳度 breathSteadiness
/// （0..1，低通后的连续值）→ 波峰亮度 alpha（0..0.07 封顶，0.02 量化）。
///
/// 呼吸平稳（→1）时波纹更舒展：幅度系数升至 1.0；紊乱（→0）时收窄
/// 至 0.8——但封顶 [kSeaTidePeakAlpha] 恒不变：海不惩罚你，只是陪你
/// 安静。
double seaTideVisual(double field, double breathSteadiness) {
  final amp = 0.8 + 0.2 * breathSteadiness.clamp(0.0, 1.0);
  var a = field.abs() * amp * kSeaTidePeakAlpha;
  if (a > kSeaTidePeakAlpha) a = kSeaTidePeakAlpha;
  return seaTideQuantize(a);
}

/// 星潮摇曳：场强 field（-1..1）→ 波纹线上该点的纵向微摇（px）。
///
/// 幅度 1~2px 量级（±[kSeaTideSwayMaxPx]），按 [kSeaTideSwayStep]
/// 量化；纯函数，供波纹线与海区星花的极微摇曳复用。
double seaTideSway(double field) {
  final f = field.clamp(-1.0, 1.0);
  return (f * kSeaTideSwayMaxPx / kSeaTideSwayStep).roundToDouble() *
      kSeaTideSwayStep;
}

/// 0.02 步进量化（向下取整；1e-9 容差防浮点误差掉步，
/// 峰值 0.07 经量化后有效上限为 0.06——恰在封顶之内）。
double seaTideQuantize(double v) {
  if (v <= 0) return 0;
  return ((v + 1e-9) / kSeaTideAlphaStep).floorToDouble() *
      kSeaTideAlphaStep;
}
