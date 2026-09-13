import 'dart:convert';

import 'shard.dart';

/// 「拾忆」（第 15 轮）：心镜数据的打包与带回。
///
/// 导出格式（schema，供将来导入兼容）：
/// ```
/// jx-memo-v1:<base64(utf8(json))>
/// json = {
///   "v": 1,                              // 格式版本
///   "at": <epoch ms>,                    // 导出时刻
///   "awa": <0..1 苏醒度>,
///   "beast": {"v": <0..1>, "swim": <epoch ms 游弋截止>},
///   "shards": [ {"t": <epoch ms>, "text": <禅语>, "region": <区域名>} ... ]
/// }
/// ```
/// 轻混淆仅为避免被一眼读出，不是加密。解析失败一律静默返回 null，
/// 由 UI 给一行淡字——不打扰、不说教。
class MementoCodec {
  MementoCodec._();

  static const String prefix = 'jx-memo-v1:';

  static String encode({
    required List<ShardRecord> shards,
    required double awakening,
    required double beastValue,
    required int beastSwimUntil,
    DateTime? now,
  }) {
    final payload = <String, dynamic>{
      'v': 1,
      'at': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'awa': _round(awakening),
      'beast': {'v': _round(beastValue), 'swim': beastSwimUntil},
      'shards': shards
          .map(
            (s) => {'t': s.time.millisecondsSinceEpoch, 'text': s.text, 'region': s.region},
          )
          .toList(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    return '$prefix${base64Encode(bytes)}';
  }

  /// 解析并校验。任何异常（前缀不对、base64 坏、字段缺、版本不符）
  /// 都静默返回 null。
  static MementoData? tryDecode(String raw) {
    try {
      var text = raw.trim();
      // 容忍粘贴时混入的说明文字：截取前缀之后的部分。
      final idx = text.indexOf(prefix);
      if (idx < 0) return null;
      text = text.substring(idx + prefix.length).trim();
      // 容忍换行/空白混入 base64。
      text = text.replaceAll(RegExp(r'\s'), '');
      if (text.isEmpty) return null;
      final decoded = utf8.decode(base64Decode(text));
      final map = jsonDecode(decoded);
      if (map is! Map<String, dynamic>) return null;
      if (map['v'] != 1) return null;
      final shardsRaw = map['shards'];
      if (shardsRaw is! List) return null;
      final shards = <ShardRecord>[];
      for (final item in shardsRaw) {
        if (item is! Map<String, dynamic>) return null;
        final t = (item['t'] as num?)?.toInt();
        final text2 = item['text'];
        if (t == null || text2 is! String || text2.isEmpty) return null;
        shards.add(
          ShardRecord(
            time: DateTime.fromMillisecondsSinceEpoch(t),
            text: text2,
            region: (item['region'] as String?) ?? '失眠之海',
          ),
        );
      }
      return MementoData(
        shards: shards,
        awakening: ((map['awa'] as num?)?.toDouble() ?? 0.02).clamp(0.0, 1.0),
        beastValue: ((map['beast']?['v'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 1.0),
        beastSwimUntil: (map['beast']?['swim'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static double _round(double v) => (v * 1000).round() / 1000;
}

class MementoData {
  MementoData({
    required this.shards,
    required this.awakening,
    required this.beastValue,
    required this.beastSwimUntil,
  });

  final List<ShardRecord> shards;
  final double awakening;
  final double beastValue;
  final int beastSwimUntil;
}

/// 合并策略（第 15 轮）：按碎片去重合并，不覆盖现有。
/// 同一片 = 同一时间戳 + 同禅语（含区域一致则更稳）。返回
/// [合并后的全部碎片（按时间升序）, 新带入的片数]。
/// 合并后的列表复用现有实例的记录对象（identical 保持），只追加新的。
(List<ShardRecord> merged, int added) mergeShards(
  List<ShardRecord> existing,
  List<ShardRecord> incoming,
) {
  bool same(ShardRecord a, ShardRecord b) =>
      a.time.millisecondsSinceEpoch == b.time.millisecondsSinceEpoch &&
      a.text == b.text;

  final merged = List<ShardRecord>.of(existing);
  var added = 0;
  for (final inc in incoming) {
    final dup = merged.any((m) => same(m, inc));
    if (dup) continue;
    merged.add(inc);
    added++;
  }
  merged.sort((a, b) => a.time.compareTo(b.time));
  return (merged, added);
}
