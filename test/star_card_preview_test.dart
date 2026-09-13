// 「长按预览」（第 48 轮）：fitCardToScreen 纯函数单测——
// 分享卡等比缩放进屏幕安全区，克制、不放大、永不消失。
import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/star_card.dart';

void main() {
  group('fitCardToScreen（预览等比缩放，第 48 轮）', () {
    test('竖屏手机：按宽度收进留白内，保持 2:3 比例', () {
      // 屏幕 390×844，四边留 24 → 可用 342×796。
      final fit = fitCardToScreen(const Size(390, 844), starCardSize);
      expect(fit.width, closeTo(342, 0.01));
      expect(fit.height, closeTo(342 * 1.5, 0.01)); // 810/540 = 1.5
      expect(fit.height, lessThanOrEqualTo(796));
    });

    test('宽屏矮窗口：按高度收进（宽度远大于需要）', () {
      // 屏幕 1440×900、四边各留 200 → 可用 1040×500，高度是约束边。
      final fit = fitCardToScreen(
        const Size(1440, 900),
        starCardSize,
        margin: 200,
      );
      expect(fit.height, closeTo(500, 0.01));
      expect(fit.width, closeTo(500 / 1.5, 0.01)); // 810/540 = 1.5
    });

    test('不放大：屏幕比卡片还大时按原尺寸显示', () {
      final fit = fitCardToScreen(const Size(1200, 1600), starCardSize);
      expect(fit.width, starCardSize.width);
      expect(fit.height, starCardSize.height);
    });

    test('自定义留白生效', () {
      final fit = fitCardToScreen(
        const Size(588, 858),
        starCardSize,
        margin: 24,
      );
      // 可用 540×810 = 卡片原尺寸 → 不缩放。
      expect(fit.width, starCardSize.width);
      expect(fit.height, starCardSize.height);
      final smaller = fitCardToScreen(
        const Size(588, 858),
        starCardSize,
        margin: 60,
      );
      expect(smaller.width, lessThan(starCardSize.width));
    });

    test('非法/过小屏幕退回卡片原尺寸（预览层宁可原大也不消失）', () {
      expect(fitCardToScreen(Size.zero, starCardSize), starCardSize);
      expect(fitCardToScreen(const Size(10, 10), starCardSize), starCardSize);
      // 非法卡片原样返回。
      expect(fitCardToScreen(const Size(390, 844), Size.zero), Size.zero);
    });

    test('结果是确定性的纯函数：同输入同输出', () {
      final a = fitCardToScreen(const Size(390, 844), starCardSize);
      final b = fitCardToScreen(const Size(390, 844), starCardSize);
      expect(a.width == b.width && a.height == b.height, isTrue);
    });
  });
}
