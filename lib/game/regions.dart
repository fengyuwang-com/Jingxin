import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';

/// 轻量「区域」抽象（第 7 轮）。
///
/// 世界是一个 2400x1800 的环绕环面；每个区域 = 自己的程序生成层 +
/// 内容物 + 色调 + 归一化 y 深度带。区域之间无加载、无传送门、无按钮：
/// 光灵漫游到哪个深度带，哪里的世界就自然浮现。
class GameRegion {
  const GameRegion({
    required this.name,
    required this.centerName,
    required this.rows,
    required this.cols,
    required this.tint,
    required this.depthStart,
    required this.depthFull,
    this.upper = false,
    this.xFull = -1,
    this.xStart = -1,
    this.gateLo = 0,
    this.gateHi = 1,
  });

  final String name;

  /// 九宫格正中的名字（诗意中心）。
  final String centerName;

  /// 九宫格行/列名（北→南 / 西→东）。
  final List<String> rows;
  final List<String> cols;

  /// 区域主题色调（星点/辉光用）。
  final Color tint;

  /// 归一化 y 深度带：depthStart 开始浮现，depthFull 完全进入。
  /// depthStart < 0 表示全域常在（底层区域）。
  final double depthStart;
  final double depthFull;

  /// 上部区域（如「疲惫荒原」的旷野带）：depthFull < ny 即开始浮现，
  /// ny < depthStart 完全进入（与下行区域的接入方式镜像对称）。
  final bool upper;

  /// 水平边缘带区域（第 13 轮「纷心雾林」）：世界是环绕环面，
  /// x=0/1 是同一条接缝——靠近接缝（nx 或 1-nx 小）即深入。
  /// nx 离接缝 <= xFull 完全进入，>= xStart 开始浮现（smoothstep）。
  /// 同时受纵向 ny 门带 [gateLo, gateHi] 约束（带外淡出）。
  /// xFull < 0 表示非水平区域，走 depthAt(ny) 的纵向逻辑。
  final double xFull;
  final double xStart;

  /// 水平区域的纵向门带（ny 范围）。
  final double gateLo;
  final double gateHi;

  /// 水平区域的深度（0..1，smoothstep）：接缝越近越深，纵向门带淡出。
  double depthAtPoint(double nx, double ny) {
    if (xFull < 0) return depthAt(ny);
    final off = nx > 0.5 ? 1 - nx : nx;
    final t = ((xStart - off) / (xStart - xFull)).clamp(0.0, 1.0);
    final sx = t * t * (3 - 2 * t);
    final lo = ((ny - gateLo) / 0.06).clamp(0.0, 1.0);
    final hi = ((gateHi - ny) / 0.06).clamp(0.0, 1.0);
    final g = (lo < hi ? lo : hi);
    final gs = g * g * (3 - 2 * g);
    return sx * gs;
  }

  /// 「疲惫荒原」：世界上部的旷野高空带（第 9 轮，第三个心境区域）。
  /// 地形隐喻是「地平线/旷野」而非深度——光灵上浮抵达。
  static const wearyHeath = GameRegion(
    name: '疲惫荒原',
    centerName: '旷心',
    rows: ['天隈', '旷原', '风缘'],
    cols: ['西碛', '中碛', '东碛'],
    tint: Color(0xFFc9a97a),
    depthStart: 0.05,
    depthFull: 0.18,
    upper: true,
  );

  /// 「纷心雾林」：世界左/右接缝两侧的水平带（第 13 轮，第四心境区域）。
  /// 环绕世界的 x 接缝两侧是同一片雾林——向左或向右走出中带即深入，
  /// 纵向限制在 ny 0.28~0.72（海的中层高度，与渊/荒原的深度带不冲突）。
  static const mistWood = GameRegion(
    name: '纷心雾林',
    centerName: '雾心',
    rows: ['雾隈', '雾心', '雾涯'],
    cols: ['西林', '中林', '东林'],
    tint: Color(0xFF8fc4b0),
    depthStart: 0.28,
    depthFull: 0.72,
    xFull: 0.14,
    xStart: 0.36,
    gateLo: 0.28,
    gateHi: 0.72,
  );

  /// 「失眠之海」：全域底层的第一个心境区域。
  static const insomniaSea = GameRegion(
    name: '失眠之海',
    centerName: '心湖',
    rows: ['北渊', '心湖', '南汀'],
    cols: ['西湾', '中洋', '东渚'],
    tint: Color(0xFF67e8f9),
    depthStart: -1,
    depthFull: -1,
  );

  /// 「焦虑之渊」：海的更深处（世界下半极深带，漫游即抵达）。
  static const anxietyAbyss = GameRegion(
    name: '焦虑之渊',
    centerName: '渊心',
    rows: ['浅壑', '深壑', '渊底'],
    cols: ['西隙', '中隙', '东隙'],
    tint: Color(0xFF9b8fb8),
    depthStart: 0.80,
    depthFull: 0.93,
  );

  static const List<GameRegion> all = [
    anxietyAbyss,
    wearyHeath,
    mistWood,
    insomniaSea,
  ];

  /// 归一化 y -> 区域深度（0..1，smoothstep；全域区域恒为 1）。
  /// 上部区域方向反转：ny 越小越深入。
  double depthAt(double ny) {
    if (depthStart < 0) return 1;
    final t = upper
        ? ((depthFull - ny) / (depthFull - depthStart)).clamp(0.0, 1.0)
        : ((ny - depthStart) / (depthFull - depthStart)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// 世界坐标所属区域：按深度带从两端向中间匹配，海是默认底层。
  static GameRegion regionAt(Vector2 worldPos) =>
      regionAtPoint(worldPos.x, worldPos.y);

  /// 点在哪个区域（纯函数，便于测试）：世界坐标 (x, y)。
  ///
  /// 世界是环绕环面：坐标先对周期取模（Dart 的 % 恒非负，负坐标 /
  /// 超界坐标自动落回 0..period），再按深度带从两端向中间匹配；
  /// 雾林水平带在 x 接缝两侧（含跨缝环绕点）与纵向门带内命中；
  /// 都不命中则回落到底层的失眠之海。
  static GameRegion regionAtPoint(double x, double y) {
    final period = JingjingGame.worldPeriod;
    final ny = (y / period.y) % 1.0;
    final nx = (x / period.x) % 1.0;
    for (final region in all) {
      if (region.xFull >= 0) {
        // 水平边缘带：靠近 x 接缝且在纵向门带内。
        final off = nx > 0.5 ? 1 - nx : nx;
        if (off <= region.xStart && ny >= region.gateLo && ny <= region.gateHi) {
          return region;
        }
        continue;
      }
      if (region.depthStart < 0) continue;
      final inBand = region.upper
          ? ny <= region.depthFull
          : ny >= region.depthStart;
      if (inBand) return region;
    }
    return insomniaSea;
  }

  /// 九宫格诗意命名（星图里的回忆坐标）。
  String gridName(Vector2 worldPos) {
    final nx =
        ((worldPos.x % JingjingGame.worldPeriod.x) / JingjingGame.worldPeriod.x)
            .clamp(0.0, 0.999);
    final ny =
        ((worldPos.y % JingjingGame.worldPeriod.y) / JingjingGame.worldPeriod.y)
            .clamp(0.0, 0.999);
    final col = (nx * 3).floor().clamp(0, 2);
    final row = (ny * 3).floor().clamp(0, 2);
    if (row == 1 && col == 1) return centerName;
    return '${rows[row]}·${cols[col]}';
  }

  /// 完整区域名，如「焦虑之渊·渊底·中隙」。
  String fullName(Vector2 worldPos) {
    final grid = gridName(worldPos);
    return grid == centerName ? '$name·$centerName' : '$name·$grid';
  }
}

/// smoothstep（供区域过渡复用）。
double regionSmoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// 供区域组件计算环绕最短差的便捷函数。
Vector2 regionWrapDelta(Vector2 from, Vector2 to) {
  final period = JingjingGame.worldPeriod;
  final d = to - from;
  final dx = (d.x + period.x * 1.5) % period.x - period.x / 2;
  final dy = (d.y + period.y * 1.5) % period.y - period.y / 2;
  return Vector2(dx, dy);
}