// 花径——星花连缀成路（第 57 轮）纯函数单测。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/breath_flower.dart';

void main() {
  group('flowerPathAlpha', () {
    test('近处峰值约为 0.09（量化后 0.10）', () {
      final a = flowerPathAlpha(0, 1.0, 1.0);
      expect(a, closeTo(0.10, 0.0001));
      expect(a, lessThanOrEqualTo(kFlowerPathPeakAlpha + 0.02));
    });

    test('开度门槛：任一朵 <= 0.4 恒 0', () {
      expect(flowerPathAlpha(0, 0.4, 1.0), 0);
      expect(flowerPathAlpha(0, 1.0, 0.39), 0);
      expect(flowerPathAlpha(0, 0.2, 0.2), 0);
      expect(flowerPathAlpha(0, 0.55, 0.55), greaterThan(0));
    });

    test('距离衰减：随距离单调下降，220 及以上恒 0', () {
      double prev = 99;
      for (int d = 0; d <= 220; d += 10) {
        final a = flowerPathAlpha(d.toDouble(), 1.0, 1.0);
        expect(a, lessThanOrEqualTo(prev));
        expect((a / kFlowerPathAlphaStep).roundToDouble() *
                kFlowerPathAlphaStep,
            closeTo(a, 1e-9),
            reason: 'dist=$d 未量化到 0.02 步进');
        prev = a;
      }
      expect(flowerPathAlpha(150, 1.0, 1.0), greaterThan(0));
      expect(flowerPathAlpha(220, 1.0, 1.0), 0);
      expect(flowerPathAlpha(500, 1.0, 1.0), 0);
    });

    test('端点收敛：近端 > 0、远端趋 0，且近端明显更亮', () {
      final near = flowerPathAlpha(10, 0.8, 0.8);
      final far = flowerPathAlpha(200, 0.8, 0.8);
      expect(near, greaterThan(0));
      // 远端经 0.02 量化后趋 0，但一定明显比近端淡。
      expect(far, lessThan(near));
    });

    test('收拢淡出：开度越低径线越淡（同步变淡）', () {
      final full = flowerPathAlpha(50, 1.0, 1.0);
      final half = flowerPathAlpha(50, 0.7, 1.0);
      final low = flowerPathAlpha(50, 0.5, 0.5);
      expect(half, lessThan(full));
      expect(low, lessThan(half));
      expect(low, greaterThan(0));
    });

    test('FIFO/花谢谢幕：bloom 归零即径线完全消失', () {
      expect(flowerPathAlpha(30, 0.0, 1.0), 0);
      // 模拟 FIFO 谢幕：开度沿 0.5→0 平滑下落，alpha 只会同步趋 0。
      double prev = 1;
      for (double b = 0.5; b >= 0; b -= 0.05) {
        final a = flowerPathAlpha(30, b, 1.0);
        expect(a, lessThanOrEqualTo(prev + 1e-9));
        prev = a;
      }
      expect(prev, 0);
    });

    test('量化：全距离×全开度组合都落在 0.02 步进上', () {
      for (int d = 0; d <= 260; d += 7) {
        for (double b = 0; b <= 1.001; b += 0.03) {
          final a = flowerPathAlpha(d.toDouble(), b, 1.0 - b * 0.5);
          expect((a / kFlowerPathAlphaStep).roundToDouble() *
                  kFlowerPathAlphaStep,
              closeTo(a, 1e-9),
              reason: 'd=$d b=$b');
          expect(a, lessThanOrEqualTo(0.10));
        }
      }
    });
  });

  group('flowerPathCandidates', () {
    test('只有满足门槛与距离的花对入选，i<j', () {
      final pos = [
        (0.0, 0.0),
        (100.0, 0.0), // 近 → 与 0 成对。
        (1000.0, 0.0), // 远 → 不成对。
      ];
      final bl = [1.0, 1.0, 1.0];
      final out = flowerPathCandidates(pos, bl);
      expect(out, hasLength(1));
      expect(out[0].$1, 0);
      expect(out[0].$2, 1);
      expect(out[0].$3, closeTo(100, 0.001));
    });

    test('开度门槛：任一朵未开花则该对不出现在候选里', () {
      final pos = [(0.0, 0.0), (50.0, 0.0)];
      expect(flowerPathCandidates(pos, [0.4, 1.0]), isEmpty);
      expect(flowerPathCandidates(pos, [0.6, 0.6]), isNotEmpty);
    });

    test('环面 wrap：跨缝的花按最短环绕距离成对', () {
      const period = (2400.0, 1800.0);
      // x 跨缝：2390 与 10 实距 20。
      final outX = flowerPathCandidates([
        (10.0, 900.0),
        (2390.0, 900.0),
      ], [1.0, 1.0], period: period);
      expect(outX, hasLength(1));
      expect(outX[0].$3, closeTo(20, 0.001));
      // y 跨缝：1790 与 10 实距 20。
      final outY = flowerPathCandidates([
        (1200.0, 10.0),
        (1200.0, 1790.0),
      ], [1.0, 1.0], period: period);
      expect(outY, hasLength(1));
      expect(outY[0].$3, closeTo(20, 0.001));
    });

    test('12 朵聚在一起 → 最多 66 对（O(n²) 上限）', () {
      final pos = List<(double, double)>.generate(12, (i) => (i * 10.0, 0));
      final bl = List<double>.filled(12, 1.0);
      final out = flowerPathCandidates(pos, bl);
      expect(out, hasLength(66));
    });

    test('距离字段与逐对复算一致（确定性）', () {
      final pos = <(double, double)>[
        (100.0, 100.0),
        (300.0, 100.0),
        (100.0, 250.0),
      ];
      final bl = [0.9, 0.5, 1.0];
      for (final (i, j, d) in flowerPathCandidates(pos, bl)) {
        final dx = (pos[i].$1 - pos[j].$1).abs();
        final dy = (pos[i].$2 - pos[j].$2).abs();
        final direct =
            math.sqrt(math.pow(dx > 1200 ? 2400 - dx : dx, 2) +
                math.pow(dy > 900 ? 1800 - dy : dy, 2));
        expect(d, closeTo(direct, 0.001));
      }
    });
  });
}
