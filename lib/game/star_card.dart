import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'memo_stats.dart';
import 'shard.dart';

/// 「星图分享卡」（第 35 轮）：把玩家的平静星图渲染成一张
/// 1080×1620 的离屏 PNG，带走留念。
///
/// 纯逻辑与绘制都在这里：布局常量、黄金角螺旋星点坐标、
/// 统计行与日期行文案皆为纯函数（可测）；离屏渲染在 UI 线程
/// 一次完成（PictureRecorder → toImage），无性能要求。
///
/// 平台出口（PNG 下载 / 保存）见 `star_card_saver.dart`
/// （条件导入：web 用 anchor download，其余 stub 仅记录）。

/// 分享卡逻辑尺寸（logical px）。实际输出 = 尺寸 × pixelRatio
/// = 540×810 × 2 = 1080×1620。
const Size starCardSize = Size(540, 810);

/// 输出 PNG 的像素倍率：540×810 × 2 = 1080×1620。
const double starCardPixelRatio = 2;

/// 黄金角（与星图屏同款排布：`_starOffset` 一致的确定性螺旋）。
const double starCardGoldenAngle = 2.39996;

/// 第 i 颗星在分享卡画布上的坐标：黄金角螺旋，中心在
/// (宽/2, 高×0.46)，纵向压扁系数 0.82，与星图屏同款气质。
/// 半径封顶（最短边×0.42），碎片再多也始终留在卡内。
/// 纯函数、确定性——同序号永远同位置。
///
/// 第 38 轮压测调整：碎片总数很多时（> 57 枚左右），硬封顶会让
/// 之后的所有星点都挤在半径 = 封顶的同一圈环带上，3000 枚时相邻
/// 星点近到完全重叠。改为「总数感知」的螺旋系数
/// c = min(30, R/√N)：N ≤ 57 时 c 恒为 30（与旧排布完全一致），
/// N 更大时整体收敛为向日葵（Vogel）式均匀盘面，任意两枚星心的
/// 最小间距保持在约 c（3000 枚时 ~4px，星核半径 3.2 互不吞没）。
Offset starCardStarOffset(int index, Size size, {int total = 1}) {
  final angle = index * starCardGoldenAngle;
  final maxRadius = size.shortestSide * 0.42;
  final n = total < 1 ? 1 : total;
  final c = math.min(30.0, maxRadius / math.sqrt(n));
  final radius = math.min(c * math.sqrt(index + 1), maxRadius);
  final cx = size.width / 2;
  final cy = size.height * 0.46;
  return Offset(
    cx + math.cos(angle) * radius,
    cy + math.sin(angle) * radius * 0.82,
  );
}

/// 卡顶小字（克制留白的一行标题）。
const String starCardTitle = '静境 · 我的平静星图';

/// 底部统计行：「已拾 N 枚碎片 · 静了 M 个夜晚」；空星图用温一点的空态。
String starCardStatsLine(List<ShardRecord> records) {
  if (records.isEmpty) return '星图还空着，每一次呼吸都会留下微光';
  return '已拾 ${records.length} 枚碎片 · 静了 ${countNights(records)} 个夜晚';
}

/// 底部日期行：`2026年9月13日`。
String starCardDateLine(DateTime now) =>
    '${now.year}年${now.month}月${now.day}日';

/// 把当前星图渲染成一张离屏分享卡 [ui.Image]
/// （1080×1620 PNG 前身）。UI 线程一次完成，无 isolate。
Future<ui.Image> renderStarCardImage({
  required List<ShardRecord> records,
  required bool fullAwakePlayed,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _StarCardPainter(
    records: records,
    fullAwakePlayed: fullAwakePlayed,
  ).paint(canvas, starCardSize);
  final picture = recorder.endRecording();
  final image = picture.toImage(
    (starCardSize.width * starCardPixelRatio).round(),
    (starCardSize.height * starCardPixelRatio).round(),
  );
  picture.dispose();
  return image;
}

/// 分享卡画笔：深空底色 + 黄金角螺旋星点（区域色相）+ 中央小晨星
/// （满醒过才有）+ 顶部小字 + 底部统计与日期。克制留白，系统字体。
class _StarCardPainter extends CustomPainter {
  _StarCardPainter({required this.records, required this.fullAwakePlayed});

  final List<ShardRecord> records;
  final bool fullAwakePlayed;

  static const Color _beastGold = Color(0xFFe8c473);

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, {
    required Color color,
    double letterSpacing = 2,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          height: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: starCardSize.width - 80);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 深空底色：径向微光，与星图屏同款气质。
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.4),
        size.height * 0.9,
        [ZenTheme.deepSpace, ZenTheme.voidBlack],
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 星点：每枚碎片一枚，区域色相（兽语签 = 星兽金）。
    for (var i = 0; i < records.length; i++) {
      final pos = starCardStarOffset(i, size, total: records.length);
      final color = records[i].region.contains('兽语')
          ? _beastGold
          : regionDotColor(records[i].region);
      // 柔和光晕。
      canvas.drawCircle(
        pos,
        9,
        Paint()..color = color.withValues(alpha: 0.14),
      );
      // 星核。
      canvas.drawCircle(pos, 3.2, Paint()..color = ZenTheme.starWhite);
    }

    // 中央小晨星：满醒过才有一枚金白印记（极小、安静）。
    if (fullAwakePlayed) {
      final c = Offset(size.width / 2, size.height * 0.46);
      canvas.drawCircle(
        c,
        14,
        Paint()..color = _beastGold.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        c,
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = _beastGold.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        c,
        3.5,
        Paint()..color = ZenTheme.starWhite.withValues(alpha: 0.9),
      );
    }

    // 顶部小字。
    _drawText(
      canvas,
      starCardTitle,
      Offset(size.width / 2, 86),
      17,
      color: ZenTheme.starWhite.withValues(alpha: 0.72),
      letterSpacing: 6,
    );

    // 底部统计 + 日期：一行淡字，克制。
    _drawText(
      canvas,
      starCardStatsLine(records),
      Offset(size.width / 2, size.height - 92),
      15,
      color: ZenTheme.textMuted.withValues(alpha: 0.68),
      letterSpacing: 3,
    );
    _drawText(
      canvas,
      starCardDateLine(DateTime.now()),
      Offset(size.width / 2, size.height - 58),
      12,
      color: ZenTheme.textMuted.withValues(alpha: 0.42),
      letterSpacing: 2,
    );
  }

  @override
  bool shouldRepaint(_StarCardPainter old) =>
      old.fullAwakePlayed != fullAwakePlayed ||
      old.records.length != records.length;
}
