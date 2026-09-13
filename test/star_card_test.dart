// 「星图分享卡」（第 35 轮）：纯函数测试——螺旋星点坐标、统计行文案、
// 日期行、输出尺寸常量。离屏渲染本体不做单测（一次性行为）。
import 'dart:math' as math;

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

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
}
