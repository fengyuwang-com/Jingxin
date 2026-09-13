import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/weary_heath.dart';

/// 第 22 轮配平巡检：疲惫荒原灯台余温衰减的边界行为。
///
/// 原实现在 fuel ∈ (0, 0.08) 衰减时会被 clamp 下界 0.08 顶回
/// （"越放越暖"的微小漂移）；修复后只有达到过余温线的进度才保底。
void main() {
  group('decayBeaconFuel', () {
    test('超过余温线的进度衰减但不低于 0.08', () {
      var fuel = 1.0;
      for (int i = 0; i < 60 * 120; i++) {
        fuel = decayBeaconFuel(fuel, 1 / 60);
      }
      expect(fuel, closeTo(0.08, 1e-9));
    });

    test('微小进度（<0.08）自然冷回 0，不被顶回余温线', () {
      var fuel = 0.03;
      fuel = decayBeaconFuel(fuel, 0.1);
      expect(fuel, lessThan(0.03));
      expect(fuel, greaterThanOrEqualTo(0.0));
      // 足够长的时间后完全冷掉。
      for (int i = 0; i < 60 * 30; i++) {
        fuel = decayBeaconFuel(fuel, 1 / 60);
      }
      expect(fuel, 0.0);
    });

    test('已归零的灯台保持 0，不无中生火', () {
      expect(decayBeaconFuel(0.0, 1.0), 0.0);
    });

    test('恰好处于余温线 0.08 的进度守住不跌', () {
      expect(decayBeaconFuel(0.08, 1.0), 0.08);
    });
  });
}
