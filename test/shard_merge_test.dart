import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/memento.dart';
import 'package:jingxin_meditation/game/shard.dart';

ShardRecord rec(int ms, String text, [String region = '失眠之海']) =>
    ShardRecord(
      time: DateTime.fromMillisecondsSinceEpoch(ms),
      text: text,
      region: region,
    );

void main() {
  group('MementoCodec', () {
    test('编码后可原样解回（往返）', () {
      final shards = [
        rec(1700000000000, '雾不是墙。', '纷心雾林'),
        rec(1700003600000, '海替你数着呼吸。'),
      ];
      final code = MementoCodec.encode(
        shards: shards,
        awakening: 0.42,
        beastValue: 0.6,
        beastSwimUntil: 12345,
      );
      expect(code.startsWith(MementoCodec.prefix), isTrue);

      final data = MementoCodec.tryDecode(code);
      expect(data, isNotNull);
      expect(data!.shards.length, 2);
      expect(data.shards[0].text, '雾不是墙。');
      expect(data.shards[0].region, '纷心雾林');
      expect(data.shards[0].time.millisecondsSinceEpoch, 1700000000000);
      expect(data.awakening, closeTo(0.42, 1e-9));
      expect(data.beastValue, closeTo(0.6, 1e-9));
      expect(data.beastSwimUntil, 12345);
    });

    test('前缀前混入说明文字、base64 混入空白也能解析', () {
      final code = MementoCodec.encode(
        shards: [rec(1, 'x')],
        awakening: 0.1,
        beastValue: 0,
        beastSwimUntil: 0,
      );
      final messy = '静境拾忆 V1 说明……\n${code.substring(0, 12)}\n'
          '${code.substring(12, 30)} ${code.substring(30)}\n';
      final data = MementoCodec.tryDecode(messy);
      expect(data, isNotNull);
      expect(data!.shards.length, 1);
    });

    test('异常输入一律静默返回 null', () {
      expect(MementoCodec.tryDecode(''), isNull);
      expect(MementoCodec.tryDecode('不是拾忆文本'), isNull);
      expect(MementoCodec.tryDecode('${MementoCodec.prefix}!!!不是base64!!!'),
          isNull);
      expect(MementoCodec.tryDecode('${MementoCodec.prefix}aGVsbG8='), isNull);
      // 版本不符（手工构造 v2 载荷）。
      final badVersion =
          '${MementoCodec.prefix}${base64Encode(utf8.encode('{"v":2,"shards":[]}'))}';
      expect(MementoCodec.tryDecode(badVersion), isNull);
    });
  });

  group('mergeShards', () {
    test('同时间戳+同禅语视为同片，不重复添加', () {
      final existing = [rec(100, 'a'), rec(200, 'b')];
      final incoming = [rec(200, 'b'), rec(300, 'c')];
      final (merged, added) = mergeShards(existing, incoming);
      expect(merged.length, 3);
      expect(added, 1);
      // 时间升序。
      expect(
        merged.map((r) => r.time.millisecondsSinceEpoch).toList(),
        [100, 200, 300],
      );
    });

    test('同时间戳不同禅语视为不同的片', () {
      final existing = [rec(100, 'a')];
      final incoming = [rec(100, 'b')];
      final (merged, added) = mergeShards(existing, incoming);
      expect(merged.length, 2);
      expect(added, 1);
    });

    test('不覆盖现有记录：同片保留现有实例', () {
      final keep = rec(100, 'a', '焦虑之渊');
      final existing = [keep];
      final incoming = [rec(100, 'a', '失眠之海')];
      final (merged, added) = mergeShards(existing, incoming);
      expect(added, 0);
      expect(identical(merged.single, keep), isTrue);
      expect(merged.single.region, '焦虑之渊');
    });

    test('空现有列表全部带入', () {
      final incoming = [rec(1, 'x'), rec(2, 'y')];
      final (merged, added) = mergeShards([], incoming);
      expect(added, 2);
      expect(merged.length, 2);
    });

    test('导入后的结果可再次导出且幂等', () {
      final shards = [rec(100, 'a'), rec(200, 'b')];
      final code = MementoCodec.encode(
        shards: shards,
        awakening: 0.3,
        beastValue: 0,
        beastSwimUntil: 0,
      );
      final data = MementoCodec.tryDecode(code)!;
      final (merged1, added1) = mergeShards(shards, data.shards);
      expect(added1, 0);
      final (merged2, added2) = mergeShards(merged1, data.shards);
      expect(added2, 0);
      expect(merged2.length, 2);
    });
  });
}
