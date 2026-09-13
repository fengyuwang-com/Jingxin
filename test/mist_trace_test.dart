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
}
