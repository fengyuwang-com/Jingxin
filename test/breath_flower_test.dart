// 星花开谢（第 55 轮）纯逻辑测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/breath_flower.dart';

void main() {
  group('flowerBloomDwellNext 累积/退回/循环', () {
    test('平稳呼吸 40s 注满并封顶', () {
      var d = 0.0;
      for (int i = 0; i < 400; i++) {
        d = flowerBloomDwellNext(dwellSeconds: d, dt: 0.1, breathSteady: true);
      }
      expect(d, closeTo(kFlowerBloomSeconds, 1e-9));
      expect(d, lessThanOrEqualTo(kFlowerBloomSeconds));
    });

    test('呼吸不平稳按 1.5/s 退回（精确配平）', () {
      final d = flowerBloomDwellNext(
        dwellSeconds: 20,
        dt: 1.0,
        breathSteady: false,
      );
      expect(d, closeTo(18.5, 1e-9));
    });

    test('退到 0 不越界', () {
      final d = flowerBloomDwellNext(dwellSeconds: 0.5, dt: 5, breathSteady: false);
      expect(d, 0.0);
    });

    test('注满后归零可循环：两次花开间隔约 40s 平稳呼吸', () {
      var d = 0.0;
      int blooms = 0;
      for (int i = 0; i < 1000; i++) {
        final before = d;
        d = flowerBloomDwellNext(dwellSeconds: d, dt: 0.1, breathSteady: true);
        if (before < kFlowerBloomSeconds && d >= kFlowerBloomSeconds) {
          blooms++;
          d = 0; // 循环重置。
        }
      }
      // 100s 内应恰好开 2 次花（40s + 40s，余 20s 不够第三次）。
      expect(blooms, 2);
    });
  });

  group('flowerBloomProgress 映射', () {
    test('端点：0 恒 0，注满且全稳为 1', () {
      expect(
        flowerBloomProgress(steadySecondsAccum: 0, breathSteadiness: 1),
        0,
      );
      expect(
        flowerBloomProgress(
          steadySecondsAccum: kFlowerBloomSeconds,
          breathSteadiness: 1,
        ),
        closeTo(1, 1e-9),
      );
    });

    test('失稳软压低：下限 0.55，绝不瞬跳', () {
      expect(
        flowerBloomProgress(
          steadySecondsAccum: kFlowerBloomSeconds,
          breathSteadiness: 0,
        ),
        closeTo(0.55, 1e-9),
      );
    });

    test('单调不减（固定平稳度）', () {
      double prev = -1;
      for (double a = 0; a <= kFlowerBloomSeconds + 1; a += 1) {
        final p = flowerBloomProgress(
          steadySecondsAccum: a,
          breathSteadiness: 0.8,
        );
        expect(p, greaterThanOrEqualTo(prev));
        prev = p;
      }
    });

    test('平稳度连续变化无跳变', () {
      double prev =
          flowerBloomProgress(steadySecondsAccum: 20, breathSteadiness: 0);
      for (double s = 0; s <= 1.0001; s += 0.05) {
        final p = flowerBloomProgress(
          steadySecondsAccum: 20,
          breathSteadiness: s.clamp(0.0, 1.0),
        );
        expect((p - prev).abs(), lessThan(0.03));
        prev = p;
      }
    });
  });

  group('flowerChaosNext / flowerWitherProgress 花谢曲线', () {
    test('紊乱 12s 完全收拢，端点 0 与 12', () {
      var c = 0.0;
      for (int i = 0; i < 120; i++) {
        c = flowerChaosNext(
          chaoticSeconds: c,
          dt: 0.1,
          chaotic: true,
          breathSteady: false,
        );
      }
      expect(c, closeTo(kFlowerWitherSeconds, 1e-9));
      expect(flowerWitherProgress(chaoticSeconds: c), closeTo(1, 1e-9));
      expect(flowerWitherProgress(chaoticSeconds: 0), 0);
    });

    test('平稳恢复按 0.6/s 缓慢消退（花缓慢重开）', () {
      final c = flowerChaosNext(
        chaoticSeconds: 10,
        dt: 1.0,
        chaotic: false,
        breathSteady: true,
      );
      expect(c, closeTo(9.4, 1e-9));
    });

    test('中间态（不乱不稳）保持不变', () {
      expect(
        flowerChaosNext(
          chaoticSeconds: 5,
          dt: 2.0,
          chaotic: false,
          breathSteady: false,
        ),
        5.0,
      );
    });

    test('花谢曲线连续：25ms 步长跳变 ≤ 0.01', () {
      double prev = flowerWitherProgress(chaoticSeconds: 0);
      for (double t = 0.025; t <= kFlowerWitherSeconds + 0.025; t += 0.025) {
        final w = flowerWitherProgress(chaoticSeconds: t);
        expect((w - prev).abs(), lessThan(0.0101),
            reason: 't=$t 跳变 ${(w - prev).abs()}');
        prev = w;
      }
    });

    test('花谢曲线单调不减且越界钳制', () {
      double prev = -1;
      for (double t = 0; t <= kFlowerWitherSeconds + 5; t += 0.5) {
        final w = flowerWitherProgress(chaoticSeconds: t);
        expect(w, greaterThanOrEqualTo(prev));
        expect(w, lessThanOrEqualTo(1.0));
        prev = w;
      }
    });
  });

  group('flowerVisual 视觉量化', () {
    test('端点：全开全稳全昼 = 张合 1', () {
      final (open, glow) = flowerVisual(1, 0);
      expect(open, 1.0);
      expect(glow, 1.0);
    });

    test('花谢 1 → 张合 0 但芯光不消失（变暗但不消失）', () {
      final (open, glow) = flowerVisual(1, 1);
      expect(open, 0.0);
      expect(glow, closeTo(0.06, 1e-9));
      expect(glow, greaterThan(0));
    });

    test('长夜闭合：night=1 → 张合 0，芯光仍在', () {
      final (open, glow) = flowerVisual(1, 0, night: 1);
      expect(open, 0.0);
      expect(glow, closeTo(0.06, 1e-9));
    });

    test('输出全部按 0.02 步进量化', () {
      for (double b = 0; b <= 1.0001; b += 0.1) {
        for (double w = 0; w <= 1.0001; w += 0.1) {
          final (open, glow) = flowerVisual(b, w);
          for (final v in [open, glow]) {
            expect((v * 50 - (v * 50).round()).abs(), closeTo(0, 1e-6),
                reason: 'b=$b w=$w v=$v');
          }
        }
      }
    });
  });

  group('花池 FIFO 与确定性', () {
    test('槽位取模循环：第 13 朵覆盖第 1 朵（最旧谢幕）', () {
      expect(flowerPoolNextIndex(0), 0);
      expect(flowerPoolNextIndex(11), 11);
      expect(flowerPoolNextIndex(12), 0); // 满 12 后回到最旧槽。
      expect(flowerPoolNextIndex(13), 1);
      expect(flowerPoolNextIndex(24), 0);
    });

    test('花瓣数确定性且在 5..7', () {
      for (int seed = 0; seed < 500; seed++) {
        final p = flowerPetalCount(seed);
        expect(p, inInclusiveRange(5, 7));
        expect(flowerPetalCount(seed), p); // 同 seed 同结果。
      }
    });

    test('花色索引确定性且在 0..2（冷色系三色）', () {
      for (int seed = 0; seed < 500; seed++) {
        final c = flowerColorIndex(seed);
        expect(c, inInclusiveRange(0, 2));
        expect(flowerColorIndex(seed), c);
      }
      // 500 个 seed 至少覆盖全部三色（青/淡紫/月白都有机会出现）。
      final seen = <int>{for (int s = 0; s < 500; s++) flowerColorIndex(s)};
      expect(seen.length, 3);
    });

    test('呼吸张合系数在 0.9..1.0 且相位 0 与 1 同值（连续）', () {
      expect(flowerBreathSway(0), closeTo(flowerBreathSway(1), 1e-9));
      for (double p = 0; p <= 1.0001; p += 0.05) {
        final s = flowerBreathSway(p.clamp(0.0, 1.0));
        expect(s, inInclusiveRange(0.9, 1.0));
      }
    });
  });
}
