// 呼吸之音（第 44 轮）测试：相位→音高/增益的纯映射 + 开关持久化。
// 第 45 轮追加：入睡礼让曲线（breathNightFactor）与随息起伏（breathWobbleFactor）。
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

  group('入睡礼让曲线（第 45 轮 breathNightFactor）', () {
    test('非长夜 / 负值 / 刚入夜：系数恒为全量 1.0', () {
      for (final s in [-100.0, 0.0, 1.0, 300.0, 569.0]) {
        expect(breathNightFactor(s), 1.0, reason: 'seconds=$s 应仍是全量');
      }
    });

    test('半档平台：10~20 分钟稳定在 0.6', () {
      // 过渡窗为边界前后各 30 秒，630 之后应完全落到半档。
      for (final s in [630.0, 900.0, 1140.0, 1169.9]) {
        expect(breathNightFactor(s), closeTo(kBreathLullHalfFactor, 1e-9),
            reason: 'seconds=$s 应处于半档平台');
      }
    });

    test('极轻平台：20 分钟后稳定在 0.35', () {
      for (final s in [1230.0, 1800.0, 3600.0, 7200.0]) {
        expect(breathNightFactor(s), closeTo(kBreathLullDeepFactor, 1e-9),
            reason: 'seconds=$s 应处于极轻平台');
      }
    });

    test('边界过渡平滑：60 秒窗内单调滑落、中点恰为半程、两端接平', () {
      // 第一段边界 600s：570 处仍 1.0，630 处已 0.6。
      expect(breathNightFactor(570.0), closeTo(1.0, 1e-9));
      expect(breathNightFactor(600.0), closeTo(0.8, 1e-9)); // smoothstep 半程
      expect(breathNightFactor(630.0), closeTo(0.6, 1e-9));
      // 窗内严格单调下降，且始终夹在两平台之间。
      double prev = 1.0;
      for (int i = 571; i <= 629; i++) {
        final f = breathNightFactor(i.toDouble());
        expect(f, lessThan(prev), reason: 'i=$i 应继续下滑（无回弹）');
        expect(f, lessThan(1.0));
        expect(f, greaterThan(kBreathLullHalfFactor));
        prev = f;
      }
      // 第二段边界 1200s 同样平滑：1170 仍 0.6，1230 已 0.35。
      expect(breathNightFactor(1170.0), closeTo(kBreathLullHalfFactor, 1e-9));
      expect(breathNightFactor(1200.0),
          closeTo((kBreathLullHalfFactor + kBreathLullDeepFactor) / 2, 1e-9));
      expect(breathNightFactor(1230.0), closeTo(kBreathLullDeepFactor, 1e-9));
    });

    test('随息起伏（breathWobbleFactor）：气息满扬起 +15%、歇下收回 -15%', () {
      expect(breathWobbleFactor(1.0), closeTo(1.15, 1e-9));
      expect(breathWobbleFactor(0.0), closeTo(0.85, 1e-9));
      // 中点约定：未开随息时传 0.5 → 恰为 1.0，原档位不变。
      expect(breathWobbleFactor(0.5), closeTo(1.0, 1e-9));
      // 越界钳制，绝不放大到 ±15% 之外。
      expect(breathWobbleFactor(-3.0), closeTo(0.85, 1e-9));
      expect(breathWobbleFactor(7.0), closeTo(1.15, 1e-9));
    });

    test('礼让 × 起伏组合：极轻夜里的音量仍被双重压低且下有地板', () {
      final deepest =
          breathNightFactor(3600.0) * breathWobbleFactor(0.0);
      expect(deepest, closeTo(kBreathLullDeepFactor * 0.85, 1e-9));
      // 任何组合都落在 [极轻×0.85, 全量×1.15] 的温和区间内。
      for (final s in [0.0, 300.0, 600.0, 900.0, 1200.0, 2400.0]) {
        for (final e in [0.0, 0.5, 1.0]) {
          final f = breathNightFactor(s) * breathWobbleFactor(e);
          expect(f, lessThanOrEqualTo(1.15));
          expect(f, greaterThanOrEqualTo(kBreathLullDeepFactor * 0.85 - 1e-9));
        }
      }
    });
  });
}
