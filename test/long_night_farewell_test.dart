import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/long_night_farewell.dart';

/// 第 26 轮：晨光告别触发判定（纯函数）与节奏常数自洽性。
void main() {
  group('LongNightFarewell.shouldBegin', () {
    test('长夜中安静未满阈值：不开始', () {
      expect(
        LongNightFarewell.shouldBegin(idleSeconds: 0, manuallyEnded: false),
        isFalse,
      );
      expect(
        LongNightFarewell.shouldBegin(idleSeconds: 89.9, manuallyEnded: false),
        isFalse,
      );
    });

    test('长夜中安静满 90 秒：开始晨光告别', () {
      expect(
        LongNightFarewell.shouldBegin(idleSeconds: 90, manuallyEnded: false),
        isTrue,
      );
      expect(
        LongNightFarewell.shouldBegin(
          idleSeconds: 3600,
          manuallyEnded: false,
        ),
        isTrue,
      );
    });

    test('明确点了结束长夜：无论闲置多久都立即开始', () {
      expect(
        LongNightFarewell.shouldBegin(idleSeconds: 0, manuallyEnded: true),
        isTrue,
      );
      expect(
        LongNightFarewell.shouldBegin(idleSeconds: 5, manuallyEnded: true),
        isTrue,
      );
    });
  });

  test('节奏常数自洽：声音最后消失，跳过快于任何正常淡出', () {
    // 偈语淡入短于停留（是"停留 10 秒"而非"淡入 10 秒"）。
    expect(LongNightFarewell.koanFadeSeconds, lessThan(LongNightFarewell.koanHoldSeconds));
    // 整体淡出收尾后音频仍在余韵（光先亮，声后歇）。
    expect(
      LongNightFarewell.koanFadeSeconds + LongNightFarewell.koanHoldSeconds + LongNightFarewell.fadeSeconds,
      lessThanOrEqualTo(LongNightFarewell.audioFadeSeconds),
    );
    // 跳过必须明显更快，不突兀。
    expect(LongNightFarewell.skipSeconds, lessThan(LongNightFarewell.koanFadeSeconds));
    // 触发阈值就是 90 秒。
    expect(LongNightFarewell.idleThresholdSeconds, 90);
  });
}
