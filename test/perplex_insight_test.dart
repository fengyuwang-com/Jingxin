// 惑星「通达」（第 52 轮）纯逻辑测试：迷失处的第二次机遇与惑语碎片。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/perplex_insight.dart';
import 'package:jingxin_meditation/game/perplex_planet.dart';

void main() {
  group('驻留推进 perplexInsightDwellNext', () {
    test('近旁且平稳：按 dt 累积，35s 封顶', () {
      var d = 0.0;
      for (int i = 0; i < 60 * 40; i++) {
        d = perplexInsightDwellNext(
          dwellSeconds: d,
          dt: 1 / 60,
          near: true,
          breathSteady: true,
        );
      }
      expect(d, kInsightFillSeconds);
    });

    test('呼吸乱：按 1.2/s 快退（dwell 35 走 10s 恰掉 12）', () {
      var d = 35.0;
      for (int i = 0; i < 600; i++) {
        d = perplexInsightDwellNext(
          dwellSeconds: d,
          dt: 1 / 60,
          near: true,
          breathSteady: false,
        );
      }
      expect(d, closeTo(35 - kInsightBrokenDecayPerSecond * 10, 1e-9));
    });

    test('平稳离开：按 0.35/s 慢退（dwell 35 走 10s 恰掉 3.5）', () {
      var d = 35.0;
      for (int i = 0; i < 600; i++) {
        d = perplexInsightDwellNext(
          dwellSeconds: d,
          dt: 1 / 60,
          near: false,
          breathSteady: true,
        );
      }
      expect(d, closeTo(35 - kInsightLeftDecayPerSecond * 10, 1e-9));
    });

    test('退到 0 不越界（clamp 下限）', () {
      var d = 2.0;
      for (int i = 0; i < 600; i++) {
        d = perplexInsightDwellNext(
          dwellSeconds: d,
          dt: 1 / 60,
          near: false,
          breathSteady: false,
        );
      }
      expect(d, 0.0);
    });
  });

  group('进度映射 perplexInsightProgress', () {
    double prog(double dwell, double s) => perplexInsightProgress(
          dwellSeconds: dwell,
          breathSteadiness: s,
        );

    test('端点：0 驻留恒 0；注满且全平稳 = 1；全失稳压到 0.55', () {
      expect(prog(0, 1), 0);
      expect(prog(kInsightFillSeconds, 1), closeTo(1, 1e-9));
      expect(prog(kInsightFillSeconds, 0), closeTo(0.55, 1e-9));
    });

    test('半程：dwell=17.5、全平稳时 smoothstep 恰为 0.5', () {
      expect(prog(17.5, 1), closeTo(0.5, 1e-9));
    });

    test('单调：dwell 增加进度不减（任意平稳度下）', () {
      for (final s in [0.0, 0.4, 0.8, 1.0]) {
        double prev = -1;
        for (double d = 0; d <= kInsightFillSeconds + 1; d += 0.5) {
          final p = prog(d, s);
          expect(p, greaterThanOrEqualTo(prev));
          expect(p, inInclusiveRange(0, 1));
          prev = p;
        }
      }
    });

    test('连续性：细采样无跳变（相邻差 < 0.01）', () {
      double prev = 0;
      for (double d = 0; d <= kInsightFillSeconds; d += 0.05) {
        final p = prog(d, 0.9);
        expect(p - prev, lessThan(0.01));
        prev = p;
      }
    });
  });

  group('呼吸乱 10s 内掉一半（完整管线模拟）', () {
    // 复刻组件层管线：低通平稳度 + dwell 推进 + progress 映射。
    double simulate(double startDwell, int frames) {
      var dwell = startDwell;
      var steadySm = 1.0;
      var p = perplexInsightProgress(
        dwellSeconds: dwell,
        breathSteadiness: steadySm,
      );
      const dt = 1 / 60;
      for (int i = 0; i < frames; i++) {
        steadySm += (0.0 - steadySm) * math.min(1.0, dt * 0.8);
        dwell = perplexInsightDwellNext(
          dwellSeconds: dwell,
          dt: dt,
          near: true,
          breathSteady: false,
        );
        p = perplexInsightProgress(
          dwellSeconds: dwell,
          breathSteadiness: steadySm,
        );
      }
      return p;
    }

    test('从注满（dwell 35）起，呼吸乱 10s 后 progress < 0.5', () {
      expect(simulate(kInsightFillSeconds, 600), lessThan(0.5));
    });

    test('从接近注满（dwell 28）起，同样成立', () {
      expect(simulate(28.0, 600), lessThan(0.5));
    });
  });

  group('通达触发 PerplexMachine.triggerInsight（至多一次）', () {
    PerplexMachine drifting() {
      final m = PerplexMachine()..beginEmerge();
      m.update(nearby: false, steady: false, cycleCompleted: false, dt: 8.0);
      return m; // visibility=1 -> drifting
    }

    test('drifting 中触发：进入 dissolving 且 resolved，第二次拒绝', () {
      final m = drifting();
      expect(m.triggerInsight(), isTrue);
      expect(m.phase, PerplexPhase.dissolving);
      expect(m.insightDone, isTrue);
      expect(m.resolved, isTrue);
      expect(m.burst, 0);
      expect(m.triggerInsight(), isFalse); // 每颗至多一次
    });

    test('hidden/emerging/fading/gone 阶段拒绝触发', () {
      expect(PerplexMachine().triggerInsight(), isFalse); // hidden
      final e = PerplexMachine()..beginEmerge();
      expect(e.triggerInsight(), isFalse); // emerging
      final g = drifting();
      g.triggerInsight();
      for (int i = 0; i < 400; i++) {
        g.update(nearby: false, steady: false, cycleCompleted: false, dt: 0.05);
      }
      expect(g.gone, isTrue);
      expect(g.triggerInsight(), isFalse); // gone
    });

    test('通达后走完化解：burst 注满 -> gone（状态机天然收尾）', () {
      final m = drifting();
      m.triggerInsight();
      for (int i = 0; i < 400; i++) {
        m.update(nearby: false, steady: false, cycleCompleted: false, dt: 0.05);
      }
      expect(m.gone, isTrue);
      expect(m.visibility, 0);
    });
  });

  group('轮廓微亮 perplexInsightGlow', () {
    test('0.5 以下恒 0，之后平滑上升，注满为 1', () {
      expect(perplexInsightGlow(0), 0);
      expect(perplexInsightGlow(0.49), 0);
      expect(perplexInsightGlow(kInsightGlowThreshold), 0);
      expect(perplexInsightGlow(1), 1);
      expect(perplexInsightGlow(0.75), greaterThan(0));
      expect(perplexInsightGlow(0.75), lessThan(1));
    });

    test('单调不减，输出按 0.04 步进量化', () {
      double prev = 0;
      for (double p = 0; p <= 1.0001; p += 0.01) {
        final g = perplexInsightGlow(p);
        expect(g, greaterThanOrEqualTo(prev));
        // 0.04 步进：值乘 25 应为整数（浮点容差）。
        expect((g * 25) % 1, closeTo(0, 1e-9));
        prev = g;
      }
    });
  });

  group('通达光尘包络 perplexInsightDustEnvelope', () {
    test('两端归零、中间为正、sin 对称', () {
      expect(perplexInsightDustEnvelope(0), 0);
      expect(perplexInsightDustEnvelope(kInsightDustSeconds), 0);
      expect(perplexInsightDustEnvelope(-1), 0);
      expect(perplexInsightDustEnvelope(99), 0);
      final mid = perplexInsightDustEnvelope(kInsightDustSeconds / 2);
      expect(mid, closeTo(1, 1e-9));
      final a = perplexInsightDustEnvelope(0.6);
      final b = perplexInsightDustEnvelope(kInsightDustSeconds - 0.6);
      expect(a, closeTo(b, 1e-9));
    });
  });

  group('惑语短语池与选取', () {
    test('池 6~8 句、全部非空且互不相同', () {
      expect(kInsightPhrases.length, inInclusiveRange(6, 8));
      expect(kInsightPhrases.every((s) => s.trim().isNotEmpty), isTrue);
      expect(kInsightPhrases.toSet().length, kInsightPhrases.length);
    });

    test('15s 内绝不重复上句；超时后自由轮换', () {
      // roll 恰命中上句时换邻位。
      final i = perplexInsightPhraseIndex(2, 2, 5.0);
      expect(i, isNot(2));
      expect(i, 3); // 邻位轮换（确定性）
      // roll 不命中上句时保持 roll。
      expect(perplexInsightPhraseIndex(1, 2, 5.0), 1);
      // 超过 15s：即使命中上句也不回避。
      expect(perplexInsightPhraseIndex(2, 2, 20.0), 2);
    });

    test('选取恒落在池内（任意 roll）', () {
      final rng = math.Random(7);
      for (int i = 0; i < 200; i++) {
        final idx = perplexInsightPhraseIndex(
          rng.nextInt(1000),
          rng.nextInt(kInsightPhrases.length),
          rng.nextDouble() * 100,
        );
        expect(idx, inInclusiveRange(0, kInsightPhrases.length - 1));
      }
    });
  });
}
