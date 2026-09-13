import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jingxin_meditation/game/full_awake.dart';

void main() {
  group('FullAwakeCtl.decide（满醒触发判定）', () {
    test('首次跨过 1.0 且未演过 → 满醒演出', () {
      expect(
        FullAwakeCtl.decide(prev: 0.99, cur: 1.0, playedEver: false),
        FullAwakeDecision.fullShow,
      );
      expect(
        FullAwakeCtl.decide(prev: 0.86, cur: 1.0, playedEver: false),
        FullAwakeDecision.fullShow,
      );
    });

    test('已演过后再次跨过 1.0（含跌破 0.9 再回满）→ 只轻量波纹', () {
      expect(
        FullAwakeCtl.decide(prev: 0.99, cur: 1.0, playedEver: true),
        FullAwakeDecision.lightRipple,
      );
      // 苏醒度回落到 0.9 以下再回满：绝不重演，只有波纹。
      expect(
        FullAwakeCtl.decide(prev: 0.72, cur: 1.0, playedEver: true),
        FullAwakeDecision.lightRipple,
      );
      // 未演过但回落很深再回满：仍是满醒演出（一生一次指"演出"）。
      expect(
        FullAwakeCtl.decide(prev: 0.5, cur: 1.0, playedEver: false),
        FullAwakeDecision.fullShow,
      );
    });

    test('未跨过 1.0 不触发：持续满值、缓慢爬升、回落都不算满值时刻', () {
      expect(
        FullAwakeCtl.decide(prev: 1.0, cur: 1.0, playedEver: false),
        FullAwakeDecision.none,
      );
      expect(
        FullAwakeCtl.decide(prev: 0.4, cur: 0.99, playedEver: false),
        FullAwakeDecision.none,
      );
      expect(
        FullAwakeCtl.decide(prev: 1.0, cur: 0.95, playedEver: true),
        FullAwakeDecision.none,
      );
    });
  });

  group('FullAwakeCtl 记账（跨会话只演一次）', () {
    test('markPlayed 后新实例读到"已演过"，决定从演出降级为波纹', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await FullAwakeCtl.loadPlayed(), isFalse);
      await FullAwakeCtl.markPlayed();
      // 跳过也照打：读回必须为真，且键名固定。
      expect(await FullAwakeCtl.loadPlayed(), isTrue);
      final played = await FullAwakeCtl.loadPlayed();
      expect(
        FullAwakeCtl.decide(prev: 0.99, cur: 1.0, playedEver: played),
        FullAwakeDecision.lightRipple,
      );
    });

    test('存储失败时按未演过处理（宁可多一次回礼）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.${FullAwakeCtl.prefKey}': 42, // 类型错误 → 读取抛异常路径
      });
      expect(await FullAwakeCtl.loadPlayed(), isFalse);
    });
  });

  test('演出节奏常数自洽：光潮单圈收在偈语前、偈语停留 8s、跳过远快于正常淡出', () {
    // 光潮（单圈）在整体淡出前走完；两兽的窗口落在光潮之内。
    expect(FullAwakeEvent.waveStart + FullAwakeEvent.waveDur,
        lessThanOrEqualTo(FullAwakeEvent.fadeStart));
    expect(FullAwakeEvent.beastStart, greaterThanOrEqualTo(1.0));
    expect(FullAwakeEvent.beastStart + FullAwakeEvent.beastDur,
        lessThanOrEqualTo(FullAwakeEvent.waveStart + FullAwakeEvent.waveDur));
    // 偈语：淡入后停留 8s，停留走满即开始整体淡出 5s，总时长约 25s 量级。
    expect(FullAwakeEvent.koanHold, 8.0);
    expect(FullAwakeEvent.fadeStart,
        FullAwakeEvent.koanStart + FullAwakeEvent.koanFade + FullAwakeEvent.koanHold);
    expect(FullAwakeEvent.totalDur, inExclusiveRange(24.0, 30.0));
    // 跳过必须明显快于正常淡出。
    expect(FullAwakeEvent.skipDur, lessThan(FullAwakeEvent.fadeDur / 4));
    // 轻量波纹是极短的收梢，不与演出同量级。
    expect(FullAwakeEvent.rippleDur, lessThan(FullAwakeEvent.skipDur * 5));
  });
}
