// 「星图分享卡」（第 35 轮）：纯函数测试——螺旋星点坐标、统计行文案、
// 日期行、输出尺寸常量。离屏渲染本体不做单测（一次性行为）。
import 'dart:math' as math;

import 'package:flutter/material.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/core/theme.dart';
import 'package:jingxin_meditation/game/shard.dart';
import 'package:jingxin_meditation/game/star_card.dart';

void main() {
  group('starCardStarOffset（黄金角螺旋）', () {
    test('确定性：同序号永远同坐标，且在画布内', () {
      final size = starCardSize;
      for (var i = 0; i < 200; i++) {
        final a = starCardStarOffset(i, size);
        final b = starCardStarOffset(i, size);
        expect(a, b);
        expect(a.dx, inInclusiveRange(0, size.width));
        expect(a.dy, inInclusiveRange(0, size.height));
      }
    });

    test('第 0 枚在螺旋起点（半径 30），纵轴偏移按 0.82 收缩', () {
      final size = const Size(540, 810);
      final p0 = starCardStarOffset(0, size);
      expect(p0.dx, closeTo(270 + 30 * math.cos(0), 1e-6));
      expect(p0.dy, closeTo(810 * 0.46, 1e-6));
      // 第 1 枚：angle=2.39996，半径 30·√2，纵向偏移已乘 0.82。
      final p1 = starCardStarOffset(1, size);
      final angle = starCardGoldenAngle;
      expect(p1.dx, closeTo(270 + 30 * math.sqrt(2) * math.cos(angle), 1e-6));
      expect(
        p1.dy,
        closeTo(810 * 0.46 + 30 * math.sqrt(2) * math.sin(angle) * 0.82, 1e-6),
      );
    });
  });

  group('分享卡文案', () {
    test('统计行：「已拾 N 枚碎片 · 静了 M 个夜晚」，空图为温柔空态', () {
      expect(
        starCardStatsLine([
          ShardRecord(
            region: '失眠之海',
            text: 'x',
            time: DateTime(2026, 9, 12, 23),
          ),
          ShardRecord(
            region: '失眠之海',
            text: 'y',
            time: DateTime(2026, 9, 13, 1),
          ),
          ShardRecord(
            region: '纷心雾林',
            text: 'z',
            time: DateTime(2026, 9, 13, 2),
          ),
        ]),
        '已拾 3 枚碎片 · 静了 2 个夜晚',
      );
      expect(starCardStatsLine(const []), '星图还空着，每一次呼吸都会留下微光');
    });

    test('日期行：yyyy年M月d日（不补零）', () {
      expect(starCardDateLine(DateTime(2026, 9, 13)), '2026年9月13日');
      expect(starCardDateLine(DateTime(2027, 1, 2)), '2027年1月2日');
    });
  });

  test('输出尺寸常量：540×810 × 2 = 1080×1620 PNG', () {
    expect(starCardPixelRatio, 2);
    expect((starCardSize.width * starCardPixelRatio).round(), 1080);
    expect((starCardSize.height * starCardPixelRatio).round(), 1620);
  });

  group('时辰印记与满醒金印（第 39 轮）', () {
    test('角度映射：正午在上（-π/2），午夜在下（+π/2），环绕连续', () {
      expect(tideMarkAngle(720), closeTo(-math.pi / 2, 1e-9)); // 12:00 上
      expect(tideMarkAngle(0), closeTo(math.pi / 2, 1e-9)); // 0:00 下
      // 环绕：23:59:59 与 0:00 的角度只差一分钟弧长，无跳变。
      final a = tideMarkAngle(1439);
      final b = tideMarkAngle(0);
      var diff = (a - b).abs() % (2 * math.pi);
      if (diff > math.pi) diff = 2 * math.pi - diff;
      expect(diff, closeTo(2 * math.pi / 1440, 1e-9));
      // 点的位置随角度落在环上。
      const c = Offset(100, 100);
      final noon = tideMarkPoint(720, c, tideMarkRingRadius);
      expect(noon.dy, lessThan(c.dy)); // 正午点在环心上方
      expect(noon.dx, closeTo(c.dx, 1e-9));
      final midnight = tideMarkPoint(0, c, tideMarkRingRadius);
      expect(midnight.dy, greaterThan(c.dy)); // 午夜点在环心下方
      expect(midnight.dx, closeTo(c.dx, 1e-9));
    });

    test('黄昏暖色：18:45 峰值偏暖，正午是中性星白', () {
      final noon = tideMarkDotColor(720);
      final dusk = tideMarkDotColor(18 * 60 + 45); // 18:45 峰值
      final night = tideMarkDotColor(0);
      // 正午 / 深夜都是星白（无暖混）。
      expect(noon, ZenTheme.starWhite);
      expect(night, ZenTheme.starWhite);
      // 黄昏：红分量抬升、蓝分量压低（暖色方向）。
      expect(dusk.r, greaterThan(dusk.b));
      expect(dusk.r, lessThan(1.0));
    });

    test('印记位置：时辰印记在右下、满醒金印在左下，与日期行对齐', () {
      final size = starCardSize;
      final tideC = tideMarkCenter(size);
      expect(tideC.dx, greaterThan(size.width / 2));
      expect(tideC.dy, closeTo(size.height - 58, 1e-9)); // 与日期行同一行
      final sealC = fullAwakeSealCenter(size);
      expect(sealC.dx, lessThan(size.width / 2));
      expect(sealC.dy, tideC.dy); // 左右对称对齐
    });

    test('两枚印记都在出血区内（边缘留白 ≥ 12px）', () {
      expect(marksWithinSafeArea(starCardSize), isTrue);
      // 防御性：极端窄卡也应报告越界而非悄悄出血。
      expect(marksWithinSafeArea(const Size(70, 70)), isFalse);
    });
  });
}
