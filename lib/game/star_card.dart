import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'day_tide.dart';
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

/// ── 预览等比缩放（第 48 轮）────────────────────────────────────
///
/// 「长按带走星图」全屏预览：把分享卡按比例缩进屏幕安全区内。
/// 纯函数、确定性，可单测。

/// 预览时卡片四周保留的最小留白（logical px）。
const double starCardPreviewMargin = 24;

/// 把 [card] 等比缩放进 [screen]（四边各留 [margin]）后的显示尺寸。
/// 永远返回正数尺寸：屏幕或卡片的非法尺寸（≤ 0）时退回卡片原尺寸，
/// 预览层宁可显示原大也不消失。
Size fitCardToScreen(
  Size screen,
  Size card, {
  double margin = starCardPreviewMargin,
}) {
  if (card.width <= 0 || card.height <= 0) return card;
  final availW = screen.width - margin * 2;
  final availH = screen.height - margin * 2;
  if (availW <= 0 || availH <= 0) return card;
  final scale = math.min(
    availW / card.width,
    availH / card.height,
  );
  // 不放大：卡片本来就小的时候按原大显示，克制。
  if (scale >= 1) return card;
  return Size(card.width * scale, card.height * scale);
}

/// ── 预览层「收下」保存（第 49 轮）──────────────────────────────
///
/// 预览层内就地保存这张卡：按钮状态机与文件名皆为纯函数，
/// 确定性可单测。

/// 「收下」小钮的状态：静候 → 保存中 → 已收下 / 失败。
enum CardSavePhase { idle, saving, done, failed }

/// 「收下」小钮收到的事件。
enum CardSaveEvent { start, succeed, fail, reset }

/// 按钮状态机转换（纯函数）：
/// - start：仅 idle / failed 允许进入 saving（saving 期间忽略重复点击，
///   done 态不重启——已收下的卡不必再收一次，reset 归位后再说）；
/// - succeed：仅 saving → done；
/// - fail：仅 saving → failed；
/// - reset：任何状态 → idle（关闭预览 / 确认态计时结束都归位）。
CardSavePhase cardSavePhaseNext(CardSavePhase current, CardSaveEvent event) {
  switch (event) {
    case CardSaveEvent.start:
      return current == CardSavePhase.idle || current == CardSavePhase.failed
          ? CardSavePhase.saving
          : current;
    case CardSaveEvent.succeed:
      return current == CardSavePhase.saving
          ? CardSavePhase.done
          : current;
    case CardSaveEvent.fail:
      return current == CardSavePhase.saving
          ? CardSavePhase.failed
          : current;
    case CardSaveEvent.reset:
      return CardSavePhase.idle;
  }
}

/// 保存文件名：`jingxin-star-map-<日期键>.png`（与「带走星图」入口
/// 同款日期键，yyyy-mm-dd）。碎片数只影响语义上的"这张卡是几星"，
/// 文件名保持稳定格式，便于按天整理。纯函数、确定性。
String saveCardFileName(DateTime now, int shardCount) =>
    'jingxin-star-map-${shardDateKey(now)}.png';

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

/// ── 时辰印记（第 39 轮）────────────────────────────────────────
///
/// 每一张带走的星图都记得它是哪个时辰画的：日期行旁一枚细描边
/// 圆环，环上按生成时刻的昼夜相位放一枚小点——把 24 小时映射到
/// 圆环一周，正午在上（-π/2）、午夜在下（+π/2），与 [DayTide]
/// 的昼夜曲线同源。黄昏时刻小点带极淡暖色。直径约 28px，克制。

/// 时辰印记圆环半径（直径 28px）。
const double tideMarkRingRadius = 14;

/// 环上小点的半径。
const double tideMarkDotRadius = 2;

/// 昼夜相位 → 圆环角度（弧度，屏幕坐标系 y 向下）。
/// 24h 映射到圆环一周：正午在上（-π/2），午夜在下（+π/2），
/// 与时钟反向（午后往左、清晨往右），环过 0:00 环绕连续。
/// 纯函数：tideMarkAngle(720) = -π/2（上），tideMarkAngle(0) = +π/2（下）。
double tideMarkAngle(int minutes) {
  final frac = ((minutes - 720) / 1440) % 1.0;
  return -math.pi / 2 + 2 * math.pi * frac;
}

/// 时辰印记小点在圆环上的位置：[center] 为环心，[radius] 为环半径。
/// 纯函数、确定性。
Offset tideMarkPoint(int minutes, Offset center, double radius) {
  final a = tideMarkAngle(minutes);
  return Offset(
    center.dx + math.cos(a) * radius,
    center.dy + math.sin(a) * radius,
  );
}

/// 时辰印记小点的颜色：日常是极淡的星白，黄昏（17:00–20:30，
/// 与 [DayTide.duskWarmth] 同窗）按暖度混入落日暖色——极淡，
/// 只在点上一瞬的暖意。纯函数。
Color tideMarkDotColor(int minutes) {
  final g = DayTide.duskWarmth(minutes);
  return Color.lerp(ZenTheme.starWhite, DayTide.duskWarmTint, g)!;
}

/// 传统时辰汉字（第 40 轮）：23:00–0:59 子时起，每两小时一时辰，
/// 与 [tideMarkAngle] 的昼夜映射同一时刻来源。纯函数、确定性，
/// 跨午夜安全（23:59 与 0:00 都是「子」）。
String shichenOf(int minutesOfDay) {
  const names = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
  // +60 把子时中点（0:00）对齐到桶中心，再每 120 分钟一桶。
  return names[((minutesOfDay + 60) ~/ 120) % 12];
}

/// 时辰印记汉字位置：圆环左侧一枚极小的字（与环同行对齐）。
Offset shichenTextOffset(Size size) {
  final c = tideMarkCenter(size);
  return Offset(c.dx - tideMarkRingRadius - 10, c.dy);
}

/// 时辰印记环心位置：右下角日期行旁。
Offset tideMarkCenter(Size size) => Offset(size.width - 48, size.height - 58);

/// 满醒金印位置：左下角，与右下的时辰印记对齐。
/// 仅满醒过的玩家可见（卡面另有中央小晨星）。
Offset fullAwakeSealCenter(Size size) => Offset(48, size.height - 58);

/// 印记安全区：任何印记（环 + 点）都必须完整落在卡内、且不越过
/// 边缘出血线 [bleed]。纯函数，用于测试与防御。
bool marksWithinSafeArea(Size size, {double bleed = 12}) {
  final safe = Rect.fromLTRB(
    bleed,
    bleed,
    size.width - bleed,
    size.height - bleed,
  );
  final centers = [
    tideMarkCenter(size),
    fullAwakeSealCenter(size),
  ];
  const reach = tideMarkRingRadius + tideMarkDotRadius;
  return centers.every(
    (c) =>
        c.dx - reach >= safe.left &&
        c.dx + reach <= safe.right &&
        c.dy - reach >= safe.top &&
        c.dy + reach <= safe.bottom,
  );
}

/// 把当前星图渲染成一张离屏分享卡 [ui.Image]
/// （1080×1620 PNG 前身）。UI 线程一次完成，无 isolate。
Future<ui.Image> renderStarCardImage({
  required List<ShardRecord> records,
  required bool fullAwakePlayed,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final now = DateTime.now();
  _StarCardPainter(
    records: records,
    fullAwakePlayed: fullAwakePlayed,
    minutesOfDay: now.hour * 60 + now.minute,
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
  _StarCardPainter({
    required this.records,
    required this.fullAwakePlayed,
    required this.minutesOfDay,
  });

  final List<ShardRecord> records;
  final bool fullAwakePlayed;

  /// 生成时刻（分钟数 0..1439），供时辰印记定位与暖色。
  final int minutesOfDay;

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
            : records[i].region.contains('惑星')
            ? const Color(0xFF9b8fb8) // 惑星（第 43 轮）：灰紫迷雾色。
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

    // 时辰印记（第 39 轮）：右下角日期行旁一枚细描边圆环，
    // 环上按昼夜相位放一枚小点——这一夜是哪个时辰，卡自己记得。
    final ringC = tideMarkCenter(size);
    canvas.drawCircle(
      ringC,
      tideMarkRingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = ZenTheme.textMuted.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      tideMarkPoint(minutesOfDay, ringC, tideMarkRingRadius),
      tideMarkDotRadius,
      Paint()..color = tideMarkDotColor(minutesOfDay).withValues(alpha: 0.75),
    );
    // 时辰汉字（第 40 轮）：环左侧一枚 12px 极小淡字——「子」「午」，
    // 禅意配传统时辰；系统字体，与卡面其余中文同源（第 35 轮已验证）。
    _drawText(
      canvas,
      shichenOf(minutesOfDay),
      shichenTextOffset(size),
      12,
      color: ZenTheme.textMuted.withValues(alpha: 0.60),
      letterSpacing: 0,
    );

    // 满醒金印（第 39 轮）：左下角一枚小金点 + 细环，
    // 与纪念签同款视觉语言；非满醒玩家无此元素。
    if (fullAwakePlayed) {
      final sealC = fullAwakeSealCenter(size);
      canvas.drawCircle(
        sealC,
        tideMarkRingRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = _beastGold.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        sealC,
        2.4,
        Paint()..color = _beastGold.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_StarCardPainter old) =>
      old.fullAwakePlayed != fullAwakePlayed ||
      old.records.length != records.length;
}
