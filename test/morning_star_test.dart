import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/jingjing_game.dart';
import 'package:jingxin_meditation/game/koans.dart';
import 'package:jingxin_meditation/game/morning_star.dart';

void main() {
  group('MorningStarCtl 醒痕晨星', () {
    test('可见性：演过满醒才常驻，未演过不可见', () {
      expect(MorningStarCtl.visible(playedEver: false), isFalse);
      expect(MorningStarCtl.visible(playedEver: true), isTrue);
    });

    test('点击冷却：10s 内不重复弹，满 10s 可再弹', () {
      expect(MorningStarCtl.koanAllowed(0.0), isFalse);
      expect(MorningStarCtl.koanAllowed(5.0), isFalse);
      expect(MorningStarCtl.koanAllowed(9.9), isFalse);
      expect(MorningStarCtl.koanAllowed(10.0), isTrue);
    });

    test('命中判定：半径 40 内命中、外不命中，且环绕最近差生效（贴缝也能点中）', () {
      final period = JingjingGame.worldPeriod;
      final star = MorningStarCtl.position(period);
      // 正上方 39px：命中。
      expect(
        MorningStarCtl.hitTest(star + Vector2(0, -39), star, period),
        isTrue,
      );
      // 41px：不命中。
      expect(
        MorningStarCtl.hitTest(star + Vector2(41, 0), star, period),
        isFalse,
      );
      // 环绕最短差：从星的正前方一个周期之外看，仍是同一处（距离 0）。
      expect(
        MorningStarCtl.hitTest(
          star + Vector2(period.x, 0),
          star,
          period,
        ),
        isTrue,
      );
      // 晨星位置固定且在既有区域/静之径之外：海中带（ny 0.225，
      // 不在渊 ny≥0.80 / 荒原 ny≤0.18 / 雾林接缝带 off≤0.36）。
      final ny = star.y / period.y;
      final off = star.x / period.x > 0.5
          ? 1 - star.x / period.x
          : star.x / period.x;
      expect(ny, greaterThan(0.18));
      expect(ny, lessThan(0.80));
      expect(off, greaterThan(0.36));
    });

    test('偈语轮换：3 句轮换取用，一轮内绝不重复', () {
      final r = KoanRotator();
      final seen = <String>{};
      for (int i = 0; i < Koans.morningStarPool.length; i++) {
        final k = r.next(Koans.morningStarPool);
        expect(seen.contains(k), isFalse); // 一轮内不重复。
        seen.add(k);
      }
      expect(seen.length, Koans.morningStarPool.length);
      // 第 4 次回到第一句：轮换而非耗尽（索引回到 0）。
      expect(r.index, Koans.morningStarPool.length - 1);
      expect(r.next(Koans.morningStarPool), seen.first);
      expect(r.index, 0);
    });
  });
}
