import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/memo_stats.dart';
import 'package:jingxin_meditation/game/shard.dart';

ShardRecord _rec(String iso, {String region = '失眠之海·心湖'}) =>
    ShardRecord(time: DateTime.parse(iso), text: '测试偈语', region: region);

void main() {
  group('夜晚数去重（按本地日期）', () {
    test('同一天多枚只算一个夜晚', () {
      final n = countNights([
        _rec('2026-09-10 23:10'),
        _rec('2026-09-10 23:55'),
        _rec('2026-09-10 23:59'),
      ]);
      expect(n, 1);
    });

    test('不同日期各算一个夜晚，且打乱顺序不影响', () {
      final n = countNights([
        _rec('2026-09-10 23:10'),
        _rec('2026-09-12 00:05'),
        _rec('2026-09-11 22:00'),
        _rec('2026-09-12 01:30'),
      ]);
      expect(n, 3);
      expect(shardDateKeys([_rec('2026-09-01 09:00')]).first, '2026-09-01');
    });
  });

  group('汇总文案', () {
    test('空态是邀请而非数字', () {
      expect(memorySummary([]), '星图还空着，去呼吸吧');
    });

    test('非空显示碎片数与去重夜晚数', () {
      final s = memorySummary([
        _rec('2026-09-10 23:10'),
        _rec('2026-09-10 23:40'),
        _rec('2026-09-12 00:05'),
      ]);
      expect(s, '已拾 3 枚碎片 · 静了 2 个夜晚');
    });
  });

  group('区域星点色相', () {
    test('与游戏内区域配色一致', () {
      expect(regionDotColor('焦虑之渊·渊底'), const Color(0xFF9b8fb8));
      expect(regionDotColor('失眠之海·心湖'), const Color(0xFF67e8f9));
      expect(regionDotColor('疲惫荒原·旷心'), const Color(0xFFc9a97a));
      expect(regionDotColor('纷心雾林·雾心'), const Color(0xFF8fc4b0));
      expect(regionDotColor('两兽之间'), const Color(0xFFe8c473));
    });
  });
}
