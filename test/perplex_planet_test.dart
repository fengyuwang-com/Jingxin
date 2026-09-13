// 惑星（第 43 轮）纯逻辑测试：世界里偶尔飘来的一个心结。
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/perplex_planet.dart';

void main() {
  group('浮现资格 perplexShouldEmerge', () {
    test('全部条件满足才浮现：连续 2 循环 + 满 5 分钟 + 未出现过 + 不被阻塞', () {
      expect(
        perplexShouldEmerge(
          steadyStreak: 2,
          sessionSeconds: 300,
          appearedThisSession: false,
          blocked: false,
        ),
        isTrue,
      );
    });

    test('循环不足 / 会话未满 5 分钟 / 已出现过 / 被演出阻塞，均不浮现', () {
      bool emerg({
        int streak = 2,
        double secs = 300,
        bool appeared = false,
        bool blocked = false,
      }) =>
          perplexShouldEmerge(
            steadyStreak: streak,
            sessionSeconds: secs,
            appearedThisSession: appeared,
            blocked: blocked,
          );
      expect(emerg(streak: 1), isFalse); // 只攒到 1 个平稳循环
      expect(emerg(streak: 0), isFalse);
      expect(emerg(secs: 299.9), isFalse); // 差一点点也不行（=300 整点可）
      expect(emerg(appeared: true), isFalse); // 每会话至多 1 颗
      expect(emerg(blocked: true), isFalse); // 演出期间延后
    });
  });

  group('状态机 PerplexMachine', () {
    PerplexMachine emerged() {
      final m = PerplexMachine()..beginEmerge();
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 8.0);
      return m; // 淡入走满 -> drifting
    }

    test('emerging 极缓淡入，visibility 不超过 1，走满进入 drifting', () {
      final m = PerplexMachine()..beginEmerge();
      expect(m.phase, PerplexPhase.emerging);
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 3.0);
      expect(m.visibility, closeTo(3 / 8, 1e-9));
      expect(m.phase, PerplexPhase.emerging);
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 100.0);
      expect(m.visibility, 1.0);
      expect(m.phase, PerplexPhase.drifting);
    });

    test('hidden 时喂 update 不动；beginEmerge 重复调用不重启', () {
      final m = PerplexMachine();
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 1.0);
      expect(m.phase, PerplexPhase.hidden);
      expect(m.visibility, 0.0);
      m.beginEmerge();
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 8.0);
      m.beginEmerge(); // 不应把 drifting 重置回 emerging
      expect(m.phase, PerplexPhase.drifting);
      expect(m.visibility, 1.0);
    });

    test('靠近 + 平稳 + 3 个平稳循环：松动上升，第 3 循环化解', () {
      final m = emerged();
      for (int i = 0; i < 3; i++) {
        m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      }
      expect(m.nearCycles, 3);
      expect(m.resolved, isTrue);
      expect(m.phase, PerplexPhase.dissolving);
      expect(m.loosen, greaterThan(0));
      // 星花散去后 gone。
      m.update(nearby: true, steady: true, cycleCompleted: false, dt: 2.5);
      expect(m.burst, 1.0);
      expect(m.gone, isTrue);
    });

    test('只 2 个循环就化解不了；但持续靠近松动仍缓慢累积', () {
      final m = emerged();
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      expect(m.resolved, isFalse);
      expect(m.loosen, greaterThan(0));
      expect(m.loosen, lessThan(0.2)); // 极缓：约 50s 才满，4s×2 远不到
    });

    test('呼吸乱了（紊乱持续 2.5s）→ 温柔退出，无奖励', () {
      final m = emerged();
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      // 紊乱：steady=false 连续超过宽限。
      m.update(nearby: true, steady: false, cycleCompleted: false, dt: 1.0);
      m.update(nearby: true, steady: false, cycleCompleted: false, dt: 1.0);
      expect(m.phase, PerplexPhase.drifting); // 2s 还在宽限内
      m.update(nearby: true, steady: false, cycleCompleted: false, dt: 0.6);
      expect(m.phase, PerplexPhase.fading);
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 8.0);
      expect(m.gone, isTrue);
      expect(m.resolved, isFalse); // 没化解就没有惑语与碎片
    });

    test('离开范围（持续 3s）→ 温柔退出，不惩罚', () {
      final m = emerged();
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      m.update(nearby: false, steady: true, cycleCompleted: false, dt: 2.0);
      expect(m.phase, PerplexPhase.drifting);
      m.update(nearby: false, steady: true, cycleCompleted: false, dt: 1.1);
      expect(m.phase, PerplexPhase.fading);
      m.update(nearby: false, steady: true, cycleCompleted: false, dt: 8.0);
      expect(m.gone, isTrue);
    });

    test('短暂漂出（<3s）回来继续，不算离开', () {
      final m = emerged();
      m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      m.update(nearby: false, steady: true, cycleCompleted: false, dt: 2.0);
      m.update(nearby: true, steady: true, cycleCompleted: false, dt: 1.0);
      expect(m.phase, PerplexPhase.drifting);
      // 宽限计时已清零：再离开仍需重新攒满 3s。
      m.update(nearby: false, steady: true, cycleCompleted: false, dt: 2.9);
      expect(m.phase, PerplexPhase.drifting);
    });

    test('化解星花期间迷雾随 burst 收散（visibility 单调降）', () {
      final m = emerged();
      for (int i = 0; i < 3; i++) {
        m.update(nearby: true, steady: true, cycleCompleted: true, dt: 4.0);
      }
      final v0 = m.visibility;
      m.update(nearby: true, steady: true, cycleCompleted: false, dt: 1.25);
      expect(m.visibility, lessThan(v0));
    });
  });

  group('惑语池与索引', () {
    test('池有 3 句且索引轮换稳定', () {
      expect(perplexKoanPool.length, 3);
      expect(perplexKoanIndex(0), 0);
      expect(perplexKoanIndex(1), 1);
      expect(perplexKoanIndex(2), 2);
      expect(perplexKoanIndex(3), 0);
      for (final k in perplexKoanPool) {
        expect(k, isNotEmpty);
      }
    });
  });
}
