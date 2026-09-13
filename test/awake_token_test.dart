import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jingxin_meditation/game/full_awake.dart';

void main() {
  group('满醒纪念签（第 31 轮）', () {
    test('计数向后兼容：无键=1，损坏按无键处理，格式往返一致', () {
      // 无键：老玩家只满醒过一次，不补日期。
      final none = FullAwakeCtl.parseCount(null);
      expect(none.count, 1);
      expect(none.lastDate, isNull);
      expect(none.memorialText, '第 1 次满醒');
      // 损坏内容也按无键兜底。
      expect(FullAwakeCtl.parseCount('abc').count, 1);
      expect(FullAwakeCtl.parseCount('0|20260913').count, 1);
      expect(FullAwakeCtl.parseCount('3|bad').lastDate, isNull);
      // 正常解析 + 文案。
      final c = FullAwakeCtl.parseCount('3|20260913');
      expect(c.count, 3);
      expect(c.lastDate, DateTime(2026, 9, 13));
      expect(c.memorialText, '第 3 次满醒 · 于 9月13日');
      // 编码往返。
      expect(FullAwakeCtl.encodeCount(3, DateTime(2026, 9, 13)), '3|20260913');
    });

    test('满醒记账：首次满醒记 1，已有计数则 +1（多次满醒）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await FullAwakeCtl.bumpCount(DateTime(2026, 9, 13));
      var c = await FullAwakeCtl.loadCount();
      expect(c.count, 1);
      expect(c.lastDate, DateTime(2026, 9, 13));
      // 再次满醒（当前逻辑一生一次，但记账按 +1 通用）。
      await FullAwakeCtl.bumpCount(DateTime(2026, 10, 1));
      c = await FullAwakeCtl.loadCount();
      expect(c.count, 2);
      expect(c.lastDate, DateTime(2026, 10, 1));
      // 存储失败兜底：读不出按 1 次无日期。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jingxin.fullawake.count.v1': 42, // 类型错乱。
      });
      final broken = await FullAwakeCtl.loadCount();
      expect(broken.count, 1);
      expect(broken.lastDate, isNull);
    });

    test('自转：90s 一圈，相位线性可循环', () {
      expect(FullAwakeCtl.tokenAngle(0), 0);
      expect(FullAwakeCtl.tokenAngle(45), closeTo(3.14159, 1e-4));
      expect(FullAwakeCtl.tokenAngle(90), closeTo(2 * 3.14159, 1e-4));
      // 周期首尾同角：视觉上无缝衔接。
      expect(
        FullAwakeCtl.tokenAngle(FullAwakeCtl.tokenSpinPeriod),
        closeTo(FullAwakeCtl.tokenAngle(0) + 2 * 3.14159, 1e-4),
      );
    });

    test('点击冷却：显示中不可点，15s 冷却满后方可再点', () {
      // 小卡显示中：任何时刻都不可点。
      expect(FullAwakeCtl.tokenTapAllowed(showing: true, secondsSinceTap: 99),
          isFalse);
      // 冷却中（自弹卡起算，含 5s 停留）。
      expect(FullAwakeCtl.tokenTapAllowed(showing: false, secondsSinceTap: 0),
          isFalse);
      expect(
        FullAwakeCtl.tokenTapAllowed(showing: false, secondsSinceTap: 14.9),
        isFalse,
      );
      expect(
        FullAwakeCtl.tokenTapAllowed(showing: false, secondsSinceTap: 15.0),
        isTrue,
      );
      // 节奏自洽：冷却大于小卡停留时间，淡出后确有一段静默。
      expect(FullAwakeCtl.tokenCooldown,
          greaterThan(FullAwakeCtl.tokenCardDur));
    });
  });
}
