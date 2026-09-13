import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../game/awakening.dart';
import '../game/full_awake.dart';
import '../game/koans.dart';
import '../game/memento.dart';
import '../game/memo_stats.dart';
import '../game/shard.dart';
import '../game/star_beast.dart';
import '../game/star_card.dart';
import '../game/star_card_saver.dart';

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
  // 「带走星图」（第 35 轮）：分享卡生成期间转圈禁用。
  bool _exporting = false;
  // 「满醒纪念签」（第 31 轮）：演过满醒终幕才有的印记，未满醒零渲染。
  bool _fullAwakePlayed = false;
  FullAwakeCount _fullAwakeCount = const FullAwakeCount(count: 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _collection.load();
    await _beastState.load();
    final played = await FullAwakeCtl.loadPlayed();
    final count = await FullAwakeCtl.loadCount();
    if (!mounted) return;
    setState(() {
      _records = List<ShardRecord>.of(_collection.records);
      _beastEyes = _beastState.openedEyes;
      _beastSwimming = _beastState.swimming;
      _fullAwakePlayed = played;
      _fullAwakeCount = count;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _tokenTimer?.cancel();
    super.dispose();
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

  /// 「带走星图」（第 35 轮）：把当前星图渲染成一张 1080×1620 的
  /// 离屏分享卡（深空底色 + 同款黄金角螺旋星点 + 中央小晨星 +
  /// 统计行），Web 上经 anchor download 触发 PNG 下载。
  /// 生成期间按钮转圈禁用；失败温柔提示，不惊扰。
  Future<void> _exportStarCard() async {
    if (_exporting || !_loaded) return;
    setState(() => _exporting = true);
    try {
      final image = await renderStarCardImage(
        records: _records,
        fullAwakePlayed: _fullAwakePlayed,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        throw StateError('toByteData returned null');
      }
      final saver = StarCardSaverImpl();
      final ok = await saver.savePng(
        data.buffer.asUint8List(),
        'jingxin-star-map-${shardDateKey(DateTime.now())}.png',
      );
      if (!mounted) return;
      _say(ok ? '星图已带走，收好' : '这张星图暂时带不走，晚点再来');
    } catch (_) {
      if (mounted) _say('这张星图暂时带不走，晚点再来');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 一行淡字提示（底部 snackbar，温柔、用后即逝）。
  void _say(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            color: ZenTheme.textHigh.withValues(alpha: 0.85),
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZenTheme.surfaceDim.withValues(alpha: 0.92),
        duration: const Duration(seconds: 3),
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

  // ---- 满醒纪念签（第 31 轮） ----
  Timer? _tokenTimer;
  bool _tokenCardShown = false;
  DateTime? _tokenTapAt;
  String? _tokenKoan;

  /// 纪念签位置：黄金角螺旋再往外一枚（index = 碎片数 + 6），
  /// 半径封顶避免碎片很多时被推出屏幕。
  Offset _tokenOffset(Size size) {
    final index = _records.length + 6;
    const goldenAngle = 2.39996;
    final angle = index * goldenAngle;
    final radius = math.min(
      26.0 * math.sqrt(index + 1),
      size.shortestSide * 0.38,
    );
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    return Offset(
      cx + math.cos(angle) * radius,
      cy + math.sin(angle) * radius * 0.82,
    );
  }

  Widget _buildAwakeToken(Size size) {
    final pos = _tokenOffset(size);
    return Positioned(
      left: pos.dx - 30,
      top: pos.dy - 30,
      width: 60,
      height: 60,
      child: _AwakeTokenWidget(onTap: _showTokenCard),
    );
  }

  /// 点纪念签：演出期间不可点（后到者让先）；小卡显示中或 15s
  /// 冷却未满也不可点。弹卡后 5s 淡出。
  void _showTokenCard() {
    if (FullAwakeCtl.performanceActive) return;
    final since = _tokenTapAt == null
        ? double.infinity
        : DateTime.now().difference(_tokenTapAt!).inMilliseconds / 1000.0;
    if (!FullAwakeCtl.tokenTapAllowed(
      showing: _tokenCardShown,
      secondsSinceTap: since,
    )) {
      return;
    }
    _tokenTapAt = DateTime.now();
    _tokenTimer?.cancel();
    setState(() {
      _tokenCardShown = true;
      _tokenKoan = Koans.nextFullAwake();
    });
    _tokenTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _tokenCardShown = false);
    });
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
                final hasStars = _records.isNotEmpty;
                // 未满醒过且尚无星：保持原样的沉睡提示（零额外渲染）。
                if (!hasStars && !_fullAwakePlayed) {
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
                    // 满醒纪念签（第 31 轮）：星座外缘一枚小小的印记。
                    // 未满醒过则完全不出现（零渲染成本）。
                    if (_fullAwakePlayed) _buildAwakeToken(size),
                    if (hasStars)
                      for (int i = 0; i < _records.length; i++)
                        _buildStar(i, size),
                    if (!hasStars)
                      Center(
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
                      ),
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
          // 「满醒纪念签」小卡（第 31 轮）：玻璃拟态，印记文案 + 一句满醒偈，
          // 5s 后淡出；纯展示层不拦截点击。
          if (_fullAwakePlayed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 110,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _tokenCardShown ? 1 : 0,
                  duration: Duration(
                    milliseconds: _tokenCardShown ? 700 : 900,
                  ),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: _AwakeTokenCard(
                      imprint: _fullAwakeCount.memorialText,
                      koan: _tokenKoan ?? '',
                    ),
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
          // 右上角双入口：「带走星图」（第 35 轮）+「拾忆」（第 15 轮）。
          // 两枚极小的图标并排，克制不抢镜。
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '带走星图',
                      iconSize: 20,
                      icon: _exporting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: ZenTheme.nebulaCyan.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            )
                            : Icon(
                              Icons.ios_share_rounded,
                              color: ZenTheme.textMuted.withValues(alpha: 0.6),
                            ),
                      onPressed: _exporting ? null : _exportStarCard,
                    ),
                    IconButton(
                      tooltip: '拾忆',
                      iconSize: 20,
                      icon: Icon(
                        Icons.auto_awesome_outlined,
                        color: ZenTheme.textMuted.withValues(alpha: 0.6),
                      ),
                      onPressed: _showMementoDrawer,
                    ),
                  ],
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
  bool _showMemories = false; // 「重看那一夜」：碎片星点列（第 24 轮）。
  // 「星河的章节」（第 25 轮）：收起的夜晚日期键集合。
  // 默认只展开最近一夜，其余收起，避免列表过长。
  Set<String> _collapsedNights = <String>{};
  bool _nightsInitialized = false;
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

  /// 「重看那一夜 · 星河的章节」（第 25 轮）：按夜晚分组的碎片星点。
  /// 每个夜晚一行：行首一枚极小的日期签（可点折叠/展开，默认只展开
  /// 最近一夜），后随该夜的星点；行右端一段细小的「夜弧」——完成度
  /// 即这一夜的碎片数占历史单夜最多次数的比例，纯装饰、克制。
  Widget _memoryChips() {
    final records = widget.collection.records;
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          '还没有碎片。当光灵拾起第一片心镜，这里会亮起第一枚星点。',
          style: TextStyle(
            color: ZenTheme.textMuted.withValues(alpha: 0.5),
            fontSize: 12,
            height: 1.8,
            letterSpacing: 1.5,
          ),
        ),
      );
    }
    // 首次展开时初始化折叠状态：最近一夜展开，其余收起。
    if (!_nightsInitialized) {
      _nightsInitialized = true;
      final groups = groupNightsByDate(records);
      _collapsedNights = {
        for (final g in groups.skip(1)) g.dateKey,
      };
    }
    final groups = groupNightsByDate(records);
    final maxCount = busiestNight(records);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ZenTheme.voidBlack.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            // 行首日期签：点按折叠/展开该夜。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (!_collapsedNights.remove(group.dateKey)) {
                  _collapsedNights.add(group.dateKey);
                }
              }),
              child: Tooltip(
                message: '点一下${_collapsedNights.contains(group.dateKey) ? '展开' : '收起'}这一夜',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _collapsedNights.contains(group.dateKey)
                            ? Icons.chevron_right_rounded
                            : Icons.expand_more_rounded,
                        size: 14,
                        color: ZenTheme.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nightLabel(group.dateKey, group.records.length),
                          style: TextStyle(
                            color: ZenTheme.textMuted.withValues(alpha: 0.65),
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // 夜弧：完成度 = 该夜碎片数 / 历史单夜最多数。
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CustomPaint(
                          painter: _NightArcPainter(
                            sweep: nightArcSweep(group.records.length, maxCount),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 该夜的星点行（收起时不渲染）。
            if (!_collapsedNights.contains(group.dateKey))
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final rec in group.records) _memoryDot(rec),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 单枚碎片星点：颜色即来源区域，点选浮起记忆卡。
  Widget _memoryDot(ShardRecord rec) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openMemoryCard(rec),
      child: Tooltip(
        message: '${_formatDate(rec.time)} · ${rec.region}',
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: regionDotColor(rec.region).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: regionDotColor(rec.region),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 记忆卡：玻璃拟态底部浮层，重走那一夜的呼吸。
  void _openMemoryCard(ShardRecord record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _MemoryCard(record: record),
    );
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
              // 限高滚动（第 30 轮）：夜数变多时抽屉不撑破屏幕，
              // 最高约屏高 55%，超出部分内部滚动，玻璃拟态与圆角不变。
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
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
                  const SizedBox(height: 14),
                  // 顶部汇总（第 24 轮）：一句淡字，数字轻、无成绩感。
                  Text(
                    memorySummary(widget.collection.records),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZenTheme.textMuted.withValues(alpha: 0.6),
                      fontSize: 12,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  // 「重看那一夜」（第 24 轮）：点一枚星点，重走那次呼吸。
                  _MementoAction(
                    label: '重看那一夜',
                    hint: '点一枚碎片，回到拾起它的时刻',
                    onTap: () =>
                        setState(() => _showMemories = !_showMemories),
                  ),
                  _expandable(visible: _showMemories, child: _memoryChips()),
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

/// 「一夜的记忆」记忆卡（第 24 轮）：玻璃拟态卡片，
/// 时间戳 + 禅语 + 来源区域星点，卡内一枚程序化「呼吸纹」
/// （三环涟漪，随呼吸节奏极缓慢脉动——回看时重走那次呼吸）。
class _MemoryCard extends StatefulWidget {
  const _MemoryCard({required this.record});

  final ShardRecord record;

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard>
    with SingleTickerProviderStateMixin {
  /// 呼吸纹周期：8s 一循环，与游戏内静呼吸节奏同量级，极缓。
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  String _formatFull(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$m月$d日 $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = regionDotColor(widget.record.region);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: ZenTheme.surfaceDim.withValues(alpha: 0.62),
            border: Border.all(color: dotColor.withValues(alpha: 0.22)),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 呼吸纹：三环涟漪，极缓脉动。
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, _) => CustomPaint(
                    size: const Size(96, 96),
                    painter: _BreathRipplePainter(
                      phase: _breath.value,
                      color: dotColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.record.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZenTheme.textHigh,
                    fontSize: 17,
                    height: 1.7,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                // 来源区域：一枚小星点 + 区域名。
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.record.region} · ${_formatFull(widget.record.time)}',
                      style: TextStyle(
                        color: ZenTheme.textMuted.withValues(alpha: 0.7),
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 呼吸纹画笔：三圈同心圆环涟漪，相位错开，透明度随呼吸相位
/// 极缓慢地起伏（sin 波，无急停）。克制：只描边、不填充。
class _BreathRipplePainter extends CustomPainter {
  _BreathRipplePainter({required this.phase, required this.color});

  /// 0..1 呼吸相位。
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 2;
    final breathe = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    for (var i = 0; i < 3; i++) {
      final t = (phase - i * 0.18) % 1.0;
      final ripple = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      final r = maxR * (0.34 + 0.30 * i / 2) + 3.0 * ripple;
      final alpha = 0.16 + 0.20 * breathe - 0.06 * i;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Color.lerp(
            ZenTheme.starWhite,
            color,
            0.55,
          )!.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
    // 中心一粒安静的星点。
    canvas.drawCircle(
      center,
      2.2 + 0.6 * breathe,
      Paint()..color = color.withValues(alpha: 0.5 + 0.3 * breathe),
    );
  }

  @override
  bool shouldRepaint(_BreathRipplePainter old) =>
      old.phase != phase || old.color != color;
}

/// 「夜弧」（第 25 轮）：夜晚行右端一枚极小的弧形标记。
/// 弧的完成度 = 该夜碎片数 / 历史单夜最多数（封顶整圆），
/// 纯装饰、克制——只是这条轨迹被静过的程度的一瞥。
class _NightArcPainter extends CustomPainter {
  _NightArcPainter({required this.sweep});

  /// 0..2π 的扫过角度。
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: r);
    // 底环：极淡的一整圈，像还没被走过的夜。
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    // 夜弧：从正上方起，顺时针扫过。
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = ZenTheme.nebulaCyan.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_NightArcPainter old) => old.sweep != sweep;
}

/// 「满醒纪念签」（第 31 轮）：星座外缘一枚小小的印记——
/// 一粒金白光点 + 极细环形光晕，缓慢自转（约 90s 一圈），克制。
/// 只有演过满醒终幕的玩家才会看到它。
class _AwakeTokenWidget extends StatefulWidget {
  const _AwakeTokenWidget({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AwakeTokenWidget> createState() => _AwakeTokenWidgetState();
}

class _AwakeTokenWidgetState extends State<_AwakeTokenWidget>
    with SingleTickerProviderStateMixin {
  /// 自转周期 90s——极缓，只是"活着"的一瞥。
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (FullAwakeCtl.tokenSpinPeriod * 1000).round(),
    ),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => CustomPaint(
          size: const Size(60, 60),
          painter: _AwakeTokenPainter(angle: FullAwakeCtl.tokenAngle(_spin.value * FullAwakeCtl.tokenSpinPeriod)),
        ),
      ),
    );
  }
}

/// 纪念签画笔：中心一粒金白光点，外缘一圈极细光晕，
/// 光晕上一枚微小的伴点缓慢绕行（自转的可视线索）。全部低透明度。
class _AwakeTokenPainter extends CustomPainter {
  _AwakeTokenPainter({required this.angle});

  /// 当前自转角（弧度）。
  final double angle;

  static const Color _gold = Color(0xFFe8c87e);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // 极细环形光晕。
    canvas.drawCircle(
      center,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _gold.withValues(alpha: 0.14),
    );
    // 中心金白光点（带一点点呼吸感由外层不承担，保持静）。
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = _gold.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      center,
      2.0,
      Paint()..color = ZenTheme.starWhite.withValues(alpha: 0.85),
    );
    // 伴点：环上极小一粒，随 angle 绕行——自转的唯一线索。
    final dx = math.cos(angle) * 17;
    final dy = math.sin(angle) * 17;
    canvas.drawCircle(
      Offset(center.dx + dx, center.dy + dy),
      1.1,
      Paint()..color = _gold.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_AwakeTokenPainter old) => old.angle != angle;
}

/// 纪念签小卡：玻璃拟态，印记文案 + 一句满醒偈。极小、克制。
class _AwakeTokenCard extends StatelessWidget {
  const _AwakeTokenCard({required this.imprint, required this.koan});

  final String imprint;
  final String koan;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: ZenTheme.surfaceDim.withValues(alpha: 0.58),
          border: Border.all(color: _tokenGold.withValues(alpha: 0.20)),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                imprint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _tokenGold.withValues(alpha: 0.9),
                  fontSize: 13,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                koan,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZenTheme.textHigh,
                  fontSize: 15,
                  height: 1.7,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _tokenGold = Color(0xFFe8c87e);
}
