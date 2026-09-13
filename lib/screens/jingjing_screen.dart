import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/jingjing_game.dart';

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

  @override
  void initState() {
    super.initState();
    _game = JingjingGame(seedColor: widget.seedColor);
  }

  @override
  void dispose() {
    _game.awakening.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          Positioned.fill(
            child: GameWidget(game: _game),
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
