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
