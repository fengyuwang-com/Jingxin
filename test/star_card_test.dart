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

  group('时辰汉字 shichenOf（第 40 轮）', () {
    test('跨午夜边界：23:59 与 0:00 都是子时', () {
      expect(shichenOf(0), '子'); // 0:00
      expect(shichenOf(59), '子'); // 0:59
      expect(shichenOf(1380), '子'); // 23:00
      expect(shichenOf(1439), '子'); // 23:59
    });

    test('两小时一档：丑时 1:00–2:59', () {
      expect(shichenOf(60), '丑'); // 1:00
      expect(shichenOf(119), '丑'); // 1:59
      expect(shichenOf(120), '丑'); // 2:00
      expect(shichenOf(179), '丑'); // 2:59
    });

    test('正午属午时（11:00–12:59）', () {
      expect(shichenOf(660), '午'); // 11:00
      expect(shichenOf(720), '午'); // 12:00 正午
      expect(shichenOf(779), '午'); // 12:59
      expect(shichenOf(780), '未'); // 13:00 立刻换未
    });

    test('边界分钟：桶边界两侧各差一分钟换时辰', () {
      expect(shichenOf(179), '丑'); // 2:59 丑
      expect(shichenOf(180), '寅'); // 3:00 寅
      expect(shichenOf(300), '卯'); // 5:00 卯
      expect(shichenOf(299), '寅'); // 4:59 寅
      expect(shichenOf(420), '辰'); // 7:00 辰
      expect(shichenOf(540), '巳'); // 9:00 巳
      expect(shichenOf(900), '申'); // 15:00 申
      expect(shichenOf(1020), '酉'); // 17:00 酉
      expect(shichenOf(1140), '戌'); // 19:00 戌
      expect(shichenOf(1260), '亥'); // 21:00 亥
      expect(shichenOf(1379), '亥'); // 22:59 亥
    });

    test('十二时辰齐备且顺序正确', () {
      // 取每个时辰的中点分钟数采样：0:00, 2:00, 4:00 … 22:00。
      final expected = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
      for (var i = 0; i < 12; i++) {
        expect(shichenOf(i * 120), expected[i], reason: 'mid of hour-pair $i');
      }
    });

    test('汉字位置：在时辰印记圆环左侧、与日期行同高', () {
      final size = starCardSize;
      final off = shichenTextOffset(size);
      final ringC = tideMarkCenter(size);
      expect(off.dy, ringC.dy);
      expect(off.dx, lessThan(ringC.dx));
      expect(off.dx, greaterThan(size.width / 2)); // 仍在右半区，不撞日期行中心
    });

    test('防御：shichenOf 对越界分钟也稳定（负数与超一天）', () {
      expect(shichenOf(-1), shichenOf(1439)); // -1 ≡ 23:59 子
      expect(shichenOf(1440), '子'); // 环绕回子时
      expect(shichenOf(1441), shichenOf(1)); // 顺延
    });
  });
}
