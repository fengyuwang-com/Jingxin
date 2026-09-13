// 「收下」（第 49 轮）：预览层就地保存的纯逻辑单测——
// 按钮状态机 cardSavePhaseNext 与文件名生成 saveCardFileName。
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/star_card.dart';

void main() {
  group('cardSavePhaseNext（收下按钮状态机，第 49 轮）', () {
    test('start：仅 idle / failed 允许进入 saving', () {
      expect(
        cardSavePhaseNext(CardSavePhase.idle, CardSaveEvent.start),
        CardSavePhase.saving,
      );
      expect(
        cardSavePhaseNext(CardSavePhase.failed, CardSaveEvent.start),
        CardSavePhase.saving,
      );
    });

    test('start：saving 期间重复点击被忽略（防重复提交）', () {
      expect(
        cardSavePhaseNext(CardSavePhase.saving, CardSaveEvent.start),
        CardSavePhase.saving,
      );
    });

    test('start：done 态不重启（已收下不必再收）', () {
      expect(
        cardSavePhaseNext(CardSavePhase.done, CardSaveEvent.start),
        CardSavePhase.done,
      );
    });

    test('succeed：仅 saving → done，其他状态保持不变', () {
      expect(
        cardSavePhaseNext(CardSavePhase.saving, CardSaveEvent.succeed),
        CardSavePhase.done,
      );
      expect(
        cardSavePhaseNext(CardSavePhase.idle, CardSaveEvent.succeed),
        CardSavePhase.idle,
      );
    });

    test('fail：仅 saving → failed，其他状态保持不变', () {
      expect(
        cardSavePhaseNext(CardSavePhase.saving, CardSaveEvent.fail),
        CardSavePhase.failed,
      );
      expect(
        cardSavePhaseNext(CardSavePhase.done, CardSaveEvent.fail),
        CardSavePhase.done,
      );
    });

    test('reset：任何状态一律归位 idle', () {
      for (final phase in CardSavePhase.values) {
        expect(
          cardSavePhaseNext(phase, CardSaveEvent.reset),
          CardSavePhase.idle,
        );
      }
    });

    test('完整生命周期：idle→saving→done→reset，与失败回退', () {
      var phase = CardSavePhase.idle;
      phase = cardSavePhaseNext(phase, CardSaveEvent.start);
      expect(phase, CardSavePhase.saving);
      phase = cardSavePhaseNext(phase, CardSaveEvent.succeed);
      expect(phase, CardSavePhase.done);
      phase = cardSavePhaseNext(phase, CardSaveEvent.reset);
      expect(phase, CardSavePhase.idle);
      // 失败回退：failed 后允许重新 start。
      phase = cardSavePhaseNext(phase, CardSaveEvent.start);
      phase = cardSavePhaseNext(phase, CardSaveEvent.fail);
      expect(phase, CardSavePhase.failed);
      phase = cardSavePhaseNext(phase, CardSaveEvent.start);
      expect(phase, CardSavePhase.saving);
    });
  });

  group('saveCardFileName（保存文件名，第 49 轮）', () {
    test('格式为 jingxin-star-map-yyyy-mm-dd.png（与带走星图同款日期键）', () {
      final name = saveCardFileName(DateTime(2026, 9, 14, 3, 25), 12);
      expect(name, 'jingxin-star-map-2026-09-14.png');
    });

    test('月 / 日补零', () {
      expect(
        saveCardFileName(DateTime(2026, 1, 5), 0),
        'jingxin-star-map-2026-01-05.png',
      );
    });

    test('确定性：同输入永远同输出，且与碎片数无关', () {
      final t = DateTime(2026, 12, 31, 23, 59);
      expect(saveCardFileName(t, 0), saveCardFileName(t, 3000));
      expect(saveCardFileName(t, 7), 'jingxin-star-map-2026-12-31.png');
    });
  });
}
