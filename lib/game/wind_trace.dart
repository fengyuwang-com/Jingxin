import 'dart:math' as math;

/// 风痕（第 62 轮）：疲惫荒原的呼吸风——纯函数层。
///
/// 六区域中疲惫荒原至今只有旷野与兽的注视；风痕是荒原专属的环境层：
/// 极长的水平缓行弧线贴着旷野走（荒原的风贴地走，不下雨不卷沙），
/// 随呼吸般的 9~14s 周期明灭。呼吸平稳时风更轻柔绵长，紊乱时风自己
/// 收短变淡——**荒原不催你，风自己慢下来**。
///
/// 语义写死：风痕无声音、无碎片、无文案、不参与任何经济/进度系统——
/// 它纯粹是荒原在呼吸（防后续轮误加经济/收集系统）。
///
/// 全部函数为纯函数、无类型依赖（不 import 游戏类型），便于测试。

/// 风痕亮度的硬封顶（克制原则，六环境层中最淡）。
const double kWindTracePeakAlpha = 0.06;

/// 风痕亮度的量化步长。
const double kWindTraceAlphaStep = 0.02;

/// 风痕颜色：疲惫荒原同族的暖沙金（渲染层使用）。
const int kWindTraceTintValue = 0xFFd8c098;

/// 世界环面周期（与 JingjingGame.worldPeriod 对齐的纯数值副本）。
const double kWindTraceWorldW = 2400;
const double kWindTraceWorldH = 1800;

/// 风的水平漂移速度区间（px/s，12~20——肉眼可见的缓行，远快于萤火
/// 的凝滞游走：荒原的风一直在走，只是不急）。
const double kWindTraceSpeedMin = 12.0;
const double kWindTraceSpeedMax = 20.0;

/// 风的纵向倾斜速度上限（px/s）：贴地走，几乎水平。
const double kWindTraceRiseMax = 2.4;

/// 风场（[windTraceField]）的波长周期（秒）：13s，保证相邻 100ms
/// 采样 |Δ| < 0.05 的连续性。
const double kWindTraceFieldPeriodSec = 13.0;

/// 风场沿世界 x 的整数周期数（λ = 2400/4 = 600px，环面接缝连续）。
const int kWindTraceFieldCycles = 4;

/// 星花被风拂过的极微倾斜量化步长（px）。
const double kWindTraceSwayStep = 0.5;

/// 星花被风拂过的极微倾斜幅度（px，1~2px 量级）。
const double kWindTraceSwayMaxPx = 1.5;

/// 风痕的基准长度（px，平稳时）；紊乱时按长度系数收短。
const double kWindTraceLengthPx = 900.0;

/// Knuth 乘法散列（黄金比例常数），确定性参数推导。
double _hash01(int salt) {
  var h = (salt + 1) * 2654435761;
  h &= 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  h = (h * 2654435761) & 0xFFFFFFFF;
  return h / 4294967296.0;
}

double _fract(double v) => v - v.floorToDouble();

/// 一道风痕在时刻 [tSec] 的确定性状态。
///
/// [x]/[y] 已 wrap 进 0..worldW/H（环面坐标，天然支持跨缝游走与 3x3
/// 镜像）；[vx] 是水平漂移速度（px/s，12~20）；[vy] 是纵向漂移速度
/// （px/s，|vy| ≤ 2.4——风贴地走）；[phase] 是明灭相位 0..1（每道
/// 相位由 Knuth 散错开）；[phasePeriodSec] 是明灭周期（9~14s）。
typedef WindTraceState = ({
  double x,
  double y,
  double vx,
  double vy,
  double phase,
  double phasePeriodSec,
});

/// 第 [index] 道风痕在 [tSec]（秒）的确定性基准点与相位。
///
/// 极长的水平缓行弧线：基准点以 12~20px/s 贴地缓行（几乎水平，纵向
/// 漂移 ≤2.4px/s），y 叠加确定性正弦摆动（摆幅 3~7px、周期 8~14s）；
/// 全部参数由 Knuth 散列(index) 确定，完全确定性；位置按世界环面
/// wrap。风痕本身极长（渲染层按 [kWindTraceLengthPx] × 长度系数画），
/// 这里只给线段的基准点与相位。
WindTraceState windTraceLine(
  double tSec,
  int index,
  double worldW,
  double worldH,
) {
  final baseX = _hash01(index * 8 + 0) * worldW;
  final baseY = _hash01(index * 8 + 1) * worldH;
  final speed =
      kWindTraceSpeedMin + _hash01(index * 8 + 2) * (kWindTraceSpeedMax - kWindTraceSpeedMin);
  final rise = (_hash01(index * 8 + 3) - 0.5) * 2 * kWindTraceRiseMax;
  final swayAmp = 3.0 + _hash01(index * 8 + 4) * 4.0; // 3~7 px
  final swayPeriod = 8.0 + _hash01(index * 8 + 5) * 6.0; // 8~14 s
  final phasePeriod = 9.0 + _hash01(index * 8 + 6) * 5.0; // 9~14 s
  final phase0 = _hash01(index * 8 + 7);

  final sw = math.sin(2 * math.pi * tSec / swayPeriod + phase0 * 2 * math.pi);
  final x = _fract((baseX + speed * tSec) / worldW) * worldW;
  final y = _fract((baseY + rise * tSec + swayAmp * sw) / worldH) * worldH;
  return (
    x: x,
    y: y,
    vx: speed,
    vy: rise,
    phase: _fract(tSec / phasePeriod + phase0),
    phasePeriodSec: phasePeriod,
  );
}

/// 风的相位场：世界坐标 [x] 与相位 [phaseMs]（毫秒）→ 场强 -1..1。
///
/// 单组波向量（沿 x 取整数周期数 [kWindTraceFieldCycles]，周期
/// [kWindTraceFieldPeriodSec]），在环面接缝两侧天然连续——风随荒原
/// 的几何无缝环绕，不需要任何特判。纯函数无类型依赖。
double windTraceField(double x, double phaseMs) {
  final tSec = phaseMs / 1000.0;
  return math.sin(
    2 * math.pi * (kWindTraceFieldCycles * x / kWindTraceWorldW -
        tSec / kWindTraceFieldPeriodSec),
  );
}

/// 风痕视觉映射：呼吸平稳度 breathSteadiness（0..1，低通后的连续值）
/// → (alpha, lengthScale)。
///
/// 呼吸平稳（→1）时风更轻柔绵长：alpha 峰值升至封顶
/// [kWindTracePeakAlpha]（0.02 量化）、长度系数 1.0；紊乱（→0）时
/// 风自己收短变淡（alpha 0.04、长度系数 0.6）——荒原不催你。alpha
/// 恒 ≤ 封顶，封顶不随平稳度变化；两端 0.04/0.06 均恰在量化网格上。
({double alpha, double lengthScale}) windTraceVisual(double breathSteadiness) {
  final s = breathSteadiness.clamp(0.0, 1.0);
  var a = 0.04 + 0.02 * s;
  if (a > kWindTracePeakAlpha) a = kWindTracePeakAlpha;
  return (
    alpha: windTraceQuantize(a),
    lengthScale: 0.6 + 0.4 * s,
  );
}

/// 星花被风拂过的极微倾斜：场强 field（-1..1）→ 沿风向的顶点偏移
/// （px，±[kWindTraceSwayMaxPx]，按 [kWindTraceSwayStep] 量化）。
///
/// 与星潮的 sway（第 60 轮）同手法：荒原的风贴地走，星花朝风向极微
/// 地倾一倾（渲染层作为 x 向偏移）。纯函数。
double windTraceSway(double field) {
  final f = field.clamp(-1.0, 1.0);
  return (f * kWindTraceSwayMaxPx / kWindTraceSwayStep).roundToDouble() *
      kWindTraceSwayStep;
}

/// 0.02 步进量化（向下取整；1e-9 容差防浮点误差掉步，峰值 0.06 恰
/// 是量化步长的整数倍，封顶即有效上限）。
double windTraceQuantize(double v) {
  if (v <= 0) return 0;
  return ((v + 1e-9) / kWindTraceAlphaStep).floorToDouble() *
      kWindTraceAlphaStep;
}
