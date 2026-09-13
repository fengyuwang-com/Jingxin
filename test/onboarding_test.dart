import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/onboarding.dart';

void main() {
  group('OnboardingDirector', () {
    test('未满 3 个循环不谢幕', () {
      final d = OnboardingDirector();
      d.tick(5, 0); // 5 秒，无循环
      d.onCycle();
      d.onCycle();
      d.tick(10, 0);
      expect(d.finished, isFalse);
      expect(d.cycles, 2);
    });

    test('3 个循环即谢幕；60 秒内完成触发提前谢幕（星潮奖励）', () {
      final d = OnboardingDirector();
      d.tick(8, 0); // 8 秒
      d.onCycle();
      d.tick(8, 0); // 16 秒
      d.onCycle();
      d.tick(8, 0); // 24 秒
      d.onCycle();
      expect(d.finished, isTrue);
      expect(d.earlyReward, isTrue, reason: '24s ≤ 60s 窗口');
    });

    test('超过 60 秒才完成 3 个循环：正常谢幕，无星潮奖励', () {
      final d = OnboardingDirector();
      d.tick(30, 0);
      d.onCycle();
      d.tick(30, 0);
      d.onCycle();
      d.tick(30, 0); // 90 秒
      d.onCycle();
      expect(d.finished, isTrue);
      expect(d.earlyReward, isFalse);
    });

    test('cycleCount 跳变一次性补齐且 finished 锁存只触发一次', () {
      final d = OnboardingDirector();
      d.tick(1, 5); // 一次推进中 cycleCount 从 0 跳到 5
      expect(d.cycles, 3, reason: '循环补齐到谢幕所需即止');
      expect(d.finished, isTrue);
      final cyclesAtFinish = d.cycles;
      d.tick(10, 99); // 之后继续推进不再累计
      expect(d.cycles, cyclesAtFinish);
    });

    test('带初始 cycleCount 构造：只统计增量（老会话兼容）', () {
      final d = OnboardingDirector(startCycleCount: 10);
      d.tick(1, 11);
      expect(d.cycles, 1);
      expect(d.finished, isFalse);
    });
  });
}
