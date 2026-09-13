// 呼吸之音（第 44 轮）测试：相位→音高/增益的纯映射 + 开关持久化。
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/breath_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('五声音阶映射', () {
    test('吸气起点取最低音（宫 C4），吸气终点取最高音（羽 A5）', () {
      final start = breathToneFor(phase: 0.0, inhaling: true, steady: true);
      final end = breathToneFor(phase: 1.0, inhaling: true, steady: true);
      expect(start.frequency, kBreathPentatonic.first);
      expect(end.frequency, kBreathPentatonic.last);
    });

    test('吸气全程沿五声音阶单调上行，且每个取音都在表内', () {
      double last = 0;
      for (int i = 0; i <= 100; i++) {
        final tone = breathToneFor(
          phase: i / 100,
          inhaling: true,
          steady: true,
        );
        expect(kBreathPentatonic.contains(tone.frequency), isTrue,
            reason: 'phase=$i/100 频率 ${tone.frequency} 不在五声音阶表内');
        expect(tone.frequency, greaterThanOrEqualTo(last));
        last = tone.frequency;
      }
    });

    test('呼气与吸气镜像：同相位呼气频率 = 吸气在补相位的频率', () {
      for (int i = 0; i <= 100; i++) {
        final p = i / 100;
        final inhale = breathToneFor(phase: p, inhaling: true, steady: true);
        final exhale = breathToneFor(phase: p, inhaling: false, steady: true);
        final mirrored = breathToneFor(
          phase: 1.0 - p, inhaling: true, steady: true);
        expect(
          exhale.frequency,
          mirrored.frequency,
          reason: 'phase=$p：呼气应对称回落到吸气补相位的同一枚音',
        );
      }
    });

    test('端点连续：相位两端增益归零，换向无咔哒', () {
      for (final inhaling in [true, false]) {
        final atZero = breathToneFor(
          phase: 0.0, inhaling: inhaling, steady: true);
        final atOne = breathToneFor(
          phase: 1.0, inhaling: inhaling, steady: true);
        expect(atZero.gain, closeTo(0.0, 1e-9));
        expect(atOne.gain, closeTo(0.0, 1e-9));
      }
      // 中段最亮，且封顶不超过极轻上限。
      final mid = breathToneFor(phase: 0.5, inhaling: true, steady: true);
      expect(mid.gain, closeTo(kBreathToneMaxGain, 1e-9));
    });

    test('增益永远极轻（≤0.06），越界相位被钳制而不炸', () {
      for (final phase in [-0.5, 0.0, 0.25, 0.5, 0.75, 1.0, 1.5]) {
        for (final inhaling in [true, false]) {
          final tone = breathToneFor(
            phase: phase, inhaling: inhaling, steady: true);
          expect(tone.gain, lessThanOrEqualTo(kBreathToneMaxGain));
          expect(tone.gain, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('呼吸紊乱：同一相位用更少的音回应（增益衰减但不刺耳地消失）', () {
      for (int i = 1; i < 100; i++) {
        final p = i / 100;
        final steady =
            breathToneFor(phase: p, inhaling: true, steady: true);
        final unsteady =
            breathToneFor(phase: p, inhaling: true, steady: false);
        expect(unsteady.gain, lessThan(steady.gain));
        expect(
          unsteady.gain,
          closeTo(steady.gain * kBreathUnsteadyGainFactor, 1e-9),
        );
        // 频率不变：只把光调暗，不换旋律。
        expect(unsteady.frequency, steady.frequency);
      }
    });
  });

  group('开关持久化（jingxin.breathsound.v1）', () {
    test('默认关：从未写入时 enabled 为 false', () async {
      SharedPreferences.setMockInitialValues({});
      final pref = BreathSoundPreference();
      await pref.load();
      expect(pref.enabled, isFalse);
    });

    test('开关往返：保存 true/false 后读回一致', () async {
      SharedPreferences.setMockInitialValues({});
      final pref = BreathSoundPreference();
      await pref.load();

      await pref.save(true);
      expect(pref.enabled, isTrue);
      final reopened = BreathSoundPreference();
      await reopened.load();
      expect(reopened.enabled, isTrue);

      await reopened.save(false);
      expect(reopened.enabled, isFalse);
      final again = BreathSoundPreference();
      await again.load();
      expect(again.enabled, isFalse);
    });
  });
}
