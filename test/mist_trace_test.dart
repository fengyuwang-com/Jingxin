// 通达残影（第 53 轮）纯逻辑测试：雾痕 alpha 曲线、呼吸起伏映射、
// 一次性掉落闸门。
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/perplex_insight.dart';

void main() {
  group('雾痕 alpha 曲线 mistTraceAlpha', () {
    test('端点：通达瞬间恰为起步 alpha，淡出结束恒 0', () {
      expect(mistTraceAlpha(0), kMistTraceStartAlpha);
      expect(mistTraceAlpha(kMistTraceFadeMs), 0);
      expect(mistTraceAlpha(kMistTraceFadeMs * 10), 0);
    });

    test('同帧起点漂移容错：负值与 0 同结果', () {
      expect(mistTraceAlpha(-1), kMistTraceStartAlpha);
      expect(mistTraceAlpha(-5000), mistTraceAlpha(0));
    });

    test('单调不回跌', () {
      double prev = mistTraceAlpha(0);
      for (int ms = 0; ms <= kMistTraceFadeMs; ms += 1000) {
        final a = mistTraceAlpha(ms);
        expect(a, lessThanOrEqualTo(prev + 1e-9));
        prev = a;
      }
    });

    test('量化：输出均为 0.02 的整数倍', () {
      for (int ms = 0; ms <= kMistTraceFadeMs; ms += 997) {
        final a = mistTraceAlpha(ms);
        final steps = a / kMistTraceAlphaStep;
        expect((steps - steps.roundToDouble()).abs(), lessThan(1e-9),
            reason: 'ms=$ms alpha=$a');
      }
    });

    test('连续性：相邻采样（50ms 步长）跳变不超过一个量化步', () {
      double prev = mistTraceAlpha(0);
      for (int ms = 50; ms <= kMistTraceFadeMs; ms += 50) {
        final a = mistTraceAlpha(ms);
        expect((prev - a).abs(), lessThanOrEqualTo(kMistTraceAlphaStep + 1e-9),
            reason: 'ms=$ms');
        prev = a;
      }
    });

    test('半程量级：约 3 分钟时 alpha 已明显淡去但未归零', () {
      final half = mistTraceAlpha(kMistTraceFadeMs ~/ 2);
      expect(half, greaterThan(0));
      expect(half, lessThanOrEqualTo(kMistTraceStartAlpha / 2 + kMistTraceAlphaStep));
    });
  });

  group('呼吸起伏映射 mistTraceBreath', () {
    test('端点：alpha 0 恒 0；包络 0 恰返回 alpha 本身', () {
      expect(mistTraceBreath(0, 1), 0);
      expect(mistTraceBreath(0, -1), 0);
      expect(mistTraceBreath(0, 0), 0);
      expect(mistTraceBreath(kMistTraceStartAlpha, 0), kMistTraceStartAlpha);
      expect(mistTraceBreath(0.08, 0), 0.08);
    });

    test('带宽：包络 ±1 时起伏恰为 ±22% 并按 0.02 量化', () {
      final up = mistTraceBreath(kMistTraceStartAlpha, 1);
      final down = mistTraceBreath(kMistTraceStartAlpha, -1);
      expect(up, closeTo(kMistTraceStartAlpha * 1.22, kMistTraceAlphaStep));
      expect(down, closeTo(kMistTraceStartAlpha * 0.78, kMistTraceAlphaStep));
      expect(up, greaterThan(kMistTraceStartAlpha));
      expect(down, lessThan(kMistTraceStartAlpha));
    });

    test('随包络单调不回跌，越界包络被钳制', () {
      double prev = mistTraceBreath(kMistTraceStartAlpha, -1.5);
      for (double e = -1.5; e <= 1.5001; e += 0.05) {
        final v = mistTraceBreath(kMistTraceStartAlpha, e);
        expect(v, greaterThanOrEqualTo(prev - 1e-9));
        prev = v;
      }
      expect(
        mistTraceBreath(kMistTraceStartAlpha, 9),
        mistTraceBreath(kMistTraceStartAlpha, 1),
      );
      expect(
        mistTraceBreath(kMistTraceStartAlpha, -9),
        mistTraceBreath(kMistTraceStartAlpha, -1),
      );
    });

    test('量化：输出均为 0.02 的整数倍', () {
      for (double e = -1.0; e <= 1.0001; e += 0.031) {
        final v = mistTraceBreath(0.12, e);
        final steps = v / kMistTraceAlphaStep;
        expect((steps - steps.roundToDouble()).abs(), lessThan(1e-9));
      }
    });
  });

  group('一次性掉落闸门 mistTraceGrantAllowed', () {
    test('近旁 + 平稳 + 未掉过：允许掉落', () {
      expect(
        mistTraceGrantAllowed(granted: false, near: true, breathSteady: true),
        isTrue,
      );
    });

    test('掉过之后：呼吸再久、再近也不再掉', () {
      expect(
        mistTraceGrantAllowed(granted: true, near: true, breathSteady: true),
        isFalse,
      );
    });

    test('未近旁或呼吸不平稳：不掉落', () {
      expect(
        mistTraceGrantAllowed(granted: false, near: false, breathSteady: true),
        isFalse,
      );
      expect(
        mistTraceGrantAllowed(granted: false, near: true, breathSteady: false),
        isFalse,
      );
    });

    test('闸门翻转后永久保持关闭（一次性语义）', () {
      var granted = false;
      // 前几帧平稳近旁 → 掉落一次。
      if (mistTraceGrantAllowed(
        granted: granted,
        near: true,
        breathSteady: true,
      )) {
        granted = true;
      }
      expect(granted, isTrue);
      // 之后 1000 帧（约 16s）持续平稳近旁：闸门恒关。
      for (int i = 0; i < 1000; i++) {
        expect(
          mistTraceGrantAllowed(
            granted: granted,
            near: true,
            breathSteady: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('雾痕常量', () {
    test('起步 alpha 与量化步进对齐（0.14 = 7 步 × 0.02）', () {
      expect(kMistTraceStartAlpha / kMistTraceAlphaStep, closeTo(7.0, 1e-9));
    });

    test('淡出时长约 6 分钟，偈语与区域非空', () {
      expect(kMistTraceFadeMs, 360000);
      expect(mistTraceShardText, isNotEmpty);
      expect(mistTraceRegion, isNotEmpty);
    });
  });

  group('雾痕道别余光脉冲 mistFarewellPulse（第 54 轮）', () {
    int pulseStartFor(int seed) {
      const windowStart = kMistTraceFadeMs - kMistFarewellWindowMs;
      final h = ((seed & 0xFFFFFFFF) * 2654435761) & 0x7FFFFFFF;
      return windowStart +
          (h / 0x7FFFFFFF * (kMistFarewellWindowMs - kMistFarewellPulseMs))
              .floor();
    }

    test('窗口外恒 0：淡出早段、生命尽头之后均为 0', () {
      const windowStart = kMistTraceFadeMs - kMistFarewellWindowMs;
      for (int ms = 0; ms <= windowStart; ms += 5000) {
        for (final seed in [0, 1, 7, 42, 999]) {
          expect(mistFarewellPulse(ms, seed: seed), 0, reason: 'ms=$ms');
        }
      }
      // 脉冲必在生命尽头之前收束：windowEnd 起恒 0（脉冲最晚在
      // windowEnd 之前一瞬结束），生命尽头之后也恒 0。
      const windowEnd = kMistTraceFadeMs;
      for (int ms = windowEnd; ms <= windowEnd + 60000; ms += 100) {
        for (final seed in [0, 3, 77]) {
          expect(mistFarewellPulse(ms, seed: seed), 0, reason: 'ms=$ms');
        }
      }
    });

    test('确定性：同 seed 同曲线', () {
      for (final seed in [0, 1, 7, 12345]) {
        for (int ms = 0; ms <= kMistTraceFadeMs; ms += 250) {
          expect(mistFarewellPulse(ms, seed: seed),
              mistFarewellPulse(ms, seed: seed), reason: 'seed=$seed ms=$ms');
        }
      }
    });

    test('端点：脉冲起止恰为 0，窗内恰有一次、且仅一段连续非零区间', () {
      for (final seed in [0, 1, 2, 5, 11, 42, 100, 7777]) {
        final s = pulseStartFor(seed);
        expect(mistFarewellPulse(s.toDouble(), seed: seed), 0, reason: 'seed=$seed');
        expect(
            mistFarewellPulse((s + kMistFarewellPulseMs).toDouble(), seed: seed),
            0,
            reason: 'seed=$seed');
        // 全生命周期细采样：非零区间连续且总长恰为一个脉冲窗。
        int nonZeroSamples = 0;
        bool inPulse = false;
        int segments = 0;
        for (int ms = 0; ms <= kMistTraceFadeMs; ms += 10) {
          final v = mistFarewellPulse(ms, seed: seed);
          if (v > 0) {
            nonZeroSamples++;
            if (!inPulse) segments++;
            inPulse = true;
          } else {
            inPulse = false;
          }
        }
        expect(segments, 1, reason: 'seed=$seed 应只闪一次');
        expect(nonZeroSamples, greaterThan(50), reason: 'seed=$seed 脉冲应有实质宽度');
      }
    });

    test('峰值上限：任意 seed 任意时刻 ≤0.10 且为 0.02 的整数倍', () {
      for (int seed = 0; seed < 64; seed++) {
        for (int ms = 0; ms <= kMistTraceFadeMs; ms += 17) {
          final v = mistFarewellPulse(ms, seed: seed);
          expect(v, lessThanOrEqualTo(kMistFarewellPeakAlpha + 1e-9));
          final steps = v / kMistTraceAlphaStep;
          expect((steps - steps.roundToDouble()).abs(), lessThan(1e-9),
              reason: 'seed=$seed ms=$ms');
        }
      }
    });

    test('连续性：窗内相邻采样（25ms 步长）跳变不超过一个量化步', () {
      for (final seed in [0, 9, 321]) {
        final s = pulseStartFor(seed) - 100;
        double prev = 0;
        for (int ms = s; ms <= s + kMistFarewellPulseMs + 200; ms += 25) {
          final v = mistFarewellPulse(ms, seed: seed);
          expect((prev - v).abs(), lessThanOrEqualTo(kMistTraceAlphaStep + 1e-9),
              reason: 'seed=$seed ms=$ms');
          prev = v;
        }
      }
    });

    test('触发时刻确实落在末段窗口内且因 seed 而异（覆盖多种时机）', () {
      final starts = <int>{};
      for (int seed = 0; seed < 32; seed++) {
        // 找首个非零时刻。
        int firstNonZero = -1;
        const searchFrom = kMistTraceFadeMs - kMistFarewellWindowMs;
        for (int ms = searchFrom; ms <= kMistTraceFadeMs; ms += 5) {
          if (mistFarewellPulse(ms, seed: seed) > 0) {
            firstNonZero = ms;
            break;
          }
        }
        expect(firstNonZero, greaterThan(searchFrom), reason: 'seed=$seed');
        expect(firstNonZero,
            lessThanOrEqualTo(kMistTraceFadeMs - kMistFarewellPulseMs + 50),
            reason: 'seed=$seed 脉冲应完整落在生命内');
        starts.add(firstNonZero ~/ 1000);
      }
      // 32 个 seed 至少铺开若干个不同的秒级时机（伪随机散布）。
      expect(starts.length, greaterThanOrEqualTo(8));
    });

    test('常量对齐：峰值恰为 5 个量化步，窗口短于总淡出时长', () {
      expect(kMistFarewellPeakAlpha / kMistTraceAlphaStep, closeTo(5.0, 1e-9));
      expect(kMistFarewellWindowMs, lessThan(kMistTraceFadeMs));
      expect(kMistFarewellPulseMs, lessThan(kMistFarewellWindowMs));
    });
  });
}
