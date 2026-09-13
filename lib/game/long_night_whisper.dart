/// 长夜「星兽低语」（第 32 轮）。
///
/// 理念：长夜里世界不是死的——星兽偶尔极轻地说一句梦话。距玩家
/// 较近的那只星兽身旁浮现一句极淡的入睡偈（复用 koans 入睡池，
/// 近期不重复），alpha 峰值 ≤0.3、8s 缓慢淡入淡出；闻声开启时用
/// 极慢语速轻声念出（复用既有 voice 路径，音量比日常偈语更低）。
///
/// 稀疏感是重点：每隔 5~8 分钟（随机抖动，每次会话不同）且玩家
/// 此刻安静（≥[BeastWhisperCtl.quietSeconds] 无触摸）才低语一次，
/// 每夜（一次长夜会话）至多 [BeastWhisperCtl.maxPerNight] 句，
/// 之后星兽彻底安眠。
///
/// 调度判定（间隔抖动 / 安静判定 / 每夜限额 / 偈语去重 / 透明度
/// 包络）全部抽成纯逻辑，便于测试；触发与朗读由 jingjing_screen
/// 的 UI 层编排，渲染由 [BeastWhisperText] 组件在游戏内呈现。
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Draggable;

import '../core/theme.dart';
import 'jingjing_game.dart';

/// 星兽低语的调度器（纯逻辑，无 IO 无渲染）。
class BeastWhisperCtl {
  BeastWhisperCtl({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  /// 判定"玩家安静"的门槛：≥20 秒无触摸。
  static const double quietSeconds = 20;

  /// 每夜（一次长夜会话）至多低语次数——之后星兽彻底安眠。
  static const int maxPerNight = 3;

  /// 两次低语的最小/最大间隔（秒）：5~8 分钟随机抖动。
  static const double minIntervalSeconds = 300;
  static const double maxIntervalSeconds = 540;

  /// 低语的完整时长（秒）：缓慢淡入淡出一个来回。
  static const double showSeconds = 8;

  /// 低语文字的 alpha 峰值（极淡，只是"感到"）。
  static const double peakAlpha = 0.3;

  /// 触摸打断后的快速淡出时长（秒）。
  static const double dismissSeconds = 0.9;

  /// 近期已展示偈语的去重队列长度。
  static const int recentKeep = 4;

  /// 本夜已低语次数。
  int count = 0;

  final List<String> _recent = [];

  /// 开启一晚：清空计数与去重队列（每个长夜会话各自新鲜）。
  void beginNight() {
    count = 0;
    _recent.clear();
  }

  /// 是否已说满每夜限额。
  bool get exhausted => count >= maxPerNight;

  /// 下一次低语的间隔（秒）：5~8 分钟随机抖动。
  /// 每次会话用不同的 Random（UI 层以时间播种），抖动因夜而异。
  double nextInterval() =>
      minIntervalSeconds +
      _rng.nextDouble() * (maxIntervalSeconds - minIntervalSeconds);

  /// 此刻是否允许低语（纯函数判定）：
  /// - 未被演出互斥（晨光告别 / 满醒终幕 / 开场引导）；
  /// - 未说满每夜限额；
  /// - 玩家此刻安静（无触摸满 [quietSeconds]）。
  static bool shouldSpeak({
    required double quietSecondsNow,
    required bool blocked,
    required int spokenCount,
  }) {
    return !blocked && spokenCount < maxPerNight && quietSecondsNow >= quietSeconds;
  }

  /// 从入睡偈语池挑一句，避开近期已展示的（简单去重队列）。
  /// 全部近期都出现过时回退整池（池远大于队列，实际极难发生）。
  String pickKoan(List<String> pool) {
    final fresh = [
      for (final text in pool)
        if (!_recent.contains(text)) text,
    ];
    final source = fresh.isEmpty ? pool : fresh;
    return source[_rng.nextInt(source.length)];
  }

  /// 记一次低语：计数 +1，偈语入去重队列。
  void record(String text) {
    count++;
    _recent.add(text);
    if (_recent.length > recentKeep) _recent.removeAt(0);
  }

  /// 低语的透明度包络（纯函数）：8s 内 sin 起落，两端归零不闪烁，
  /// 峰值恰为 [peakAlpha]——任何时刻 t 都 ≤ 峰值。
  static double alphaAt(double t) {
    if (t <= 0 || t >= showSeconds) return 0;
    return math.sin(math.pi * t / showSeconds) * peakAlpha;
  }
}

/// 星兽低语的渲染组件：跟随触发时选定的那只星兽（眠或惘），
/// 在其身旁极淡地浮现一句入睡偈，8s 缓慢淡入淡出；任何触摸
/// 立即快速淡出（[dismiss]）。偈语未显示时零渲染成本。
class BeastWhisperText extends Component with HasGameReference<JingjingGame> {
  BeastWhisperText({required this.text, required this.followMist});

  /// 低语内容（入睡偈语池的一句）。
  final String text;

  /// 是否跟随「惘」（雾林守林者）；false 跟随「眠」（失眠之海）。
  final bool followMist;

  double _t = 0;
  bool _dismissed = false;

  TextPainter? _painter;

  /// 触摸打断：进入快速淡出。
  void dismiss() => _dismissed = true;

  @override
  void update(double dt) {
    _t += _dismissed ? dt * (BeastWhisperCtl.showSeconds / BeastWhisperCtl.dismissSeconds) : dt;
    if (_t >= BeastWhisperCtl.showSeconds) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = BeastWhisperCtl.alphaAt(_t);
    if (alpha <= 0.001) return;
    final game = this.game;
    final beast = followMist ? game.mistGuardian.pos : game.beast.pos;

    // 星兽世界坐标 -> 屏幕坐标（与各组件同款的相机换算）。
    final size = game.size;
    final dx = beast.x - game.camPos.x;
    final dy = beast.y - game.camPos.y;
    final center = Offset(
      size.x / 2 + dx,
      size.y / 2 + dy,
    );

    final painter = _painter ??= TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: ZenTheme.starWhite.withValues(alpha: 1),
          fontSize: 13,
          letterSpacing: 5,
          height: 1.8,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x * 0.7);

    // 偈语浮在星兽身旁的上方，极淡——像它梦里咕哝的一句。
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - 92 - painter.height),
    );
  }
}
