import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'jingjing_game.dart';
import 'memento.dart';
import 'perplex_insight.dart';
import 'shard.dart';

/// 「惑星」（第 43 轮）——世界里偶尔飘来的一个心结。
///
/// 理念：不是每个结都要马上解，但它来了，世界给你足够的温柔去化解它。
///
/// - 浮现：长按呼吸节奏稳定（连续 ≥2 个平稳循环）且本会话开场至少
///   5 分钟、演出互斥窗口之外，世界某处极缓浮现一颗惑星：一团
///   半透明迷雾小球（灰紫、alpha ≤0.35、直径约 60px、缓慢漂移），
///   带极淡内旋纹理。每会话至多 1 颗。
/// - 松动：光灵靠近 80px 内且保持平稳呼吸（cycleCount 连续递增、
///   无紊乱），迷雾变淡、内旋加快；累计 3 个平稳循环后完全化解——
///   化作一小簇星花散去 + 一句惑语 + 1 枚「惑星」心镜碎片。
/// - 退出：呼吸乱了或离开范围——不惩罚，惑星只是慢慢重新凝实、
///   缓缓漂远，本会话不再出现（温柔退出）。
///
/// 状态机是纯逻辑（[PerplexMachine]，可测）；组件只做输入采集与渲染。
/// 碎片入账复用兽语签那套 mergeShards「同时间戳+同偈语」幂等去重。

/// 惑星状态机的阶段。
enum PerplexPhase {
  /// 尚未浮现（等待世界给出资格）。
  hidden,

  /// 极缓浮现中（迷雾渐浓）。
  emerging,

/// 自由漂移，等待光灵靠近。
  drifting,

  /// 化解中：星花散去（约 2.5s）。
  dissolving,

  /// 温柔退出：重新凝实、缓缓漂远。
  fading,

  /// 本会话已结束（化解或退出都到此）。
  gone,
}

/// 惑星纯逻辑状态机：输入只有「是否靠近 / 是否平稳 / 是否刚完成
/// 一个平稳循环 / dt」，输出是阶段与视觉进度。绝不引用 Flame/游戏。
class PerplexMachine {
  PerplexPhase phase = PerplexPhase.hidden;

  /// 迷雾可见度 0..1（emerging 淡入、fading 淡出）。
  double visibility = 0;

  /// 松动度 0..1（靠近且平稳时上升——迷雾变淡、内旋加快）。
  double loosen = 0;

  /// 靠近期间累计的平稳循环数（化解需要 [requiredCycles] 个）。
  int nearCycles = 0;

  /// 化解星花的绽放进度 0..1（仅 dissolving 阶段推进）。
  double burst = 0;

  /// 是否已完全化解（决定是否有惑语与碎片入账）。
  bool get resolved => phase == PerplexPhase.dissolving || _resolved;
  bool _resolved = false;

  /// 状态机是否已彻底结束。
  bool get gone => phase == PerplexPhase.gone;

  bool _insightDone = false;

  /// 本颗惑星是否已经历「通达」（每颗至多一次）。
  bool get insightDone => _insightDone;

  /// 「通达」触发（第 52 轮）：drifting 中跳过循环数要求、提前进入
  /// 化解（星花散去 + 惑语碎片照常走 resolved 通道）。每颗至多一次
  /// ——一次性闸门保证；非 drifting 或已触发过则拒绝并保持原状。
  bool triggerInsight() {
    if (_insightDone || phase != PerplexPhase.drifting) return false;
    _insightDone = true;
    phase = PerplexPhase.dissolving;
    _resolved = true;
    burst = 0;
    return true;
  }

  // ---- 内部计时 ----
  double _offTime = 0; // 连续离开范围的秒数
  double _disorderTime = 0; // 连续呼吸紊乱的秒数

  /// 从 hidden 进入浮现（由组件在浮现资格满足时调用一次）。
  void beginEmerge() {
    if (phase != PerplexPhase.hidden) return;
    phase = PerplexPhase.emerging;
    visibility = 0;
  }

  /// 每帧喂入。dt 秒；[nearby]=光灵在 80px 内；[steady]=呼吸平稳；
  /// [cycleCompleted]=本帧刚完成一个平稳循环（一次性脉冲）。
  void update({
    required bool nearby,
    required bool steady,
    required bool cycleCompleted,
    required double dt,
  }) {
    switch (phase) {
      case PerplexPhase.hidden:
      case PerplexPhase.gone:
        break;

      case PerplexPhase.emerging:
        visibility = (visibility + dt / emergeSeconds).clamp(0.0, 1.0);
        if (visibility >= 1) phase = PerplexPhase.drifting;

      case PerplexPhase.drifting:
        final engaged = nearby && steady;
        if (engaged) {
          _offTime = 0;
          _disorderTime = 0;
          // 持续靠近本身也让迷雾极缓松动（视觉先行，化解仍靠循环数）。
          loosen = (loosen + dt * 0.02).clamp(0.0, 1.0);
          if (cycleCompleted) nearCycles++;
          if (nearCycles >= requiredCycles) {
            phase = PerplexPhase.dissolving;
            _resolved = true;
            burst = 0;
          }
        } else {
          if (!nearby) {
            _offTime += dt;
          } else {
            _offTime = 0;
          }
          if (!steady) {
            _disorderTime += dt;
          } else {
            _disorderTime = 0;
          }
          // 离开范围（3s）或呼吸乱了（2.5s）：温柔退出，不惩罚。
          if (_offTime > leaveGraceSeconds ||
              _disorderTime > disorderGraceSeconds) {
            phase = PerplexPhase.fading;
          }
        }

      case PerplexPhase.dissolving:
        burst = (burst + dt / dissolveSeconds).clamp(0.0, 1.0);
        // 星花散尽的同时迷雾随之收散。
        visibility = (1 - burst).clamp(0.0, 1.0);
        if (burst >= 1) phase = PerplexPhase.gone;

      case PerplexPhase.fading:
        visibility = (visibility - dt / fadeSeconds).clamp(0.0, 1.0);
        if (visibility <= 0) phase = PerplexPhase.gone;
    }
  }

  /// 浮现淡入时长（秒）：极缓，像视线适应后才发现它一直在。
  static const double emergeSeconds = 8.0;

  /// 温柔退出淡出时长（秒）。
  static const double fadeSeconds = 8.0;

  /// 化解星花散去时长（秒）。
  static const double dissolveSeconds = 2.5;

  /// 化解需要的平稳循环数。
  static const int requiredCycles = 3;

  /// 离开范围多少秒后开始退出（短暂的漂出不算离开）。
  static const double leaveGraceSeconds = 3.0;

  /// 呼吸紊乱多少秒后开始退出。
  static const double disorderGraceSeconds = 2.5;

  /// 光灵靠近多少算「在惑星旁」。
  static const double nearDistance = 80.0;
}

/// 浮现资格（纯函数）：连续平稳循环 ≥2、本会话已过 5 分钟、
/// 本会话未出现过、且不在任何演出互斥窗口内（被阻塞则延后）。
bool perplexShouldEmerge({
  required int steadyStreak,
  required double sessionSeconds,
  required bool appearedThisSession,
  required bool blocked,
}) {
  if (appearedThisSession) return false;
  if (blocked) return false;
  if (steadyStreak < 2) return false;
  return sessionSeconds >= minSessionSeconds;
}

/// 至少 5 分钟未出现过（每会话开场起算）。
const double minSessionSeconds = 300.0;

/// 惑语池（新池 3 句）。
const List<String> perplexKoanPool = [
  '解开它的不是力气，是呼吸。',
  '结会松的，在你不盯着它的时候。',
  '它飘来，只是想被轻轻看过一眼。',
];

/// 惑语选取（纯函数）：按本会话已化解的颗数轮换（每会话至多 1 颗，
/// 实际即 0 → 首句；池序稳定可测）。
int perplexKoanIndex(int resolvedCount) => resolvedCount % perplexKoanPool.length;

/// 惑星碎片的收录区域名（导出/合并沿用 ShardRecord.region）。
const String perplexRegion = '惑星';

/// 「惑星」世界组件：迷雾小球 + 内旋纹理 + 化解星花。
///
/// idle（hidden/gone）零渲染成本；浮现后也只画自己这一小团雾。
class PerplexPlanet extends Component with HasGameReference<JingjingGame> {
  PerplexPlanet() {
    final rng = math.Random(7);
    for (int i = 0; i < _dustCount; i++) {
      _dustAngles.add(rng.nextDouble() * math.pi * 2);
      _dustFactors.add(0.55 + rng.nextDouble() * 0.45);
    }
  }

  final PerplexMachine machine = PerplexMachine();

  /// 世界坐标（环绕周期内）。浮现时刻相对光灵选一个中距离的方位，
  /// 让"靠近"是一段小小的旅程而非撞见。
  Vector2 pos = Vector2.zero();

  /// 内旋与漂移的相位种子。
  double seed = 0;

  bool _appeared = false;
  bool _granted = false;
  int _seenCycles = 0;
  int _steadyStreak = 0;
  double _lastCycleAt = -999;

  // ---- 通达（第 52 轮）：状态在组件层内存持有，不持久化。 ----
  double _insightDwell = 0;
  double _insightProgress = 0;

  // 平稳度低通（显示连续性，绝不瞬跳）。
  double _insightSteadySm = 1.0;
  int _lastInsightIndex = -1;
  double _lastInsightAt = -999;

  // 通达光尘：定长粒子池（角度/距离系数构造时预生成，触发时只置
  // 相位 _dustT，逐帧零分配）。
  static const int _dustCount = 18;
  final List<double> _dustAngles = [];
  final List<double> _dustFactors = [];
  double _dustT = -1; // <0 = 未触发

  // ---- 通达残影（第 53 轮）：状态在组件层内存持有，不持久化。 ----
  // 通达进入 dissolving 时记录原位坐标；gone 之后原位留雾痕缓淡。
  final Vector2 _tracePos = Vector2.zero();
  bool _traceActive = false;
  bool _traceGranted = false;
  double _traceElapsedMs = 0;
  double _traceBreathSm = 0; // 呼吸起伏包络低通（绝不瞬跳）。
  final Paint _tracePaint = Paint();

  final math.Random _rng = math.Random(DateTime.now().millisecondsSinceEpoch);

  // 复用画笔（零逐帧分配）。
  final Paint _mistPaint = Paint();
  final Paint _swirlPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;
  final Paint _sparkPaint = Paint();
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  @override
  void update(double dt) {
    final game = this.game;

    // 通达残影计时：自通达瞬间起累计（gone 之后继续淡出）。
    if (_traceActive) _traceElapsedMs += dt * 1000;

    if (machine.gone) {
      if (!_traceActive) {
        removeFromParent();
        return;
      }
      // 雾痕阶段：本体已散，只剩原位雾痕——alpha 归零后彻底停止。
      if (mistTraceAlpha(_traceElapsedMs) <= 0) {
        _traceActive = false;
        removeFromParent();
        return;
      }
      final d = game.spiritPos - _tracePos;
      game.wrapDelta(d);
      final near =
          d.length2 <=
          PerplexMachine.nearDistance * PerplexMachine.nearDistance;
      // 平稳呼吸时雾痕轻微随呼吸起伏（低通包络，绝不瞬跳）。
      final envTarget =
          (near && game.breathSteady) ? math.sin(game.time * 1.4) : 0.0;
      _traceBreathSm += (envTarget - _traceBreathSm) * math.min(1.0, dt * 3.0);
      // 再遇馈赠：近旁 + 平稳呼吸 → 一次性掉落 1 枚普通心镜碎片。
      if (mistTraceGrantAllowed(
        granted: _traceGranted,
        near: near,
        breathSteady: game.breathSteady,
      )) {
        _traceGranted = true;
        _grantTraceShard(game);
      }
      return;
    }

    // 刚完成一个平稳循环（cycleCount 只增不减；一次脉冲只算一次）。
    final cycleCompleted = game.cycleCount != _seenCycles;
    if (cycleCompleted) {
      // 连续性：距上个循环超过约 1.5 个呼吸周期视为节奏断过——
      // 重新计数（温和：断掉只是重新攒，不惩罚）。
      _steadyStreak =
          (game.time - _lastCycleAt <= 14.0) ? _steadyStreak + 1 : 1;
      _lastCycleAt = game.time;
    }
    _seenCycles = game.cycleCount;
    if (game.time - _lastCycleAt > 14.0) _steadyStreak = 0;

    // 演出互斥（后到者让先的既有约定）：演出期间不浮现，进行中
    // 被阻塞则延后——已浮现的不被打断（它是背景里的雾，不是演出）。
    final blocked =
        game.onboarding != null ||
        game.reunion.active ||
        game.fullAwake.active ||
        game.farewellPlaying ||
        game.longAbsenceActive;

    if (machine.phase == PerplexPhase.hidden) {
      if (perplexShouldEmerge(
        steadyStreak: _steadyStreak,
        sessionSeconds: game.time,
        appearedThisSession: _appeared,
        blocked: blocked,
      )) {
        _appeared = true;
        _spawnNearSpirit(game);
        machine.beginEmerge();
      }
      return;
    }

    // 距离（环绕最短距离）。
    final d = game.spiritPos - pos;
    game.wrapDelta(d);
    final nearby =
        d.length2 <=
        PerplexMachine.nearDistance * PerplexMachine.nearDistance;

    machine.update(
      nearby: nearby,
      steady: game.breathSteady,
      cycleCompleted: cycleCompleted,
      dt: dt,
    );

    // 通达（第 52 轮）：drifting 且近旁、平稳呼吸时驻留积累；注满
    // 触发一次「通达」——惑星提前化解 + 光尘 + 惑语碎片（每颗至多
    // 一次，由 triggerInsight 的一次性闸门保证）。
    if (machine.phase == PerplexPhase.drifting) {
      _insightSteadySm +=
          ((game.breathSteady ? 1.0 : 0.0) - _insightSteadySm) *
          math.min(1.0, dt * 0.8);
      _insightDwell = perplexInsightDwellNext(
        dwellSeconds: _insightDwell,
        dt: dt,
        near: nearby,
        breathSteady: game.breathSteady,
      );
      _insightProgress = perplexInsightProgress(
        dwellSeconds: _insightDwell,
        breathSteadiness: _insightSteadySm,
      );
      if (_insightProgress >= kInsightTriggerThreshold &&
          machine.triggerInsight()) {
        _granted = true; // 通达发放「惑语」碎片，普通化解不再重复入账。
        _grantInsightShard(game);
        _dustT = 0;
        // 通达残影：进入 dissolving 即记录原位坐标，gone 后留雾痕。
        _traceActive = true;
        _traceElapsedMs = 0;
        _tracePos.setFrom(pos);
      }
    }

    // 通达光尘相位推进（化解 2.5s 内收散，组件移除前自然结束）。
    if (_dustT >= 0) {
      _dustT += dt;
      if (_dustT >= kInsightDustSeconds) _dustT = -1;
    }

    // 缓慢漂移：极小的圆流分量，无方向突变。
    final t = game.time + seed;
    pos.x += math.cos(t * 0.13) * 5.5 * dt;
    pos.y += math.sin(t * 0.11 + 1.7) * 4.5 * dt;
    game.wrap(pos);

    // 化解完成：一句惑语 + 1 枚「惑星」心镜碎片（幂等入账，只记一次）。
    if (machine.resolved && !_granted) {
      _granted = true;
      _grantShard(game);
    }
  }

  /// 在光灵周围 380~640px 的环绕最短距离处落点。
  void _spawnNearSpirit(JingjingGame game) {
    seed = _rng.nextDouble() * math.pi * 2;
    final angle = _rng.nextDouble() * math.pi * 2;
    final dist = 380 + _rng.nextDouble() * 260;
    pos = game.spiritPos + Vector2(math.cos(angle), math.sin(angle)) * dist;
    game.wrap(pos);
  }

  /// 碎片入账：复用兽语签那套 mergeShards「同时间戳+同偈语」幂等
  /// 去重（重复触发不重复记账），并入 shardMessage 面板浮现惑语。
  void _grantShard(JingjingGame game) {
    final koan = perplexKoanPool[perplexKoanIndex(0)];
    final record = ShardRecord(
      time: DateTime.now(),
      text: koan,
      region: perplexRegion,
    );
    final (merged, added) = mergeShards(game.shardCollection.records, [record]);
    if (added > 0) {
      game.shardCollection.records
        ..clear()
        ..addAll(merged);
      unawaited(game.shardCollection.save());
    }
    game.shardMessage.value = koan;
  }

  /// 「通达」入账：一枚「惑语」碎片（region='惑'，走既有拾忆/merge
  /// 通道）+ 一句"迷失也是路"短语浮出（15s 内不重复上句）。
  void _grantInsightShard(JingjingGame game) {
    final idx = perplexInsightPhraseIndex(
      _rng.nextInt(kInsightPhrases.length),
      _lastInsightIndex,
      game.time - _lastInsightAt,
    );
    _lastInsightIndex = idx;
    _lastInsightAt = game.time;
    final phrase = kInsightPhrases[idx];
    final record = ShardRecord(
      time: DateTime.now(),
      text: phrase,
      region: perplexInsightRegion,
    );
    final (merged, added) = mergeShards(game.shardCollection.records, [record]);
    if (added > 0) {
      game.shardCollection.records
        ..clear()
        ..addAll(merged);
      unawaited(game.shardCollection.save());
    }
    game.shardMessage.value = phrase;
  }

  /// 「雾痕」一次性馈赠（第 53 轮）：近旁平稳呼吸时掉 1 枚普通心镜
  /// 碎片（region='雾痕'，走既有拾忆/merge 幂等通道），一次性闸门由
  /// mistTraceGrantAllowed 纯函数保证——掉过后只剩纯视觉雾痕。
  void _grantTraceShard(JingjingGame game) {
    final record = ShardRecord(
      time: DateTime.now(),
      text: mistTraceShardText,
      region: mistTraceRegion,
    );
    final (merged, added) = mergeShards(game.shardCollection.records, [record]);
    if (added > 0) {
      game.shardCollection.records
        ..clear()
        ..addAll(merged);
      unawaited(game.shardCollection.save());
    }
    game.shardMessage.value = mistTraceShardText;
  }

  @override
  void render(Canvas canvas) {
    final game = this.game;
    final vis = machine.visibility;
    final phase = machine.phase;
    if (phase == PerplexPhase.hidden || vis <= 0.004) {
      if (!(phase == PerplexPhase.gone && _traceActive)) return;
    }
    if (game.introEase <= 0.05) return;

    if (phase == PerplexPhase.gone) {
      _renderMistTrace(canvas, game);
      return;
    }

    // 世界坐标 -> 屏幕坐标（环绕镜像最近一次）。
    final size = game.size;
    final d = pos - game.camPos;
    game.wrapDelta(d);
    final center = Offset(size.x / 2 + d.x, size.y / 2 + d.y);
    if (center.dx < -80 ||
        center.dx > size.x + 80 ||
        center.dy < -80 ||
        center.dy > size.y + 80) {
      return;
    }

    final t = game.time + seed;
    final loosen = machine.loosen;
    // 松动时呼吸般轻微舒缩；迷雾变淡（松动度直接压 alpha）。
    final breathe = 1 + 0.06 * math.sin(t * 1.4);
    final radius = 30.0 * breathe * (1 + 0.10 * loosen);

    // 迷雾本体：灰紫径向渐变，峰值 alpha 0.35 封顶。
    final alpha = 0.35 * vis * (1 - 0.55 * loosen);
    _mistPaint.shader = RadialGradient(
      colors: [
        const Color(0xFF8f86ad).withValues(alpha: alpha),
        const Color(0xFF6a6280).withValues(alpha: alpha * 0.55),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _mistPaint);

    // 极淡内旋纹理：两圈细弧随松动度加快旋转（乱结被呼吸梳理）。
    final swirlAlpha = 0.14 * vis * (0.4 + 0.6 * (1 - loosen));
    final spin = t * (0.35 + 1.5 * loosen);
    for (int i = 0; i < 2; i++) {
      final start = spin + i * math.pi * 0.9;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.42 + 0.18 * i)),
        start,
        math.pi * 1.15,
        false,
        _swirlPaint
          ..color = const Color(0xFFc9c2e0).withValues(alpha: swirlAlpha),
      );
    }

    // 通达轮廓微亮：progress 越过 0.5 后轮廓极缓亮起（量化 alpha，
    // 不新增每帧分配——glow 本身已按 0.04 步进量化）。
    final glow = perplexInsightGlow(
      machine.phase == PerplexPhase.drifting ? _insightProgress : 0,
    );
    if (glow > 0) {
      final ga = ((0.16 * glow * vis) * 40).round() / 40.0;
      if (ga > 0) {
        canvas.drawCircle(
          center,
          radius * 1.12,
          _glowPaint
            ..color = const Color(0xFFc9c2e0).withValues(alpha: ga),
        );
      }
    }

    // 化解星花（复用 anxiety_abyss 星花的视觉语言）：一小簇星点
    // 从花心缓缓张开散去，花心带一点呼吸辉光。
    if (phase == PerplexPhase.dissolving) {
      final p = machine.burst;
      final ease = p * p * (3 - 2 * p);
      final heartA = 0.30 * (1 - p);
      _sparkPaint.shader = RadialGradient(
        colors: [
          const Color(0xFFe8c4d0).withValues(alpha: heartA),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 26 + 14 * ease));
      canvas.drawCircle(center, 26 + 14 * ease, _sparkPaint);

      const petals = 9;
      for (int i = 0; i < petals; i++) {
        final a = (i / petals) * math.pi * 2 + seed + spin * 0.5;
        final dist = 6 + 46 * ease * (0.75 + 0.25 * math.sin(i * 2.4));
        final pt = Offset(
          center.dx + math.cos(a) * dist,
          center.dy + math.sin(a) * dist * 0.92,
        );
        final pa = (1 - p) * 0.7;
        _sparkPaint
          ..shader = null
          ..color = Color.lerp(
            const Color(0xFF9b8fb8),
            const Color(0xFFf0d8e2),
            ease,
          )!.withValues(alpha: pa);
        canvas.drawCircle(pt, 1.3 + (i % 3) * 0.5, _sparkPaint);
      }
    }

    // 通达光尘：一圈灰紫光尘从花心缓缓散开（定长池预生成参数，
    // 包络 sin 起落，随化解一起收散）。
    final dustEnv = perplexInsightDustEnvelope(_dustT);
    if (dustEnv > 0) {
      final spread = 22 + 72 * (_dustT / kInsightDustSeconds);
      final da = ((0.5 * dustEnv) * 40).round() / 40.0;
      for (int i = 0; i < _dustCount; i++) {
        final a = _dustAngles[i] + _dustT * 0.5;
        final dist = spread * _dustFactors[i];
        _sparkPaint
          ..shader = null
          ..color = const Color(0xFF9b8fb8).withValues(alpha: da);
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(a) * dist,
            center.dy + math.sin(a) * dist * 0.92,
          ),
          0.9 + (i % 3) * 0.4,
          _sparkPaint,
        );
      }
    }
  }

  /// 通达残影（第 53 轮）：gone 之后在通达原位画一道极淡的灰紫椭圆
  /// 雾痕，随 mistTraceAlpha 约 6 分钟缓淡；近旁平稳呼吸时经
  /// mistTraceBreath 轻微起伏。alpha 归零后 update 已短路移除，
  /// 超时/离屏直接 return——不画即零成本。
  void _renderMistTrace(Canvas canvas, JingjingGame game) {
    final a = mistTraceAlpha(_traceElapsedMs);
    if (a <= 0) return;

    final size = game.size;
    final d = _tracePos - game.camPos;
    game.wrapDelta(d);
    final center = Offset(size.x / 2 + d.x, size.y / 2 + d.y);
    if (center.dx < -90 ||
        center.dx > size.x + 90 ||
        center.dy < -90 ||
        center.dy > size.y + 90) {
      return;
    }

    final alpha = mistTraceBreath(a, _traceBreathSm);
    if (alpha <= 0) return;
    final wobble = 1 + 0.05 * _traceBreathSm;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 76 * wobble,
        height: 58 * wobble,
      ),
      _tracePaint..color = const Color(0xFF8f86ad).withValues(alpha: alpha),
    );
  }
}
