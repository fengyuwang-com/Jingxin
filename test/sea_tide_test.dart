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

    test('seaTideVisual 封顶：不超 0.40，且全部 0.02 量化', () {
      for (double f = -1; f <= 1.001; f += 0.031) {
        for (double s = 0; s <= 1.001; s += 0.1) {
          final a = seaTideVisual(f, s);
          expect(a, lessThanOrEqualTo(kSeaTidePeakAlpha + eps));
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
      // 满场强时：平稳触封顶 0.40，紊乱 0.8 倍幅度恰落 0.32 档。
      final peakS = seaTideVisual(1.0, 1.0);
      final peakU = seaTideVisual(-1.0, 0.0);
      expect(peakS, lessThanOrEqualTo(kSeaTidePeakAlpha + eps));
      expect(peakU, lessThanOrEqualTo(kSeaTidePeakAlpha + eps));
      // 平稳端点：1×1.0×0.40 → 量化后恰 0.40（封顶即有效上限）。
      expect(peakS, closeTo(0.40, 1e-9));
      // 紊乱端点：0.8 幅度 → 0.32，仍远在肉眼可见档（≥0.6×平稳）。
      expect(peakU, closeTo(0.32, 1e-9));
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

  group('显性化语义锁（第 68 轮）', () {
    const eps = 1e-9;

    test('① 平稳态峰值 alpha ≥ 0.35（肉眼明显档，目标 0.40）', () {
      final peak = seaTideVisual(1.0, 1.0);
      expect(peak, greaterThanOrEqualTo(0.35));
      expect(peak, closeTo(0.40, eps)); // 恰落 0.02 网格的目标档。
    });

    test('② 紊乱态 ≥ 0.6×平稳态（只略暗不消失；可见档内逐点成立）', () {
      // 满场强端点：0.32 ≥ 0.6×0.40。
      expect(seaTideVisual(1.0, 0.0),
          greaterThanOrEqualTo(0.6 * seaTideVisual(1.0, 1.0) - eps));
      // 全扫描：平稳可见档（≥0.10）内逐点 ≥0.6×（floor 量化不破坏，
      // 设计比 0.8）；近零档本就趋近不可见，允许一个步进松量。
      for (double f = 0; f <= 1.001; f += 0.013) {
        final steady = seaTideVisual(f, 1.0);
        final rough = seaTideVisual(f, 0.0);
        if (steady >= 0.10) {
          expect(rough, greaterThanOrEqualTo(steady * 0.6 - eps),
              reason: 'f=$f steady=$steady rough=$rough');
        } else {
          expect(
            rough,
            greaterThanOrEqualTo(steady * 0.6 - kSeaTideAlphaStep + eps),
            reason: 'f=$f steady=$steady rough=$rough',
          );
        }
      }
    });

    test('③ 全输入域落 0.02 量化网格（floor 取整不放大原值）', () {
      for (double f = -1; f <= 1.001; f += 0.023) {
        for (double s = 0; s <= 1.001; s += 0.07) {
          final a = seaTideVisual(f, s);
          final q = a / kSeaTideAlphaStep;
          expect(q, closeTo(q.roundToDouble(), 1e-6),
              reason: 'f=$f s=$s a=$a');
          final raw =
              f.abs() * (0.8 + 0.2 * s.clamp(0.0, 1.0)) * kSeaTidePeakAlpha;
          expect(a, lessThanOrEqualTo(raw + eps),
              reason: 'f=$f s=$s 量化放大了原值');
        }
      }
    });
  });
}
