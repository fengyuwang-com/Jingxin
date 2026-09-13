import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../game/awakening.dart';
import '../game/memento.dart';
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

  /// 「拾忆」玻璃底部抽屉（第 15 轮）：导出 / 足迹 / 带回。
  void _showMementoDrawer() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (_) => _MementoDrawer(
        collection: _collection,
        beastState: _beastState,
        onImported: () {
          if (mounted) {
            setState(() => _records = List<ShardRecord>.of(_collection.records));
          }
        },
      ),
    );
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
          // 「拾忆」入口（第 15 轮）：右上角一枚极小的图标，克制不抢镜。
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: '拾忆',
                  iconSize: 20,
                  icon: Icon(
                    Icons.auto_awesome_outlined,
                    color: ZenTheme.textMuted.withValues(alpha: 0.6),
                  ),
                  onPressed: _showMementoDrawer,
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

/// 「拾忆」抽屉：玻璃拟态底部面板。三件小事，皆克制——
/// 带我的心境走（导出到剪贴板）、看一眼足迹（极简回顾）、
/// 放回心镜（粘贴带回）。不是备份工具，只是一次轻轻的拾忆。
class _MementoDrawer extends StatefulWidget {
  const _MementoDrawer({
    required this.collection,
    required this.beastState,
    required this.onImported,
  });

  final ShardCollection collection;
  final StarBeastState beastState;
  final VoidCallback onImported;

  @override
  State<_MementoDrawer> createState() => _MementoDrawerState();
}

class _MementoDrawerState extends State<_MementoDrawer> {
  final TextEditingController _pasteController = TextEditingController();
  final AwakeningState _awakening = AwakeningState();
  bool _showFootprint = false;
  bool _showPaste = false;
  String? _message; // 一行淡字，用后即逝。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _awakening.load();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  void _say(String msg) => setState(() => _message = msg);

  String _formatDate(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$m月$d日';
  }

  /// 「带我的心境走」：全部收集史 + 苏醒度/星兽状态打包进剪贴板。
  Future<void> _carry() async {
    if (_busy) return;
    _busy = true;
    final code = MementoCodec.encode(
      shards: widget.collection.records,
      awakening: _awakening.value,
      beastValue: widget.beastState.value,
      beastSwimUntil: widget.beastState.swimUntilEpoch,
    );
    await Clipboard.setData(ClipboardData(text: code));
    _busy = false;
    _say('已复制，收好');
  }

  /// 「放回心镜」：粘贴文本 → 校验 → 按时间戳去重合并，不覆盖现有。
  Future<void> _bringBack() async {
    if (_busy) return;
    _busy = true;
    final data = MementoCodec.tryDecode(_pasteController.text);
    if (data == null) {
      _busy = false;
      _say('这段记忆读不出来');
      return;
    }
    final (merged, added) = mergeShards(widget.collection.records, data.shards);
    if (added > 0) {
      widget.collection.records
        ..clear()
        ..addAll(merged);
      await widget.collection.save();
    }
    _busy = false;
    widget.onImported();
    _pasteController.clear();
    _say('心镜归位了，共 $added 片');
  }

  String get _footprintText {
    final records = widget.collection.records;
    if (records.isEmpty) {
      return '足迹尚是空白。当光灵拾起第一片心镜，这里会留下第一行印迹。';
    }
    final sorted = List<ShardRecord>.of(records)
      ..sort((a, b) => a.time.compareTo(b.time));
    final first = sorted.first;
    final last = sorted.last;
    final buffer = StringBuffer(
      '共 ${sorted.length} 片心镜。\n第一次是${_formatDate(first.time)}，'
      '在${first.region}，捡到「${first.text}」。',
    );
    if (sorted.length > 1) {
      buffer.write(
        '\n最近一次是${_formatDate(last.time)}，'
        '在${last.region}，捡到「${last.text}」。',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
            decoration: BoxDecoration(
              color: ZenTheme.surfaceDim.withValues(alpha: 0.62),
              border: Border(
                top: BorderSide(
                  color: ZenTheme.nebulaCyan.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: ZenMotion.page,
              curve: ZenMotion.pageCurve,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - t)),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '拾 忆',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZenTheme.starWhite.withValues(alpha: 0.7),
                      fontSize: 14,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MementoAction(
                    label: '带我的心境走',
                    hint: '把这片星图收进一段文字，随身带走',
                    onTap: _carry,
                  ),
                  const SizedBox(height: 10),
                  _MementoAction(
                    label: '看一眼足迹',
                    hint: '第一次与最近一次的拾取',
                    onTap: () =>
                        setState(() => _showFootprint = !_showFootprint),
                  ),
                  _expandable(
                    visible: _showFootprint,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: ZenTheme.voidBlack.withValues(alpha: 0.35),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        _footprintText,
                        style: TextStyle(
                          color: ZenTheme.textMuted.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.9,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MementoAction(
                    label: '放回心镜',
                    hint: '把带走的文字粘贴回来',
                    onTap: () => setState(() => _showPaste = !_showPaste),
                  ),
                  _expandable(
                    visible: _showPaste,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _pasteController,
                          maxLines: 3,
                          style: TextStyle(
                            color: ZenTheme.textHigh.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: '在此轻轻放下那段文字……',
                            hintStyle: TextStyle(
                              color:
                                  ZenTheme.textMuted.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor:
                                ZenTheme.voidBlack.withValues(alpha: 0.35),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _bringBack,
                          child: Text(
                            '归位',
                            style: TextStyle(
                              color:
                                  ZenTheme.nebulaCyan.withValues(alpha: 0.8),
                              fontSize: 13,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 一行淡字：结果提示，用后即逝。
                  AnimatedOpacity(
                    opacity: _message != null ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _message ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZenTheme.textMuted.withValues(alpha: 0.55),
                          fontSize: 12,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部淡入展开的小区块（足迹 / 粘贴框共用）。
  Widget _expandable({required bool visible, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: visible ? 0 : 1, end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        if (t == 0) return const SizedBox(width: double.infinity);
        return Opacity(
          opacity: t,
          child: ClipRect(
            child: Align(
              heightFactor: t,
              widthFactor: 1,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 10 * t),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 抽屉里的一行小动作：只有一句标题与一句更淡的注解。
class _MementoAction extends StatelessWidget {
  const _MementoAction({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ZenTheme.starWhite.withValues(alpha: 0.8),
                fontSize: 15,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                color: ZenTheme.textMuted.withValues(alpha: 0.45),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
