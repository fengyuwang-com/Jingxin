// 星兽低语（第 32 轮）纯逻辑测试。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/koans.dart';
import 'package:jingxin_meditation/game/long_night_whisper.dart';

void main() {
  group('BeastWhisperCtl', () {
    test('间隔抖动落在 5~8 分钟内，且不同会话抖动不同', () {
      final a = BeastWhisperCtl(random: math.Random(1));
      final b = BeastWhisperCtl(random: math.Random(999));
      for (int i = 0; i < 200; i++) {
        final t = a.nextInterval();
        expect(t, greaterThanOrEqualTo(BeastWhisperCtl.minIntervalSeconds));
        expect(t, lessThanOrEqualTo(BeastWhisperCtl.maxIntervalSeconds));
      }
      // 不同种子的一组间隔应几乎必然不同（每次会话抖动各不相同）。
      final seqA = List.generate(12, (_) => a.nextInterval());
      final seqB = List.generate(12, (_) => b.nextInterval());
      expect(seqA.join(','), isNot(seqB.join(',')));
    });

    test('安静判定：不满 20s 不低语，满 20s 才低语', () {
      expect(
        BeastWhisperCtl.shouldSpeak(
          quietSecondsNow: 19.9,
          blocked: false,
          spokenCount: 0,
        ),
        isFalse,
      );
      expect(
        BeastWhisperCtl.shouldSpeak(
          quietSecondsNow: 20.0,
          blocked: false,
          spokenCount: 0,
        ),
        isTrue,
      );
    });

    test('演出互斥与每夜限额：blocked 不低语；至多 3 句后彻底安眠', () {
      // 演出进行中（晨光告别/满醒终幕/开场引导）一律不触发。
      expect(
        BeastWhisperCtl.shouldSpeak(
          quietSecondsNow: 100,
          blocked: true,
          spokenCount: 0,
        ),
        isFalse,
      );
      // 每夜至多 3 句：0~2 句可说，3 句后 exhausted。
      final ctl = BeastWhisperCtl(random: math.Random(7));
      ctl.beginNight();
      expect(ctl.exhausted, isFalse);
      for (int i = 0; i < BeastWhisperCtl.maxPerNight; i++) {
        expect(
          BeastWhisperCtl.shouldSpeak(
            quietSecondsNow: 30,
            blocked: false,
            spokenCount: ctl.count,
          ),
          isTrue,
        );
        ctl.record('偈$i');
      }
      expect(ctl.exhausted, isTrue);
      expect(
        BeastWhisperCtl.shouldSpeak(
          quietSecondsNow: 30,
          blocked: false,
          spokenCount: ctl.count,
        ),
        isFalse,
      );
      // 新的一夜重新记账。
      ctl.beginNight();
      expect(ctl.exhausted, isFalse);
    });

    test('偈语去重：近期不重复，整个池抽尽前不回退', () {
      final ctl = BeastWhisperCtl(random: math.Random(3));
      final pool = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛'];
      final seen = <String>{};
      // 连抽 6 句（< 池长 - 队列 4），应互不重复。
      for (int i = 0; i < 6; i++) {
        final k = ctl.pickKoan(pool);
        expect(seen.contains(k), isFalse, reason: '第 $i 次不应重复：$k');
        seen.add(k);
        ctl.record(k);
      }
      // 去重队列只保留最近 4 句。
      expect(ctl.count, 6);
    });

    test('透明度包络：峰值恰为 0.3，两端归零，任意时刻不超峰值', () {
      expect(BeastWhisperCtl.alphaAt(0), 0);
      expect(BeastWhisperCtl.alphaAt(BeastWhisperCtl.showSeconds), 0);
      expect(BeastWhisperCtl.alphaAt(-1), 0);
      expect(BeastWhisperCtl.alphaAt(10), 0);
      expect(
        BeastWhisperCtl.alphaAt(BeastWhisperCtl.showSeconds / 2),
        closeTo(BeastWhisperCtl.peakAlpha, 1e-9),
      );
      for (double t = -2; t <= 12; t += 0.05) {
        expect(BeastWhisperCtl.alphaAt(t), lessThanOrEqualTo(0.3 + 1e-9));
        expect(BeastWhisperCtl.alphaAt(t), greaterThanOrEqualTo(0));
      }
    });

    test('入睡偈语池可被调度器取用且非空', () {
      expect(Koans.whisperPool, isNotEmpty);
      final ctl = BeastWhisperCtl(random: math.Random(5));
      final k = ctl.pickKoan(Koans.whisperPool);
      expect(Koans.whisperPool.contains(k), isTrue);
    });
  });
}
