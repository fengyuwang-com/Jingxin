import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shard.dart';

/// 「一夜的记忆」拾忆回看统计（第 24 轮）。
///
/// 纯函数，可测。数据只来自既有 `jingxin.shards.v1` 的 ShardRecord，
/// 不改任何持久化格式。
///
/// 「静了 M 个夜晚」：按碎片拾取时刻的本地日期去重——
/// 同一个深夜里（哪怕跨过零点前后各拾一枚，落在两个日期）也照实计数：
/// 星图记录的是"哪几天来过"，不是睡眠时长。

/// 单个时刻 -> 本地日期键（yyyy-MM-dd）。
String shardDateKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// 全部碎片的去重日期键集合。
Set<String> shardDateKeys(List<ShardRecord> records) =>
    records.map((r) => shardDateKey(r.time)).toSet();

/// 去重后的夜晚数。
int countNights(List<ShardRecord> records) => shardDateKeys(records).length;

/// 抽屉顶部的一句汇总：N=0 时空态，否则「已拾 N 枚碎片 · 静了 M 个夜晚」。
String memorySummary(List<ShardRecord> records) {
  if (records.isEmpty) return '星图还空着，去呼吸吧';
  return '已拾 ${records.length} 枚碎片 · 静了 ${countNights(records)} 个夜晚';
}

/// 「星河的章节」（第 25 轮）：按夜晚分组重看。
///
/// 碎片聚成夜晚，夜晚串成一条静下来的轨迹。仍是纯函数、只读
/// `jingxin.shards.v1` 的 ShardRecord，不改任何持久化格式。

/// 一个夜晚：一个本地日期下的全部碎片（时间新→旧排好）。
class NightGroup {
  NightGroup({required this.dateKey, required this.records});

  /// 本地日期键（yyyy-MM-dd）。
  final String dateKey;

  /// 这一夜的碎片，按拾取时刻新→旧排序。
  final List<ShardRecord> records;
}

/// 把全部碎片按本地日期分组，最近的夜在最前；
/// 每组内碎片按时间新→旧排序。空列表返回空列表。
List<NightGroup> groupNightsByDate(List<ShardRecord> records) {
  if (records.isEmpty) return const [];
  final byDate = <String, List<ShardRecord>>{};
  for (final r in records) {
    byDate.putIfAbsent(shardDateKey(r.time), () => []).add(r);
  }
  final groups = byDate.entries
      .map(
        (e) => NightGroup(
          dateKey: e.key,
          records: e.value..sort((a, b) => b.time.compareTo(a.time)),
        ),
      )
      .toList()
    ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  return groups;
}

/// 夜晚的日期签文案：`2026-09-12` + 3 枚 →「9月12日 · 3 枚」。
String nightLabel(String dateKey, int count) {
  final parts = dateKey.split('-');
  final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
  final day = parts.length > 2 ? int.tryParse(parts[2]) : null;
  final dateText = (month != null && day != null)
      ? '$month月$day日'
      : dateKey;
  return '$dateText · $count 枚';
}

/// 历史单夜最多的碎片数（用于夜弧完成度的归一化）。空表返回 0。
int busiestNight(List<ShardRecord> records) {
  if (records.isEmpty) return 0;
  final counts = <String, int>{};
  for (final r in records) {
    counts[shardDateKey(r.time)] = (counts[shardDateKey(r.time)] ?? 0) + 1;
  }
  return counts.values.reduce(math.max);
}

/// 夜弧扫过角度（弧度，0..2π）：该夜碎片数 / 历史单夜最多数，
/// 封顶整圆。单夜最多数为 0（理论不出现）时返回整圆。
double nightArcSweep(int count, int maxCount) {
  if (maxCount <= 0) return 2 * math.pi;
  final fraction = (count / maxCount).clamp(0.0, 1.0);
  return 2 * math.pi * fraction;
}

/// 来源区域的星点色相（与游戏内区域配色一致，regions.dart tint）：
/// 渊=冷紫、海=青、荒原=暖沙、雾林=青灰、相会/惘=金。
Color regionDotColor(String region) {
  if (region.contains('两兽之间') || region.contains('惘')) {
    return const Color(0xFFe8c473); // 相会双星的金。
  }
  if (region.contains('渊')) return const Color(0xFF9b8fb8); // 焦虑之渊。
  if (region.contains('荒原')) return const Color(0xFFc9a97a); // 疲惫荒原。
  if (region.contains('雾林')) return const Color(0xFF8fc4b0); // 纷心雾林。
  return const Color(0xFF67e8f9); // 失眠之海（默认底层）。
}
