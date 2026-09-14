import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/sea_tide.dart';

void main() {
  group('星潮纯函数（第 60 轮）', () {
    const eps = 1e-9;

    test('确定性：同输入同输出（多点位/多相位扫描）', () {
      for (double x = -2400; x <= 2400; x += 173.0) {
        for (double y = -1800; y <= 1800; y += 211.0) {
          for (double ms = 0; ms <= 60000; ms += 3700.0) {
            expect(seaTideWave(x, y, ms), seaTideWave(x, y, ms));
          }
        }
      }
    });

    test('场强落在 -1..1（全网格扫描）', () {
      for (double x = 0; x < 2400; x += 37.0) {
        for (double y = 0; y < 1800; y += 31.0) {
          for (double ms = 0; ms < 14000; ms += 431.0) {
            final v = seaTideWave(x, y, ms);
            expect(v, inInclusiveRange(-1.0, 1.0),
                reason: 'x=$x y=$y ms=$ms v=$v');
          }
        }
      }
    });

    test('时间连续性：相邻 100ms 采样 |Δ| < 0.05', () {
      for (double x = 0; x < 2400; x += 311.0) {
        for (double y = 0; y < 1800; y += 271.0) {
          var prev = seaTideWave(x, y, 0);
          for (double ms = 100; ms <= 30000; ms += 100) {
            final v = seaTideWave(x, y, ms);
            expect((v - prev).abs(), lessThan(0.05),
                reason: 'x=$x y=$y ms=$ms');
            prev = v;
          }
        }
      }
    });

    test('环面接缝连续：x/y 跨周期边界场强一致', () {
      for (double y = 0; y < 1800; y += 97.0) {
        for (double ms = 0; ms < 30000; ms += 1100.0) {
          expect(
            (seaTideWave(0, y, ms) - seaTideWave(2400, y, ms)).abs(),
            lessThan(1e-6),
          );
        }
      }
      for (double x = 0; x < 2400; x += 97.0) {
        for (double ms = 0; ms < 30000; ms += 1100.0) {
          expect(
            (seaTideWave(x, 0, ms) - seaTideWave(x, 1800, ms)).abs(),
            lessThan(1e-6),
          );
        }
      }
    });

    test('波长 260~420px、周期 9~14s（三组成分，参数确定性固定）', () {
      expect(kSeaTideWaves.length, 3);
      for (final w in kSeaTideWaves) {
        final len = seaTideWavelength(w);
        expect(len, greaterThan(260), reason: '$w');
        expect(len, lessThan(420), reason: '$w');
        expect(w.periodSec, greaterThanOrEqualTo(9.0), reason: '$w');
        expect(w.periodSec, lessThanOrEqualTo(14.0), reason: '$w');
      }
    });

    test('seaTideVisual 端点：场强 0 → alpha 0', () {
      expect(seaTideVisual(0, 0), 0);
      expect(seaTideVisual(0, 1), 0);
    });

    test('seaTideVisual 封顶：不超 0.07，且全部 0.02 量化', () {
      for (double f = -1; f <= 1.001; f += 0.031) {
        for (double s = 0; s <= 1.001; s += 0.1) {
          final a = seaTideVisual(f, s);
          expect(a, lessThanOrEqualTo(0.07 + eps));
          expect(a / 0.02 % 1, closeTo(0, 1e-6), reason: 'f=$f s=$s a=$a');
        }
      }
    });

    test('呼吸响应：平稳（1）幅度舒展 ≥ 紊乱（0）幅度收窄，封顶不变', () {
      // 中等偏强场强处：平稳时更亮（0.02 量化下仍可分辨）。
      final mid = 0.9;
      expect(seaTideVisual(mid, 1.0), greaterThan(seaTideVisual(mid, 0.0)));
      // 中等场强处：量化后至少不更暗。
      expect(seaTideVisual(0.5, 1.0),
          greaterThanOrEqualTo(seaTideVisual(0.5, 0.0)));
      // 满场强时两者都触顶（0.06 量化上限 ≤ 0.07 封顶）。
      final peakS = seaTideVisual(1.0, 1.0);
      final peakU = seaTideVisual(-1.0, 0.0);
      expect(peakS, lessThanOrEqualTo(0.07));
      expect(peakU, lessThanOrEqualTo(0.07));
      // 平稳端点：1×1.0×0.07 → 量化到 0.06。
      expect(peakS, closeTo(0.06, 1e-9));
      // 紊乱端点：0.8 幅度 → 0.056 → 量化 0.04。
      expect(peakU, closeTo(0.04, 1e-9));
      // 紊乱收窄是下限：任意场强下紊乱 alpha ≤ 平稳 alpha。
      for (double f = 0; f <= 1.001; f += 0.017) {
        expect(seaTideVisual(f, 0.0),
            lessThanOrEqualTo(seaTideVisual(f, 1.0) + eps));
      }
    });

    test('seaTideVisual 单调（|field| 增 alpha 不减）', () {
      var prev = 0.0;
      for (double f = 0; f <= 1.001; f += 0.013) {
        final a = seaTideVisual(f, 0.7);
        expect(a, greaterThanOrEqualTo(prev - eps));
        prev = a;
      }
    });

    test('seaTideSway 端点与界内：场强 0 → 0，|sway| ≤ 1.5px', () {
      expect(seaTideSway(0), 0);
      expect(seaTideSway(1), closeTo(1.5, 1e-9));
      expect(seaTideSway(-1), closeTo(-1.5, 1e-9));
      for (double f = -1; f <= 1.001; f += 0.041) {
        expect(seaTideSway(f).abs(), lessThanOrEqualTo(1.5 + eps));
      }
    });

    test('seaTideSway 量化：0.5px 步进', () {
      for (double f = -1; f <= 1.001; f += 0.019) {
        final s = seaTideSway(f);
        expect(s / 0.5 % 1, closeTo(0, 1e-6), reason: 'f=$f s=$s');
      }
    });

    test('seaTideSway 符号随场强、单调不回跌（正侧）', () {
      var prev = 0.0;
      for (double f = 0; f <= 1.001; f += 0.023) {
        final s = seaTideSway(f);
        expect(s, greaterThanOrEqualTo(prev - eps));
        prev = s;
      }
      expect(seaTideSway(0.3), greaterThan(0));
      expect(seaTideSway(-0.3), lessThan(0));
    });

    test('世界周期副本与游戏常量对齐（2400x1800）', () {
      expect(kSeaTideWorldW, 2400);
      expect(kSeaTideWorldH, 1800);
    });
  });
}
