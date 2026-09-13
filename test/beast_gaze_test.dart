import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/beast_gaze.dart';

void main() {
  group('beastGazeProgress 纯映射', () {
    test('星兽未半醒（<0.5）恒为 0，无论驻留与平稳度', () {
      expect(
        beastGazeProgress(
            dwellSeconds: 45, breathSteadiness: 1, beastAwakening: 0.49),
        0,
      );
      expect(
        beastGazeProgress(
            dwellSeconds: 45, breathSteadiness: 1, beastAwakening: 0),
        0,
      );
    });

    test('端点：dwell=0 → 0；dwell 注满 → 1', () {
      expect(
        beastGazeProgress(
            dwellSeconds: 0, breathSteadiness: 1, beastAwakening: 0.6),
        0,
      );
      expect(
        beastGazeProgress(
            dwellSeconds: kGazeFillSeconds, breathSteadiness: 1,
            beastAwakening: 0.6),
        closeTo(1.0, 1e-9),
      );
    });

    test('半程：dwell 注满一半时进度恰为 0.5（smoothstep 中点）', () {
      expect(
        beastGazeProgress(
            dwellSeconds: kGazeFillSeconds / 2, breathSteadiness: 1,
            beastAwakening: 0.6),
        closeTo(0.5, 1e-9),
      );
    });

    test('单调：dwell 递增进度不回跌（平稳、已半醒）', () {
      double prev = -1;
      for (double d = 0; d <= kGazeFillSeconds + 5; d += 1) {
        final p = beastGazeProgress(
            dwellSeconds: d, breathSteadiness: 1, beastAwakening: 0.6);
        expect(p, greaterThanOrEqualTo(prev));
        expect(p, inInclusiveRange(0, 1));
        prev = p;
      }
    });

    test('连续性：细采样相邻差极小，无跳变', () {
      double prev = 0;
      for (double d = 0; d <= kGazeFillSeconds; d += 0.25) {
        final p = beastGazeProgress(
            dwellSeconds: d, breathSteadiness: 1, beastAwakening: 0.6);
        expect((p - prev).abs(), lessThan(0.02));
        prev = p;
      }
    });

    test('失稳软压低：平稳度连续时输出连续，绝不瞬跳到 0', () {
      double prev = beastGazeProgress(
          dwellSeconds: kGazeFillSeconds, breathSteadiness: 1,
          beastAwakening: 0.6);
      for (double s = 1; s >= 0; s -= 0.05) {
        final p = beastGazeProgress(
            dwellSeconds: kGazeFillSeconds, breathSteadiness: s,
            beastAwakening: 0.6);
        expect((p - prev).abs(), lessThan(0.03));
        prev = p;
      }
      // 完全失稳仍有保留（0.55 下限附近），不是硬归零。
      expect(prev, closeTo(0.55, 0.03));
    });
  });

  group('beastGazeDwellNext 推进', () {
    test('近旁 + 平稳：按秒累积，注满后封顶', () {
      var d = 0.0;
      for (int i = 0; i < 50; i++) {
        d = beastGazeDwellNext(
            dwellSeconds: d, dt: 1, near: true, breathSteady: true,
            beastAwakening: 0.6);
      }
      expect(d, kGazeFillSeconds);
    });

    test('未半醒：无论什么条件一律归零（永为 0）', () {
      expect(
        beastGazeDwellNext(
            dwellSeconds: 40, dt: 0.016, near: true, breathSteady: true,
            beastAwakening: 0.3),
        0,
      );
    });
  });

  group('退回速度（手感量化）', () {
    // 完整管线模拟：ctl.update 逐帧喂条件，验证真实手感。
    BeastGazeCtl runSeconds(
      double startDwell,
      int seconds, {
      required bool near,
      required bool steady,
      double awakening = 0.6,
    }) {
      final ctl = BeastGazeCtl()
        ..dwell = startDwell;
      for (int i = 0; i < seconds * 60; i++) {
        ctl.update(
          dt: 1 / 60,
          near: near,
          breathSteady: steady,
          beastAwakening: awakening,
        );
      }
      return ctl;
    }

    test('呼吸乱：8s 内注视进度至少掉一半（多个起点）', () {
      for (final start in [kGazeFillSeconds, 34.0, kGazeFillSeconds / 2]) {
        final before = beastGazeProgress(
            dwellSeconds: start, breathSteadiness: 1, beastAwakening: 0.6);
        final ctl = runSeconds(start, 8, near: true, steady: false);
        expect(ctl.progress, lessThanOrEqualTo(before / 2),
            reason: 'start dwell=$start: ${ctl.progress} vs $before/2');
      }
    });

    test('平稳离开：10s 内 gaze 几乎不跌（退得慢）', () {
      final ctl = runSeconds(kGazeFillSeconds, 10, near: false, steady: true);
      expect(ctl.progress, greaterThan(0.8));
    });

    test('恢复：重新平稳靠近后从中断处继续累积（不归零重来）', () {
      final ctl = runSeconds(kGazeFillSeconds, 8, near: true, steady: false);
      final afterBreak = ctl.progress;
      for (int i = 0; i < 2 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      expect(ctl.progress, greaterThan(afterBreak));
      expect(ctl.dwell, greaterThan(0));
    });

    test('跨越条件切换时显示连续（失稳瞬间无跳变）', () {
      final ctl = BeastGazeCtl();
      for (int i = 0; i < 30 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      final before = ctl.progress;
      ctl.update(
          dt: 1 / 60, near: true, breathSteady: false, beastAwakening: 0.6);
      expect((ctl.progress - before).abs(), lessThan(0.02));
    });
  });

  group('注视脉冲与低语调度', () {
    test('progress 越过 0.55 触发脉冲，每夜至多 2 次', () {
      final ctl = BeastGazeCtl();
      var pulses = 0;
      var prevEnv = 0.0;
      for (int i = 0; i < 60 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
        if (prevEnv == 0 && ctl.pulseEnvelope > 0) pulses++;
        prevEnv = ctl.pulseEnvelope;
      }
      expect(pulses, 1); // 一次注满只自下而上越过阈值一次
      expect(ctl.pulsesThisNight, 1);
    });

    test('脉冲包络：3.5s 自然消散，两端归零、峰值 1', () {
      expect(beastGazePulseEnvelope(0), 0);
      expect(beastGazePulseEnvelope(kGazePulseSeconds), 0);
      expect(
        beastGazePulseEnvelope(kGazePulseSeconds / 2),
        closeTo(1.0, 1e-9),
      );
    });

    test('beginNight 重置每夜脉冲计数', () {
      final ctl = BeastGazeCtl();
      for (int i = 0; i < 60 * 50; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      expect(ctl.pulsesThisNight, greaterThanOrEqualTo(1));
      ctl.beginNight();
      expect(ctl.pulsesThisNight, 0);
    });

    test('注满低语：一次注满至多一句，冷却 2 分钟内不再请求', () {
      final ctl = BeastGazeCtl();
      for (int i = 0; i < 60 * 50; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      expect(ctl.consumeWhisperRequest(), true);
      expect(ctl.consumeWhisperRequest(), false);
      // 继续驻留 90s（<120s 冷却）：不应再有低语请求。
      for (int i = 0; i < 90 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      expect(ctl.consumeWhisperRequest(), false);
      // 掉回 0.9 以下再注满（此处直接打破又恢复）后可再请求。
      for (int i = 0; i < 8 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: false, beastAwakening: 0.6);
      }
      for (int i = 0; i < 130 * 60; i++) {
        ctl.update(
            dt: 1 / 60, near: true, breathSteady: true, beastAwakening: 0.6);
      }
      expect(ctl.consumeWhisperRequest(), true);
    });
  });

  group('beastGazeVisual 视觉映射', () {
    test('端点与单调', () {
      expect(beastGazeVisual(0), 0);
      expect(beastGazeVisual(1), closeTo(1.0, 1e-9));
      double prev = -1;
      for (double p = 0; p <= 1.001; p += 0.01) {
        final v = beastGazeVisual(p);
        expect(v, greaterThanOrEqualTo(prev));
        expect(v, inInclusiveRange(0, 1));
        // 量化：0.02 步进（浮点容差）。
        expect((v * 50 - (v * 50).round()).abs(), lessThan(1e-9));
        prev = v;
      }
    });

    test('越界钳制', () {
      expect(beastGazeVisual(-0.5), 0);
      expect(beastGazeVisual(1.5), closeTo(1.0, 1e-9));
    });
  });

  test('低语池非空且无空串（组件按索引轮换取用，确定性）', () {
    expect(kGazeWhispers, isNotEmpty);
    for (final w in kGazeWhispers) {
      expect(w.trim(), isNotEmpty);
    }
  });
}
