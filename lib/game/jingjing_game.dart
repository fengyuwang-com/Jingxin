import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;

import '../core/theme.dart';
import 'awakening.dart';
import 'insomnia_sea.dart';
import 'shard.dart';

/// 静境（Jingjing）游戏循环。
///
/// 第 2 轮：呼吸输入层——按住屏幕=吸气、松开=呼气，光灵平滑跟随；
/// 空闲数秒后回归缓慢自动呼吸（引导而非惩罚）。完整平稳呼吸循环
/// 缓慢提升"世界苏醒度"（AwakeningState），实时驱动星空亮度、
/// 闪烁密度、背景色温与光灵光晕。
class JingjingGame extends FlameGame with TapCallbacks {
  JingjingGame({this.seedColor = ZenTheme.nebulaCyan})
    : awakening = AwakeningState(),
      breathHint = ValueNotifier<String?>(null),
      awakeningValue = ValueNotifier(0),
      shardMessage = ValueNotifier<String?>(null);

  final Color seedColor;
  final AwakeningState awakening;

  /// 当前呼吸提示词（"吸气…"/"呼气…"），null 表示静息。
  final ValueNotifier<String?> breathHint;

  /// 苏醒度镜像，供 UI 层（极细光线/边缘光晕）监听。
  final ValueNotifier<double> awakeningValue;

  /// 刚被吸入的心镜碎片浮现的禅语（null=无），供 UI 玻璃面板监听。
  final ValueNotifier<String?> shardMessage;

  /// 心镜碎片收集史（持久化），星图回读用。
  final ShardCollection shardCollection = ShardCollection();

  /// 本轮程序放置的碎片（2~4 片，极稀疏）。
  final List<MindShard> shards = [];

  final math.Random _random = math.Random(42);
  late final LightSpirit _spirit;
  late final _Starfield _starfield;
  double _time = 0;

  // ---- 呼吸输入状态 ----
  bool _pressing = false;
  double _breathProgress = 0;
  double _prevBreathProgress = 0;
  double _idleTime = 0;

  /// 自动呼吸混合权重：无输入越久越趋近 1（回归引导节奏）。
  double _autoWeight = 1;

  // 完整循环检测（先到峰、再落谷 = 一次平稳循环）。
  bool _cyclePeakReached = false;
  double _cycleTime = 0;

  /// 吸气时长（秒）：按住约 3 秒满。
  static const double inhaleDuration = 3.2;

  /// 世界环绕周期（逻辑像素）：漫游无边界，坐标按此周期折叠。
  static final Vector2 worldPeriod = Vector2(2400, 1800);

  /// 漫游最大速度（逻辑像素/秒）：缓慢、无急停。
  static const double maxDriftSpeed = 55;

  /// 光灵世界坐标与相机坐标（相机缓慢跟随光灵）。
  Vector2 spiritPos = Vector2.zero();
  Vector2 camPos = Vector2.zero();
  Vector2 _spiritVelocity = Vector2.zero();
  Vector2? _touchPoint;

  /// 呼吸平稳度：|Δprogress| 的低通值，低于阈值视为"平稳呼吸"。
  double _breathJitter = 0;

  /// 当前是否处于平稳呼吸（供星岛苏醒判定）。
  bool get breathSteady => _breathJitter > 0.004 && _breathJitter < 0.35;

  /// 游戏运行秒数（供组件做微光动画）。
  double get time => _time;

  /// 呼气时长（秒）：松开约 4 秒归零。
  static const double exhaleDuration = 4.2;

  /// 呼吸阶段周期（秒），空闲自动节奏。
  static const double breathPeriod = 8.0;

  /// 认为循环"平稳"的最短时长（秒），过快的呼吸不计入苏醒度。
  static const double steadyCycleMinTime = 3.5;

  @override
  Future<void> onLoad() async {
    await awakening.load();
    await shardCollection.load();
    awakeningValue.value = awakening.value;

    final stars = <_Star>[];
    for (int i = 0; i < 90; i++) {
      stars.add(
        _Star(
          position: Vector2(_random.nextDouble(), _random.nextDouble()),
          radius: 0.4 + _random.nextDouble() * 1.2,
          twinklePhase: _random.nextDouble() * math.pi * 2,
          twinkleSpeed: 0.5 + _random.nextDouble() * 1.5,
        ),
      );
    }
    _starfield = _Starfield(stars);
    add(_starfield);

    _spirit = LightSpirit(tint: seedColor);

    // 失眠之海：星潮背景 -> 星岛 -> 光灵（渲染顺序）。
    final sea = InsomniaSea();
    add(sea);
    final rng = math.Random(42);
    for (int i = 0; i < 7; i++) {
      add(
        StarIsle(
          position: Vector2(
            (0.12 + 0.76 * rng.nextDouble()) * worldPeriod.x,
            (0.12 + 0.76 * rng.nextDouble()) * worldPeriod.y,
          ),
          radius: 42 + rng.nextDouble() * 46,
          shapeSeed: 100 + i * 17,
          tint: i.isEven ? ZenTheme.nebulaCyan : const Color(0xFF34d399),
        ),
      );
    }
    add(_spirit);

    // 心镜碎片：本轮漫游程序放置 2~4 片，散布在世界中（远离光灵起点）。
    final shardRng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final count = 2 + shardRng.nextInt(3);
    for (int i = 0; i < count; i++) {
      final pos = Vector2(
        (0.06 + 0.88 * shardRng.nextDouble()) * worldPeriod.x,
        (0.06 + 0.88 * shardRng.nextDouble()) * worldPeriod.y,
      );
      final shard = MindShard(
        position: pos,
        phase: shardRng.nextDouble() * math.pi * 2,
        tint: i.isOdd ? const Color(0xFF34d399) : ZenTheme.nebulaCyan,
      );
      shards.add(shard);
      add(shard);
    }
  }

  /// 刚完成一次平稳呼吸循环且尚未被碎片消费——供 MindShard 吸入判定。
  /// 被消费即返回 true 并清除（一次循环最多吸入一片）。
  bool consumeCycleEvent() {
    if (_pendingCycleEvent) {
      _pendingCycleEvent = false;
      return true;
    }
    return false;
  }

  bool _pendingCycleEvent = false;

  // 呼吸输入：按住=吸气，松开=呼气。
  @override
  void onTapDown(TapDownEvent event) {
    _pressing = true;
    _idleTime = 0;
    _touchPoint = event.canvasPosition.clone();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pressing = false;
    _touchPoint = null;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressing = false;
    _touchPoint = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    _updateBreath(dt);
    _updateAwakening(dt);
    _updateDrift(dt);
    _updateShards(dt);
  }

  /// 碎片吸入完成：记录收集史 + 通知 UI 浮现禅语。不打断漫游。
  void _updateShards(double dt) {
    for (final shard in List<MindShard>.of(shards)) {
      if (!shard.isAbsorbed) continue;
      shards.remove(shard);
      remove(shard);
      shardCollection.add(
        ShardRecord(
          time: DateTime.now(),
          text: shard.koan,
          region: regionNameFor(spiritPos),
        ),
      );
      shardMessage.value = shard.koan;
    }
  }

  /// 呼吸即移动：吸气蓄力——光灵缓缓朝触点上浮；
  /// 呼气滑行——沿当前方向缓缓漂移，无急停。
  void _updateDrift(double dt) {
    final damping = math.exp(-dt * 0.22);
    _spiritVelocity.scale(damping);

    if (_pressing) {
      // 吸气：朝触点方向的柔和引力，随呼吸进度增强（蓄力）。
      final spiritScreen = Vector2(
        gameSize.x / 2 + (spiritPos.x - camPos.x),
        gameSize.y / 2 + (spiritPos.y - camPos.y),
      );
      final target = _touchPoint;
      if (target != null) {
        final dir = Vector2(
          target.x - spiritScreen.x,
          target.y - spiritScreen.y,
        );
        final len = dir.length;
        if (len > 12) {
          dir.scale(1.0 / len);
          _spiritVelocity +=
              dir * (46.0 * (0.35 + 0.65 * _breathProgress)) * dt;
        }
      }
      // 吸气浮力：微微向上。
      _spiritVelocity.y -= 9.0 * dt;
    }

    // 限速：永远缓慢。
    final speed = _spiritVelocity.length;
    if (speed > maxDriftSpeed) {
      _spiritVelocity.scale(maxDriftSpeed / speed);
    }

    spiritPos += _spiritVelocity * dt;
    _wrap(spiritPos);

    // 相机极缓跟随：光灵在屏幕上只做小幅游移，世界在四周流动。
    final camDelta = spiritPos - camPos;
    _wrapDelta(camDelta);
    camPos += camDelta * math.min(1.0, dt * 1.1);
    // 相机与光灵保持在同一环绕单元，避免周期折叠时的坐标跳变。
    camPos.x = spiritPos.x + (camPos.x - spiritPos.x) % worldPeriod.x;
    camPos.y = spiritPos.y + (camPos.y - spiritPos.y) % worldPeriod.y;
  }

  void _wrap(Vector2 v) {
    v.x = v.x % worldPeriod.x;
    v.y = v.y % worldPeriod.y;
  }

  void _wrapDelta(Vector2 v) {
    if (v.x > worldPeriod.x / 2) v.x -= worldPeriod.x;
    if (v.x < -worldPeriod.x / 2) v.x += worldPeriod.x;
    if (v.y > worldPeriod.y / 2) v.y -= worldPeriod.y;
    if (v.y < -worldPeriod.y / 2) v.y += worldPeriod.y;
  }

  Vector2 get gameSize => size;

  void _updateBreath(double dt) {
    _prevBreathProgress = _breathProgress;
    _cycleTime += dt;

    // 平滑向目标推进：跟随输入速度，从不瞬跳、不惩罚过快。
    if (_pressing) {
      _breathProgress = (_breathProgress + dt / inhaleDuration).clamp(0.0, 1.0);
      _idleTime = 0;
    } else {
      _breathProgress = (_breathProgress - dt / exhaleDuration).clamp(0.0, 1.0);
      // 完全呼尽且继续无输入，才逐渐进入空闲自动节奏。
      if (_breathProgress <= 0.001) {
        _idleTime += dt;
      } else {
        _idleTime = 0;
      }
    }

    // 空闲 3 秒后淡入自动呼吸引导；有任何输入立即淡出。
    final autoTarget = (_idleTime > 3.0) ? 1.0 : 0.0;
    _autoWeight += (autoTarget - _autoWeight) * math.min(1.0, dt * 1.2);
    if (_autoWeight > 0.001) {
      final phase =
          (math.sin(math.pi * 2 * _time / breathPeriod - math.pi / 2) + 1) / 2;
      _breathProgress +=
          (phase - _breathProgress) * math.min(1.0, _autoWeight * dt * 1.6);
      _breathProgress = _breathProgress.clamp(0.0, 1.0);
    }

    _spirit.breatheProgress = _breathProgress;
    _spirit.glowBoost = 0.75 + 0.5 * awakeningValue.value;
    _starfield.awakening = awakeningValue.value;

    // 完整循环检测：先升至峰（>0.88）再落回谷（<0.12），且足够平稳。
    if (_prevBreathProgress < 0.88 && _breathProgress >= 0.88) {
      _cyclePeakReached = true;
    }
    if (_cyclePeakReached &&
        _prevBreathProgress > 0.12 &&
        _breathProgress <= 0.12) {
      if (_cycleTime >= steadyCycleMinTime) {
        _lastCompletedCycle = true;
        _pendingCycleEvent = true;
      }
      _cyclePeakReached = false;
      _cycleTime = 0;
    }

    // 呼吸提示词：按运动方向淡入"吸气…/呼气…"。
    final delta = _breathProgress - _prevBreathProgress;
    // 呼吸平稳度：对 |Δprogress| 做低通，用于星岛苏醒判定。
    final jitter = (delta.abs() / math.max(dt, 0.001)).clamp(0.0, 2.0);
    _breathJitter += (jitter - _breathJitter) * math.min(1.0, dt * 1.5);

    if (delta > 0.0002) {
      _setHint('吸气…');
    } else if (delta < -0.0002) {
      _setHint('呼气…');
    } else if (_breathProgress <= 0.001 && !(_autoWeight > 0.01)) {
      _setHint(null);
    }
  }

  bool _lastCompletedCycle = false;

  void _updateAwakening(double dt) {
    awakening.update(dt, completedCycle: _lastCompletedCycle);
    _lastCompletedCycle = false;
    awakeningValue.value = awakening.value;
  }

  void _setHint(String? hint) {
    if (breathHint.value != hint) {
      breathHint.value = hint;
    }
  }

  @override
  void onRemove() {
    awakening.save();
    super.onRemove();
  }
}

/// 星空背景层，把归一化坐标铺满视口。
/// 亮度、闪烁密度与背景色温随苏醒度渐变。
class _Starfield extends Component with HasGameReference<JingjingGame> {
  _Starfield(this.stars);

  final List<_Star> stars;
  double _elapsed = 0;

  /// 0..1 世界苏醒度，由游戏循环同步。
  double awakening = 0;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final aw = awakening;

    // 深空底色：苏醒度越高，背景色温越暖亮（黑 -> 靛蓝微光）。
    final bg = Color.lerp(
      ZenTheme.voidBlack,
      const Color(0xFF101828),
      0.35 * aw,
    )!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = bg);

    // 中央星云微光：随苏醒度扩散、色温偏暖。
    final nebulaInner = Color.lerp(
      ZenTheme.deepSpace,
      ZenTheme.nebulaCyan.withValues(alpha: 0.55),
      0.4 * aw,
    )!;
    final nebulaPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              nebulaInner.withValues(alpha: 0.85 + 0.15 * aw),
              bg,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.x / 2, size.y / 2),
              radius: size.length / (1.6 - 0.2 * aw),
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), nebulaPaint);

    for (final star in stars) {
      final twinkle =
          0.55 +
          0.45 * math.sin(_elapsed * star.twinkleSpeed * 2 + star.twinklePhase);
      // 亮度与闪烁幅度随苏醒度增强；高苏醒时更多星星参与闪烁。
      final active = star.twinkleSpeed > 1.6 - 1.1 * aw || aw > 0.85;
      final twinkleAmp = active ? 0.25 + 0.5 * aw : 0.0;
      final brightness = (0.22 + 0.35 * aw) + twinkleAmp * twinkle;
      final paint = Paint()
        ..color = ZenTheme.starWhite.withValues(
          alpha: brightness.clamp(0.0, 1.0),
        );
      canvas.drawCircle(
        Offset(star.position.x * size.x, star.position.y * size.y),
        star.radius,
        paint,
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
  }
}

class _Star {
  _Star({
    required this.position,
    required this.radius,
    required this.twinklePhase,
    required this.twinkleSpeed,
  });

  final Vector2 position;
  final double radius;
  final double twinklePhase;
  final double twinkleSpeed;
}

/// "光灵"：呼吸脉动的光球。
/// 吸气（progress 上升）时扩张上升并更亮，呼气时凝聚下沉。
/// [glowBoost] 随世界苏醒度增强光晕强度。
class LightSpirit extends Component with HasGameReference<JingjingGame> {
  LightSpirit({required this.tint});

  final Color tint;

  /// 0..1，由呼吸输入层驱动（平滑跟随，不瞬跳）。
  double breatheProgress = 0;

  /// 苏醒度光晕增益（约 0.75..1.25）。
  double glowBoost = 1;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    // 光灵世界坐标 -> 屏幕坐标：随漫游在屏上小幅游移。
    final base = Offset(size.x / 2, size.y / 2 - size.y * 0.04);
    final drift = Offset(
      game.spiritPos.x - game.camPos.x,
      game.spiritPos.y - game.camPos.y,
    );
    final center = base + drift;

    // 呼吸派生量。
    final expansion = 0.55 + 0.45 * breatheProgress;
    final rise = -size.y * 0.05 * breatheProgress;
    final orbCenter = Offset(center.dx, center.dy + rise);
    final maxRadius = math.min(size.x, size.y) * 0.18;
    final radius = maxRadius * expansion;
    final glow = (0.35 + 0.65 * breatheProgress) * glowBoost;

    // 多层呼吸光晕。
    for (int i = 5; i >= 0; i--) {
      final layerRadius = radius * 1.2 + i * radius * 0.28 * (0.5 + glow);
      final opacity = (0.12 - i * 0.018) * glow;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: (opacity * 2).clamp(0.0, 1.0)),
            ZenTheme.nebulaPurple.withValues(alpha: opacity.clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: layerRadius));
      canvas.drawCircle(orbCenter, layerRadius, paint);
    }

    // 光球本体。
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          ZenTheme.starWhite.withValues(alpha: 0.92),
          tint.withValues(alpha: 0.75),
          ZenTheme.nebulaPurple.withValues(alpha: 0.4),
          ZenTheme.voidBlack.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: radius));
    canvas.drawCircle(orbCenter, radius, bodyPaint);

    // 环绕微粒：吸气时外扩、呼气时收拢。
    final rng = math.Random(42);
    const particleCount = 18;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2 + rng.nextDouble() * 0.5;
      final distance =
          radius * 1.25 +
          breatheProgress * radius * 0.9 * (0.5 + rng.nextDouble() * 0.5);
      final p = Offset(
        orbCenter.dx + math.cos(angle) * distance,
        orbCenter.dy + math.sin(angle) * distance,
      );
      final opacity = ((0.75 - breatheProgress * 0.45) * (0.4 + glow * 0.6))
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        1.5 + rng.nextDouble() * 2.5,
        Paint()..color = ZenTheme.starWhite.withValues(alpha: opacity),
      );
    }

    // 底部提示文字随呼吸微弱明灭。
    final textPainter = TextPainter(
      text: TextSpan(
        text: '光灵 · 随呼吸起伏',
        style: TextStyle(
          color: ZenTheme.textMuted.withValues(
            alpha: (0.55 + 0.3 * glow).clamp(0.0, 1.0),
          ),
          fontSize: 13,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(orbCenter.dx - textPainter.width / 2, orbCenter.dy + radius + 42),
    );
  }
}
