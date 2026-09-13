/// 花境图鉴（第 58 轮）纯逻辑单测：编码 roundtrip、脏数据容错、
/// 溢出防御封顶、bump 只增不减。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/breath_flower.dart';

void main() {
  group('flowerLedgerEncode / flowerLedgerDecode roundtrip', () {
    test('全 0 账本 roundtrip', () {
      final l = flowerLedgerNew();
      expect(flowerLedgerDecode(flowerLedgerEncode(l)), l);
    });

    test('典型账本 roundtrip', () {
      final l = [3, 0, 5, 1, 0, 2];
      expect(flowerLedgerDecode(flowerLedgerEncode(l)), l);
    });

    test('编码格式为六段竖线分隔', () {
      expect(flowerLedgerEncode([3, 0, 5, 1, 0, 2]), '3|0|5|1|0|2');
    });

    test('上限值 roundtrip', () {
      final l = List<int>.filled(kFlowerLedgerRegions, kFlowerLedgerMaxPerRegion);
      expect(flowerLedgerDecode(flowerLedgerEncode(l)), l);
    });
  });

  group('flowerLedgerDecode 脏数据容错', () {
    test('空串 → 全 0', () {
      expect(flowerLedgerDecode(''), flowerLedgerNew());
    });

    test('完全不可解析 → 全 0', () {
      expect(flowerLedgerDecode('abc|def||ghi'), flowerLedgerNew());
    });

    test('非法 token 按该区 0 计，合法段保留', () {
      expect(flowerLedgerDecode('2|x|7'), [2, 0, 7, 0, 0, 0]);
    });

    test('负数 token 按 0 计', () {
      expect(flowerLedgerDecode('1|-3|4'), [1, 0, 4, 0, 0, 0]);
    });

    test('段数不足六段缺省 0，多出的段忽略', () {
      expect(flowerLedgerDecode('1|2'), [1, 2, 0, 0, 0, 0]);
      expect(flowerLedgerDecode('1|2|3|4|5|6|7|8'), [1, 2, 3, 4, 5, 6]);
    });

    test('带空白容错', () {
      expect(flowerLedgerDecode(' 1 | 2 | 3 '), [1, 2, 3, 0, 0, 0]);
    });

    test('超上限夹到 9999', () {
      expect(
        flowerLedgerDecode('9999|10000|123456789'),
        [9999, 9999, 9999, 0, 0, 0],
      );
    });
  });

  group('flowerLedgerBump 只增不减', () {
    test('bump 对应区域 +1，其余不变，且不修改原账本（纯函数）', () {
      final l = [1, 0, 2, 0, 0, 0];
      final out = flowerLedgerBump(l, 2);
      expect(out, [1, 0, 3, 0, 0, 0]);
      expect(l, [1, 0, 2, 0, 0, 0]); // 原账本不被改写。
    });

    test('花谢不扣账：没有减法入口，bump 只会加', () {
      var l = flowerLedgerNew();
      for (int i = 0; i < 10; i++) {
        l = flowerLedgerBump(l, 0);
      }
      expect(l[0], 10);
    });

    test('单区封顶 9999：再 bump 也不越过', () {
      var l = flowerLedgerNew();
      l[4] = kFlowerLedgerMaxPerRegion;
      l = flowerLedgerBump(l, 4);
      l = flowerLedgerBump(l, 4);
      expect(l[4], kFlowerLedgerMaxPerRegion);
    });

    test('区域越界原样返回副本', () {
      final l = [1, 2, 3, 4, 5, 6];
      expect(flowerLedgerBump(l, -1), l);
      expect(flowerLedgerBump(l, 6), l);
      expect(flowerLedgerBump(l, 99), l);
    });

    test('连续 bump 多区域计数正确', () {
      var l = flowerLedgerNew();
      l = flowerLedgerBump(l, FlowerMood.insomniaSea.index);
      l = flowerLedgerBump(l, FlowerMood.insomniaSea.index);
      l = flowerLedgerBump(l, FlowerMood.perplex.index);
      expect(l, [2, 0, 0, 0, 0, 1]);
    });
  });
}
