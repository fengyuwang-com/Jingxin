// 长夜沉底（第 66 轮）：睡前章节最后一道纯视觉呼应——四环境层的集体收束。
//
// 理念：**入夜不抹黑，而是万物安眠**。nightAmount 爬升时（≥0.5 起明显），
// 四个环境层各自缓缓"沉底"：
// - 星潮（海）：波纹振幅渐收至静止海面（[nightSettleSeaAmpScale] 1→0.15）；
// - 渊光（渊）：上浮微光整体缓沉降向渊底（[nightSettleAbyssDyPx] 0→+8px，
//   在现有 alpha 让位之外叠加的下沉位移，上限 ≤10px）；
// - 风痕（荒原）：风痕流速与长度渐止到近乎凝滞（[nightSettleWindSpeedScale]
//   1→0.08、[nightSettleWindLengthScale] 1→0.25）；
// - 萤迹（雾林）：萤火漂移速度渐慢（[nightSettleFireflyDriftScale] 1→0.15）、
//   亮度包络趋低（[nightSettleFireflyGlowFloor] 0.35→0.10）。
//
// 语义边界（写死，防后续轮误加）：本增量**只动运动/幅度/包络层面**——
// 各层现有的 nightYield（alpha ×(1−nightAmount)）让位逻辑保留不变，alpha
// 端不经过这里任何函数，也不产生 alpha 量化。无任何奖励/UI/音效/文案，
// 不参与经济系统。黎明回落（nightAmount 下降）时各层自然恢复：全部系数
// 是 nightAmount 的纯派生量，不需要状态机。
//
// 全部函数为纯函数、无类型依赖（不 import 游戏类型），便于测试。

/// 沉底起点（nightAmount）：0..[kNightSettleStart] 完全不动，与各层
/// nightYield 线性让位错开——前半段夜只是变暗，后半段万物开始安眠。
const double kNightSettleStart = 0.5;

/// 沉底终点（nightAmount）：≥ 此值沉底程度达到 1（最深安眠）。
const double kNightSettleEnd = 0.95;

/// smoothstep 三次缓动 t²(3−2t)：两端导数为 0（入眠不突兀、醒来不惊醒）。
double _smooth(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

/// 沉底程度（0..1）：nightAmount → smoothstep 映射。
///
/// nightAmount ≤ [kNightSettleStart] → 0；≥ [kNightSettleEnd] → 1；
/// 界内 smoothstep 单调不减；越界输入一律夹住。纯派生量——黎明回落时
/// 沿同一曲线自然恢复，不需要任何状态机。
double nightSettleFactor(double nightAmount) {
  final n = nightAmount.isNaN ? 0.0 : nightAmount.clamp(0.0, 1.0);
  final t = (n - kNightSettleStart) / (kNightSettleEnd - kNightSettleStart);
  return _smooth(t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 星潮·波纹振幅乘子（1→0.15）：沉底时涟漪渐收至近乎静止的海面。
/// 渲染层把它叠进 sway 幅度与场强均值（不动 alpha、不动相位）。
double nightSettleSeaAmpScale(double settle) {
  return _lerp(1.0, 0.15, nightSettleFactor(settle));
}

/// 渊光·下沉位移（px，非负向下，上限 ≤10px）：上浮微光整体缓缓沉降向
/// 渊底（0→8px，smoothstep）。在现有 alpha 让位之外叠加的运动层收束。
double nightSettleAbyssDyPx(double settle) {
  return 8.0 * nightSettleFactor(settle);
}

/// 渊光·上浮速度乘子（1→0.25）：沉降的同时上浮本身也渐慢——
/// 不是掉下去，是不想再浮了。
double nightSettleAbyssRiseScale(double settle) {
  return _lerp(1.0, 0.25, nightSettleFactor(settle));
}

/// 风痕·流速乘子（1→0.08）：荒原的风渐止到近乎凝滞。
/// 渲染层同时用它缩放帧内外推步长与节拍重算用的等效时间。
double nightSettleWindSpeedScale(double settle) {
  return _lerp(1.0, 0.08, nightSettleFactor(settle));
}

/// 风痕·长度乘子（1→0.25）：风痕渐收短（与呼吸平稳度的 lengthScale 同法，
/// 叠乘使用）。
double nightSettleWindLengthScale(double settle) {
  return _lerp(1.0, 0.25, nightSettleFactor(settle));
}

/// 萤迹·漂移速度乘子（1→0.15）：萤火漂移渐慢（帧内外推与吸引靠近共用）。
double nightSettleFireflyDriftScale(double settle) {
  return _lerp(1.0, 0.15, nightSettleFactor(settle));
}

/// 萤迹·明灭包络下限（0.35→0.10）：亮度包络趋低——萤火不是熄灭，是眯眼。
/// 渲染层用 floor + (1−floor)×envelope 重塑包络；alpha 仍走原有量化链，
/// 本函数不产生任何 alpha 值。
double nightSettleFireflyGlowFloor(double settle) {
  return _lerp(0.35, 0.10, nightSettleFactor(settle));
}
