/// 花开之地（第 59 轮）：图鉴余温落在世界上——星花支线收束轮。
///
/// 花境图鉴（第 58 轮）记下了每个心境区域开过的花；本轮让这份账在
/// 世界里留下一处痕迹：对开过花的区域，在确定性的一处浮现一枚极淡
/// 的静止光晕——「这里曾开过很多花」的余温。
///
/// **它不是目标、不是提示、不参与任何经济/进度系统**（星花不给碎片
/// 不给分数是既定设计，此余温同样只是回忆的余温，写死语义防后续
/// 轮误加引导系统）。
///
/// 全部纯函数：位置由区域 seed 的 Knuth 散列确定性给出，亮度随
/// 账本计数单调微升、封顶 [kLandmarkPeakAlpha]（极淡），0.02 步进
/// 量化；账本为 0 时恒隐（alpha = 0）。
library;

import 'breath_flower.dart';
import 'regions.dart';

/// 花开之地的亮度峰值（账本计数很多时封顶在 0.08——比花径还淡）。
const double kLandmarkPeakAlpha = 0.08;

/// 花开之地的起步亮度（第一朵花开后就有一处极淡的余温）。
const double kLandmarkBaseAlpha = 0.04;

/// 亮度达到峰值所需的账本计数（此值及以上恒为峰值）。
const int kLandmarkSaturationCount = 10;

/// 亮度量化步进（与花/花径一致）。
const double kLandmarkAlphaStep = 0.02;

/// 确定性偏移的最大幅度（px，单侧一半）：几何中心附近的一小片。
const double kLandmarkSpread = 150.0;

/// 各心境区域的锚点（归一化几何中心附近）+ 可选的 regionAtPoint 校验。
///
/// 四个深度带区域（海/渊/荒原/雾林）给 `check`，落点用
/// [GameRegion.regionAtPoint] 校验、不命中回落锚点本身；
/// 静之径/惘无固定深度带几何（径是曲线、惑星偶发漂移），给固定的
/// 确定性锚点、不做校验（语义：径/惘的余温锚在它们常驻的静处）。
({double nx, double ny, GameRegion? check}) _anchorOf(FlowerMood mood) {
  switch (mood) {
    case FlowerMood.insomniaSea:
      // 失眠之海是底层全域：取中部（远离渊带/荒原带/雾林接缝）。
      return (nx: 0.5, ny: 0.45, check: GameRegion.insomniaSea);
    case FlowerMood.anxietyAbyss:
      // 渊带 ny 0.80..1.0 的中部。
      return (nx: 0.5, ny: 0.88, check: GameRegion.anxietyAbyss);
    case FlowerMood.wearyHeath:
      // 荒原旷野带 ny 0..0.18 的中部。
      return (nx: 0.5, ny: 0.09, check: GameRegion.wearyHeath);
    case FlowerMood.mistWood:
      // 雾林在 x 接缝两侧：锚在接缝附近的林深处（nx 0.22 → off 0.22）。
      return (nx: 0.22, ny: 0.5, check: GameRegion.mistWood);
    case FlowerMood.stillPath:
      // 静之径中段（径锚点 Offset(312, 1098) 归一化处）。
      return (nx: 312 / 2400, ny: 1098 / 1800, check: null);
    case FlowerMood.perplex:
      // 惑星偶发漂移、无固定位置：惘的余温锚在海的中下带一处静处。
      return (nx: 0.62, ny: 0.62, check: null);
  }
}

/// 花开之地的亮度（纯函数）。
///
/// 账本计数 ≤ 0 恒隐（0）；1 朵起 [kLandmarkBaseAlpha]，随计数
/// 单调微升至 [kLandmarkSaturationCount] 朵封顶 [kLandmarkPeakAlpha]；
/// 输出按 [kLandmarkAlphaStep] 量化。
double landmarkAlphaFor(int ledgerCount) {
  if (ledgerCount <= 0) return 0;
  final span = (kLandmarkSaturationCount - 1).clamp(1, 1 << 30);
  final t = ((ledgerCount - 1) / span).clamp(0.0, 1.0);
  return flowerQuantize(
    kLandmarkBaseAlpha +
        (kLandmarkPeakAlpha - kLandmarkBaseAlpha) * t,
  );
}

/// 花开之地的落点与亮度（纯函数，确定性）。
///
/// 每区域至多一处：取该区域几何中心附近的确定性偏移（seed = 区域
/// 序号，Knuth 散列），[worldW]/[worldH] 应与 `JingjingGame.worldPeriod`
/// 一致（区域校验按周期归一化）。落点须落在该区域内（深度带区域用
/// [GameRegion.regionAtPoint] 校验，不命中回落区域锚点本身）。
/// [ledgerCount] 只影响亮度，不影响位置——余温留在原地，只随记忆
/// 渐渐清晰。
({double x, double y, double alpha}) landmarkSpotFor(
  FlowerMood mood,
  int ledgerCount, {
  required double worldW,
  required double worldH,
}) {
  final anchor = _anchorOf(mood);
  // Knuth 乘法散列的确定性偏移（同区域同偏移，绝不随机会跳）。
  final h = ((mood.index + 1) * 2654435761) >>> 0;
  final ox = (((h >>> 16) & 0xFF) / 255.0 - 0.5) * kLandmarkSpread;
  final oy = (((h >>> 4) & 0xFF) / 255.0 - 0.5) * kLandmarkSpread;
  var x = (anchor.nx * worldW + ox) % worldW;
  var y = (anchor.ny * worldH + oy) % worldH; // Dart % 恒非负。
  final check = anchor.check;
  if (check != null && !identical(GameRegion.regionAtPoint(x, y), check)) {
    // 不落回退到区域锚点本身（锚点恒在区域内）。
    x = anchor.nx * worldW;
    y = anchor.ny * worldH;
  }
  return (x: x, y: y, alpha: landmarkAlphaFor(ledgerCount));
}
