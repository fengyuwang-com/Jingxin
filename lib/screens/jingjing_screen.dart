import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/jingjing_game.dart';

/// 静境游戏画面：全屏 Flame GameWidget 展示呼吸光灵，可返回首页。
class JingjingScreen extends StatelessWidget {
  const JingjingScreen({super.key, this.seedColor = ZenTheme.nebulaCyan});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          Positioned.fill(
            child: GameWidget(game: JingjingGame(seedColor: seedColor)),
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
