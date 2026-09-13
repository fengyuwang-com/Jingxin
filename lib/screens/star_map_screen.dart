import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/shard.dart';
import '../game/star_beast.dart';

/// 「我的静境星图」——静境星图回看（第 4 轮）。
///
/// 收集到的每一片心镜碎片化为一颗星，按收集时间以黄金角螺旋排布，
/// 呈现为一片属于个人的星座（是风景，不是列表，没有计数）。
/// 点一颗星，浮现那晚的偈语与日期。玻璃拟态、克制、无分数感。
class StarMapScreen extends StatefulWidget {
  const StarMapScreen({super.key, this.onSpeakKoan});

  /// 「闻声」（第 12 轮）：点星时轻声读出那句偈语的可选回调。
  /// 由调用方传入（仅当用户开启了朗读）；null 则完全静默。
  final void Function(String koan)? onSpeakKoan;

  @override
  State<StarMapScreen> createState() => _StarMapScreenState();
}

class _StarMapScreenState extends State<StarMapScreen> {
  final ShardCollection _collection = ShardCollection();
  final StarBeastState _beastState = StarBeastState();
  List<ShardRecord> _records = [];
  int _beastEyes = 0;
  bool _beastSwimming = false;
  ShardRecord? _selected;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _collection.load();
    await _beastState.load();
    if (!mounted) return;
    setState(() {
      _records = List<ShardRecord>.of(_collection.records);
      _beastEyes = _beastState.openedEyes;
      _beastSwimming = _beastState.swimming;
      _loaded = true;
    });
  }

  /// 黄金角螺旋：第 i 颗星的角度与半径（确定性排布，按收集顺序）。
  static Offset _starOffset(int index, Size size) {
    const goldenAngle = 2.39996;
    final angle = index * goldenAngle;
    final radius = 26.0 * math.sqrt(index + 1);
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    return Offset(
      cx + math.cos(angle) * radius,
      cy + math.sin(angle) * radius * 0.82,
    );
  }

  String _formatDate(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$m月$d日 $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          // 深空底色微光。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.2,
                  colors: [ZenTheme.deepSpace, ZenTheme.voidBlack],
                ),
              ),
            ),
          ),
          // 星座画布。
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (!_loaded) {
                  return const SizedBox.shrink();
                }
                if (_records.isEmpty) {
                  return Center(
                    child: Text(
                      '星图尚在沉睡……\n当光灵在漫游中轻轻拾起心镜碎片，\n这里会亮起第一颗星。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ZenTheme.textMuted.withValues(alpha: 0.55),
                        fontSize: 14,
                        height: 2,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    for (int i = 0; i < _records.length; i++)
                      _buildStar(i, size),
                  ],
                );
              },
            ),
          ),
          // 标题。
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Text(
                  '我的静境星图',
                  style: TextStyle(
                    color: ZenTheme.starWhite.withValues(alpha: 0.8),
                    fontSize: 16,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
          // 点选碎片后浮现的偈语玻璃卡。
          if (_selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: _KoanCard(
                    text: _selected!.text,
                    date: _formatDate(_selected!.time),
                    region: _selected!.region,
                  ),
                ),
              ),
            ),
          // 海深处极淡的一行：星兽苏醒的隐约线索（无数字、无进度）。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Text(
                  StarBeastState.whisper(
                    _beastEyes,
                    isSwimming: _beastSwimming,
                  ),
                  style: TextStyle(
                    color: ZenTheme.textMuted.withValues(alpha: 0.32),
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
          // 返回。
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

  Widget _buildStar(int index, Size size) {
    final pos = _starOffset(index, size);
    final rec = _records[index];
    final isSelected = identical(_selected, rec);
    final twinklePhase = index * 1.7;
    return Positioned(
      left: pos.dx - 24,
      top: pos.dy - 24,
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selected = rec);
          // 点星轻声读一句（可选、克制）：每次进入星图最多读点过的那句。
          widget.onSpeakKoan?.call(rec.text);
        },
        child: Center(
          child: _StarWidget(phase: twinklePhase, selected: isSelected),
        ),
      ),
    );
  }
}

/// 单颗星：柔和光点 + 微呼吸闪烁；选中时泛起青紫光环。
class _StarWidget extends StatefulWidget {
  const _StarWidget({required this.phase, required this.selected});

  final double phase;
  final bool selected;

  @override
  State<_StarWidget> createState() => _StarWidgetState();
}

class _StarWidgetState extends State<_StarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tw =
            0.5 +
            0.5 * math.sin(_controller.value * 2 * math.pi + widget.phase);
        final glowColor = widget.selected
            ? ZenTheme.nebulaPurple
            : ZenTheme.nebulaCyan;
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.10 + 0.22 * tw),
                blurRadius: widget.selected ? 18 : 10,
                spreadRadius: widget.selected ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.selected ? 7 : 5,
              height: widget.selected ? 7 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZenTheme.starWhite.withValues(alpha: 0.75 + 0.25 * tw),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 偈语玻璃卡：毛玻璃拟态，呈现碎片上的偈语与拾取时刻。
class _KoanCard extends StatelessWidget {
  const _KoanCard({
    required this.text,
    required this.date,
    required this.region,
  });

  final String text;
  final String date;
  final String region;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: ZenTheme.surfaceDim.withValues(alpha: 0.55),
          border: Border.all(
            color: ZenTheme.nebulaCyan.withValues(alpha: 0.18),
          ),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZenTheme.textHigh,
                  fontSize: 17,
                  height: 1.7,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$region · $date',
                style: TextStyle(
                  color: ZenTheme.textMuted.withValues(alpha: 0.7),
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
