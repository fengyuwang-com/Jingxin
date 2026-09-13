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

  static const List<GameRegion> all = [anxietyAbyss, wearyHeath, insomniaSea];

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
  static GameRegion regionAt(Vector2 worldPos) {
    final ny = (worldPos.y / JingjingGame.worldPeriod.y) % 1.0;
    for (final region in all) {
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