// 花开之地（第 59 轮）的纯函数测试：确定性 / 区域归属 / 封顶 / 恒隐，
// 以及「账本从 0 增到 N 时余温亮度单调不回跌且封顶」的管线测试。
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/breath_flower.dart';
import 'package:jingxin_meditation/game/breath_flower_landmark.dart';
import 'package:jingxin_meditation/game/regions.dart';

const double worldW = 2400;
const double worldH = 1800;

GameRegion? _regionOf(FlowerMood mood) => switch (mood) {
  FlowerMood.insomniaSea => GameRegion.insomniaSea,
  FlowerMood.anxietyAbyss => GameRegion.anxietyAbyss,
  FlowerMood.wearyHeath => GameRegion.wearyHeath,
  FlowerMood.mistWood => GameRegion.mistWood,
  _ => null, // 静之径/惘无深度带几何，不做归属校验。
};

void main() {
  group('landmarkSpotFor · 落点确定性', () {
    test('同区域同账本两次调用结果完全一致', () {
      final a = landmarkSpotFor(
        FlowerMood.anxietyAbyss, 5, worldW: worldW, worldH: worldH,
      );
      final b = landmarkSpotFor(
        FlowerMood.anxietyAbyss, 5, worldW: worldW, worldH: worldH,
      );
      expect(a.x, b.x);
      expect(a.y, b.y);
      expect(a.alpha, b.alpha);
    });

    test('账本计数只影响亮度，不影响位置', () {
      final a = landmarkSpotFor(
        FlowerMood.mistWood, 1, worldW: worldW, worldH: worldH,
      );
      final b = landmarkSpotFor(
        FlowerMood.mistWood, 99, worldW: worldW, worldH: worldH,
      );
      expect(a.x, b.x);
      expect(a.y, b.y);
      expect(a.alpha, isNot(equals(b.alpha)));
    });

    test('不同区域的落点互不相同', () {
      final spots = FlowerMood.values
          .map((m) => landmarkSpotFor(m, 3, worldW: worldW, worldH: worldH))
          .toList();
      for (int i = 0; i < spots.length; i++) {
        for (int j = i + 1; j < spots.length; j++) {
          final same = spots[i].x == spots[j].x && spots[i].y == spots[j].y;
          expect(same, isFalse, reason: '区域 $i 与 $j 落点重合');
        }
      }
    });
  });

  group('landmarkSpotFor · 区域归属', () {
    for (final mood in FlowerMood.values) {
      final check = _regionOf(mood);
      if (check == null) continue;
      test('${mood.name} 的落点落在该区域内（regionAtPoint 校验）', () {
        final s = landmarkSpotFor(
          mood, 4, worldW: worldW, worldH: worldH,
        );
        expect(identical(GameRegion.regionAtPoint(s.x, s.y), check), isTrue);
      });
    }

    test('深度带区域的落点在极端小偏移散布下也绝不落回锚点', () {
      // 落点应偏离锚点（偏移生效），而非退化为质心本身。
      final s = landmarkSpotFor(
        FlowerMood.insomniaSea, 2, worldW: worldW, worldH: worldH,
      );
      expect(s.x == 0.5 * worldW && s.y == 0.45 * worldH, isFalse);
    });
  });

  group('landmarkAlphaFor · 亮度', () {
    test('ledger = 0 恒隐（全区域 alpha = 0）', () {
      for (final mood in FlowerMood.values) {
        expect(
          landmarkSpotFor(mood, 0, worldW: worldW, worldH: worldH).alpha,
          0,
          reason: mood.name,
        );
        expect(landmarkAlphaFor(0), 0);
        expect(landmarkAlphaFor(-3), 0);
      }
    });

    test('第一朵花开后即有极淡余温（0.04）', () {
      expect(landmarkAlphaFor(1), 0.04);
    });

    test('计数封顶：达到饱和计数及以上恒为峰值 0.08', () {
      expect(landmarkAlphaFor(10), kLandmarkPeakAlpha);
      expect(landmarkAlphaFor(50), kLandmarkPeakAlpha);
      expect(landmarkAlphaFor(9999), kLandmarkPeakAlpha);
      expect(kLandmarkPeakAlpha, 0.08);
    });

    test('全程按 0.02 步进量化', () {
      for (int n = 1; n <= 9999; n = n * 3 + 1) {
        final a = landmarkAlphaFor(n);
        expect((a * 50) % 1, lessThan(0.0001), reason: 'n=$n');
      }
    });
  });

  group('管线测试 · 账本 0 → N', () {
    test('连续 bump 单区域：亮度单调不回跌且封顶', () {
      var ledger = flowerLedgerNew();
      var prev = 0.0;
      for (int n = 0; n < 60; n++) {
        final a = landmarkSpotFor(
          FlowerMood.wearyHeath,
          ledger[FlowerMood.wearyHeath.index],
          worldW: worldW,
          worldH: worldH,
        ).alpha;
        expect(a, greaterThanOrEqualTo(prev), reason: 'n=$n 回跌');
        expect(a, lessThanOrEqualTo(kLandmarkPeakAlpha));
        prev = a;
        ledger = flowerLedgerBump(ledger, FlowerMood.wearyHeath.index);
      }
      expect(prev, kLandmarkPeakAlpha); // 60 次后早已封顶。
    });

    test('六区域并行 bump：各自的余温亮度独立单调且互不干扰', () {
      var ledger = flowerLedgerNew();
      final prev = List<double>.filled(kFlowerLedgerRegions, 0);
      for (int step = 0; step < 30; step++) {
        for (final mood in FlowerMood.values) {
          final a = landmarkSpotFor(
            mood, ledger[mood.index], worldW: worldW, worldH: worldH,
          ).alpha;
          expect(a, greaterThanOrEqualTo(prev[mood.index]),
              reason: '${mood.name} step=$step 回跌');
          expect(a, lessThanOrEqualTo(kLandmarkPeakAlpha));
          prev[mood.index] = a;
        }
        // 每步给两个不同区域各记一笔（模拟会话内的花开节奏）。
        ledger = flowerLedgerBump(ledger, step % kFlowerLedgerRegions);
        ledger = flowerLedgerBump(ledger, (step + 3) % kFlowerLedgerRegions);
      }
      // 所有区域最终都应到峰值。
      for (final p in prev) {
        expect(p, kLandmarkPeakAlpha);
      }
    });
  });
}
