import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/jingjing_game.dart';
import '../game/soundscape.dart';
import 'star_map_screen.dart';

/// 静境游戏画面：全屏 Flame GameWidget 展示呼吸光灵，可返回首页。
///
/// 第 2 轮：极简状态呈现——苏醒度以顶端一条极细渐变光线表达
/// （不显示数字，避免"分数感"），吸气/呼气提示词淡入淡出。
class JingjingScreen extends StatefulWidget {
  const JingjingScreen({super.key, this.seedColor = ZenTheme.nebulaCyan});

  final Color seedColor;

  @override
  State<JingjingScreen> createState() => _JingjingScreenState();
}

class _JingjingScreenState extends State<JingjingScreen> {
  late final JingjingGame _game;
  Timer? _koanTimer;

  /// "海之白噪音"声景（Web 合成实现；非 Web 平台静音降级）。
  /// 懒创建：首次进入长夜（用户手势内）才真正初始化 AudioContext。
  SeaSoundscape? _soundscape;

  /// 长夜模式：true 时世界缓缓入夜，白噪音极缓淡入。
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    _game = JingjingGame(seedColor: widget.seedColor);
    _game.shardMessage.addListener(_onShardMessage);
  }

  /// 碎片被吸入：禅语玻璃面板淡入，停留数秒后自行淡出。
  /// 不打断漫游，也不需要玩家做任何操作。
  void _onShardMessage() {
    final koan = _game.shardMessage.value;
    if (koan == null) return;
    _koanTimer?.cancel();
    _game.shardMessage.value = null;
    _showKoan(koan);
  }

  void _showKoan(String koan) {
    setState(() => _koanText = koan);
    _koanTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _koanText = null);
    });
  }

  String? _koanText;

  @override
  void dispose() {
    _game.shardMessage.removeListener(_onShardMessage);
    _koanTimer?.cancel();
    _soundscape?.stop(fadeOut: 1.5);
    _game.awakening.save();
    super.dispose();
  }

  /// 进入/退出长夜：世界渐暗 + 星更亮（game 侧渐变），白噪音淡入淡出。
  /// 首次点击（用户手势）时才创建 AudioContext，规避浏览器自动播放限制。
  Future<void> _toggleNight() async {
    final entering = !_nightMode;
    setState(() => _nightMode = entering);
    _game.setNight(entering);
    if (entering) {
      await _game.longNight.markVisited();
      unawaited(
        (_soundscape ??= SeaSoundscapeImpl()).start(fadeIn: 4.0),
      );
    } else {
      unawaited(_soundscape?.stop(fadeOut: 3.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          // 长夜遮罩：整体缓缓转入深夜色调（更暗），不挡任何操作。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(seconds: 4),
                curve: Curves.easeOut,
                color: _nightMode
                    ? const Color(0xFF02040C).withValues(alpha: 0.42)
                    : const Color(0xFF02040C).withValues(alpha: 0),
              ),
            ),
          ),
          // 顶端极细渐变光线：苏醒度的无声表达。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _game.awakeningValue,
              builder: (context, awakening, _) {
                final glow = (0.15 + 0.85 * awakening).clamp(0.0, 1.0);
                return Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.seedColor.withValues(alpha: 0.1 * glow),
                        widget.seedColor.withValues(alpha: 0.85 * glow),
                        ZenTheme.nebulaPurple.withValues(alpha: 0.85 * glow),
                        widget.seedColor.withValues(alpha: 0.1 * glow),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.seedColor.withValues(alpha: 0.35 * glow),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 呼吸提示词：淡入淡出，随呼吸方向切换。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: ValueListenableBuilder<String?>(
                  valueListenable: _game.breathHint,
                  builder: (context, hint, _) {
                    return AnimatedOpacity(
                      opacity: hint == null ? 0 : 1,
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOut,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 900),
                        child: Text(
                          hint ?? ' ',
                          key: ValueKey(hint),
                          style: TextStyle(
                            color: ZenTheme.textMuted.withValues(alpha: 0.7),
                            fontSize: 15,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // 心镜碎片禅语：玻璃拟态面板，淡入-停留-淡出，不可交互不打断漫游。
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 72),
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _koanText == null ? 0 : 1,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _koanText == null
                        ? const SizedBox.shrink()
                        : _KoanGlassPanel(text: _koanText!),
                  ),
                ),
              ),
            ),
          ),
          // 长夜提示：世界睡了，你也可以睡了。极淡、缓缓浮现。
          Positioned(
            bottom: 86,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _nightMode ? 1 : 0,
                duration: const Duration(seconds: 3),
                curve: Curves.easeOut,
                child: Text(
                  '世界睡了，你也可以睡了',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ZenTheme.textMuted.withValues(alpha: 0.45),
                    fontSize: 13,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),
          ),
          // 右下角极小的月亮入口：长夜的开关，克制如一枚月痕。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: _nightMode ? '退出长夜' : '长夜',
                  icon: Icon(
                    _nightMode ? Icons.nightlight_round : Icons.nightlight_outlined,
                    size: 20,
                    color: ZenTheme.textMuted.withValues(
                      alpha: _nightMode ? 0.85 : 0.5,
                    ),
                  ),
                  onPressed: _toggleNight,
                ),
              ),
            ),
          ),
          // 左下角极小的星图入口：克制、半透明，像风景里的一扇小窗。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: '我的静境星图',
                  icon: Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: ZenTheme.textMuted.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(milliseconds: 800),
                        pageBuilder: (_, _, _) => const StarMapScreen(),
                        transitionsBuilder: (_, animation, _, child) =>
                            FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                              child: child,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: '返回',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: ZenTheme.textMuted,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 禅语玻璃面板：毛玻璃 + 细边微光，呈现碎片上的句子。
class _KoanGlassPanel extends StatelessWidget {
  const _KoanGlassPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: ZenTheme.surfaceDim.withValues(alpha: 0.5),
          border: Border.all(
            color: ZenTheme.nebulaCyan.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ZenTheme.textHigh,
            fontSize: 15,
            height: 1.7,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
