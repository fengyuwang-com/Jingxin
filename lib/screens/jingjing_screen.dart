import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/jingjing_game.dart';
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
    _game.awakening.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
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
