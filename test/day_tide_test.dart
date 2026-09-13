// 「昼夜潮汐」（第 36 轮）：纯函数测试——正午/黄昏/午夜三段、
// 过零点边界连续性、总 alpha 封顶、长夜让位。
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/day_tide.dart';

int _ch(double v) => (v * 255.0).round().clamp(0, 255);
int _r(Color c) => _ch(c.r);
int _g(Color c) => _ch(c.g);
int _b(Color c) => _ch(c.b);

void main() {
  group('昼夜潮汐 tideTintAt（三段曲线）', () {
    test('正午最亮：暖白提亮，alpha 约 4.5%', () {
      final tide = DayTide.tideTintAt(12 * 60); // 12:00
      expect(DayTide.daylight(720), closeTo(1.0, 1e-9));
      expect(tide.alpha, closeTo(DayTide.noonLift, 1e-9));
      expect(tide.alpha, greaterThan(0.04));
      expect(tide.alpha, lessThan(0.05));
      // 暖白：RGB 全高，且不是冷色。
      expect(_r(tide.color), greaterThan(200));
      expect(_g(tide.color), greaterThan(200));
      expect(_b(tide.color), greaterThan(150));
    });

    test('深夜最沉：深黑蓝压暗，alpha 5% 峰值', () {
      final tide = DayTide.tideTintAt(0); // 00:00
      expect(DayTide.daylight(0), closeTo(-1.0, 1e-9));
      expect(tide.alpha, closeTo(DayTide.midnightSink, 1e-9));
      // 压暗色：极暗且偏蓝（b > r）。
      expect(_r(tide.color), lessThan(20));
      expect(_b(tide.color), greaterThan(_r(tide.color)));
    });

    test('黄昏偏暖：暖度窗峰值 18:45，色相比正午/午夜明显偏红', () {
      expect(DayTide.duskWarmth(1140), closeTo(1.0, 0.03)); // 19:00 邻近峰值
      final dusk = DayTide.tideTintAt(18 * 60 + 45); // 18:45
      final noon = DayTide.tideTintAt(12 * 60);
      final night = DayTide.tideTintAt(0);
      // 无论落在昼侧还是夜侧，黄昏色相都比两端更暖（r-g 差更大）。
      final duskWarmthGap = _r(dusk.color) - _g(dusk.color);
      expect(duskWarmthGap, greaterThan(_r(noon.color) - _g(noon.color)));
      expect(duskWarmthGap, greaterThan(_r(night.color) - _g(night.color)));
      // 黄昏处仍在过渡带，alpha 远小于两端峰值（克制）。
      expect(dusk.alpha, lessThan(0.02));
    });

    test('边界连续性：18:00 过零点两侧 alpha 都趋 0 且差值极小', () {
      final before = DayTide.tideTintAt(17 * 60 + 59);
      final after = DayTide.tideTintAt(18 * 60 + 1);
      expect(before.alpha, lessThan(0.002));
      expect(after.alpha, lessThan(0.002));
      expect((before.alpha - after.alpha).abs(), lessThan(0.002));
      // 6:00 晨光过零点同理趋 0。
      expect(DayTide.tideTintAt(6 * 60).alpha, closeTo(0.0, 1e-9));
      // 环绕连续：23:59 与 00:01 的 daylight 几乎相同。
      expect(
        (DayTide.daylight(23 * 60 + 59) - DayTide.daylight(1)).abs(),
        lessThan(0.005),
      );
    });

    test('总 alpha 封顶：全天任意时刻 ≤ maxAlpha（≤0.06 克制上限）', () {
      for (int m = 0; m < 1440; m += 7) {
        final tide = DayTide.tideTintAt(m);
        expect(tide.alpha, lessThanOrEqualTo(DayTide.maxAlpha));
        expect(tide.alpha, greaterThanOrEqualTo(0.0));
        expect(tide.alpha, lessThanOrEqualTo(0.06));
      }
    });
  });

  group('长夜让位', () {
    test('长夜完全激活时潮汐完全归零；半程平滑让位；不为负', () {
      const base = 0.045;
      expect(DayTide.tideEffectiveAlpha(base, 1.0), 0.0);
      expect(DayTide.tideEffectiveAlpha(base, 0.0), closeTo(base, 1e-9));
      final half = DayTide.tideEffectiveAlpha(base, 0.5);
      expect(half, closeTo(base * 0.5, 1e-9));
      // 越界输入也安全。
      expect(DayTide.tideEffectiveAlpha(base, 2.0), 0.0);
      expect(
        DayTide.tideEffectiveAlpha(base, -1.0),
        closeTo(base, 1e-9),
      );
      // 任何组合都不超过克制上限。
      expect(
        DayTide.tideEffectiveAlpha(DayTide.maxAlpha, 0.0),
        lessThanOrEqualTo(0.06),
      );
    });
  });
}
