import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/reunion.dart';

/// 「相会」触发判定的纯函数测试（第 18 轮）。
void main() {
  group('ReunionTrigger.shouldTrigger', () {
    test('四条件齐备才触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: true,
          guardianReveal: 0.9,
          awakening: 0.6,
          spiritToMidpoint: 200,
        ),
        isTrue,
      );
    });

    test('眠不在游弋期不触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: false,
          guardianReveal: 0.9,
          awakening: 0.6,
          spiritToMidpoint: 200,
        ),
        isFalse,
      );
    });

    test('惘未完全显形（<=0.85）不触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: true,
          guardianReveal: 0.85,
          awakening: 0.6,
          spiritToMidpoint: 200,
        ),
        isFalse,
      );
    });

    test('苏醒度不高（<=0.5）不触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: true,
          guardianReveal: 0.9,
          awakening: 0.5,
          spiritToMidpoint: 200,
        ),
        isFalse,
      );
    });

    test('光灵离中点太远（>=260）不触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: true,
          guardianReveal: 0.9,
          awakening: 0.6,
          spiritToMidpoint: 260,
        ),
        isFalse,
      );
    });

    test('边界内极近处可触发', () {
      expect(
        ReunionTrigger.shouldTrigger(
          beastSwimming: true,
          guardianReveal: 0.851,
          awakening: 0.501,
          spiritToMidpoint: 259.9,
        ),
        isTrue,
      );
    });
  });
}
