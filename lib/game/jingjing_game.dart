import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;

import '../core/theme.dart';
import 'anxiety_abyss.dart';
import 'companion.dart';
import 'day_tide.dart';
import 'breath_mic.dart';
import 'awakening.dart';
import 'beast_gaze.dart';
import 'breath_flower.dart';
import 'full_awake.dart';
import 'insomnia_sea.dart';
import 'long_night.dart';
import 'long_absence.dart';
import 'long_night_whisper.dart';
import 'mist_guardian.dart';
import 'morning_star.dart';
import 'mist_wood.dart';
import 'onboarding.dart';
import 'perplex_planet.dart';
import 'quality.dart';
import 'regions.dart';
import 'reunion.dart';
import 'shard.dart';
import 'soundscape.dart';
import 'star_beast.dart';
import 'still_path.dart';
import 'weary_heath.dart';

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
      shardMessage = ValueNotifier<String?>(null),
      fullAwakeKoan = ValueNotifier<String?>(null),
      fullAwakeEnding = ValueNotifier(false),
      fullAwakeFast = ValueNotifier(false);

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

  /// 长夜记忆：是否进入过长夜（只存不用，供后续睡前章节统计）。
  final LongNightMemory longNight = LongNightMemory();

  /// 久别记忆（第 42 轮）：上次进入静境的时刻（jingxin.lastvisit.v1）。
  final LongAbsenceMemory longAbsence = LongAbsenceMemory();

  /// 久别偈（演出到点浮现的一句，约 10s 后由演出组件置 null 淡出）。
  final ValueNotifier<String?> longAbsenceKoan = ValueNotifier(null);

  /// 长夜程度（0..1）：setNight 后极缓滑向目标，驱动深夜色调/星亮/光晕收拢。
  double nightAmount = 0;
  bool _nightTarget = false;

  /// 视听联动（第 8 轮）：夜雨雨丝 / 篝火暖色的当前强度（0..1，极缓跟随）。
  double rainAmount = 0;
  double warmthAmount = 0;
  SoundscapeScene? _sceneTarget;

  /// 声景切换的视听联动：夜雨 -> 极淡雨丝；篝火 -> 极微暖色偏移。
  /// 仅作视觉暗示，声音淡入淡出由声景引擎负责。
  void setSoundscapeScene(SoundscapeScene? scene) {
    _sceneTarget = scene;
  }

  /// 呼吸之音（第 44 轮）：非空时每帧收到（相位 0..1、是否吸气、
  /// 是否平稳）。UI 层在呼吸之音开启且进入长夜时注入，退出长夜/
  /// 关闭开关时置回 null——引擎侧再校验 playing 与开关，双保险。
  void Function(double phase, bool inhaling, bool steady)? onBreathTone;

  /// 本轮程序放置的碎片（2~4 片，极稀疏）。
  final List<MindShard> shards = [];

  /// 星兽「眠」：失眠之海深处的长线存在（第 5 轮）。
  late final StarBeast beast;

  /// 纷心雾林（第 13 轮）；雾沉降度由星兽「惘」读取（第 17 轮）。
  late final MistWood mistWood;

  /// 星兽「惘」：雾林守林者（第 17 轮），相会演出读取其状态与端点。
  late final MistGuardian mistGuardian;

  /// 星兽「注视」（第 51 轮）：久伴 + 平稳呼吸换来的回望。
  /// 各兽一个控制器（纯逻辑在 beast_gaze.dart），内存态不持久化。
  final BeastGazeCtl gazeSleep = BeastGazeCtl();
  final BeastGazeCtl gazeMist = BeastGazeCtl();

  /// 静之径（第 14 轮），相会演出驱动其短暂亮起与径上尘聚拢。
  late final StillPath stillPath;

  /// 「相会」演出（第 18 轮）：眠与惘的稀有时刻（触发即自动运行）。
  late final ReunionEvent reunion;

  /// 「同频引路」（第 27 轮）：静之径附近的指尖陪伴互动。
  /// 状态机是纯逻辑（companion.dart），这里只持有实例并每帧喂输入。
  final CompanionGuide companion = CompanionGuide();

  /// 「满醒」终幕（第 28 轮）：世界第一次完全苏醒的回礼演出
  /// （一生一次；触发判定与记账在 full_awake.dart，纯函数可测）。
  late final FullAwakeEvent fullAwake;

  /// 「晨星」（第 29 轮）：满醒后世界里常驻的一枚醒痕
  /// （点击弹短偈；命中与互斥判定在此，逻辑在 morning_star.dart）。
  late final MorningStar morningStar;

  /// 满醒偈（演出到点浮现的一句），null=无——UI 层监听呈现。
  final ValueNotifier<String?> fullAwakeKoan;

  /// 满醒演出进入整体淡出（true 后 UI 层收走偈语与光效）。
  final ValueNotifier<bool> fullAwakeEnding;

  /// 满醒演出被触摸跳过（淡出用 0.9s 快速档）。
  final ValueNotifier<bool> fullAwakeFast;

  /// 晨光告别是否进行中（UI 层在演出起止时置位）——满醒演出的
  /// 互斥判定用：同帧冲突时后到者让先。
  bool farewellPlaying = false;

  /// 长按点的世界坐标（null=当前无按住）。每帧由屏幕触点换算，
  /// 相机移动时自然跟随。
  Vector2? _touchWorld;

  /// 「初次入静」开场呼吸引导（第 23 轮）：仅首次且未开随息时装配；
  /// 老用户/随息用户为 null，零打扰。
  OnboardingOverlay? onboarding;
  late final OnboardingPreference onboardingPref = OnboardingPreference();

  /// 已完成的平稳呼吸循环总数（星兽苏醒的独立事件源，不受碎片消费影响）。
  int cycleCount = 0;

  final math.Random _random = math.Random(42);
  late final LightSpirit _spirit;

  /// 星花花园（第 55 轮）：光灵平稳呼吸在身后种下呼吸的痕迹。
  late final BreathFlowerGarden _flowerGarden = BreathFlowerGarden();
  late final _Starfield _starfield;
  double _time = 0;

  // ---- 呼吸输入状态 ----
  bool _pressing = false;
  double _breathProgress = 0;
  double _prevBreathProgress = 0;
  double _idleTime = 0;

  // ---- 麦克风呼吸输入（第 9 轮，完全可选、默认关闭）----
  /// 由 UI 层在用户点击手势内设置；null = 触控模式。
  /// 引擎只输出 0..1 音量包络（绝不录音存储，见 breath_mic.dart）。
  BreathMicEngine? micEngine;

  /// 麦克风模式是否开启（驱动光灵的"声息涟漪"等细微反馈）。
  bool micBreathEnabled = false;

  /// 游戏侧对包络的再平滑镜像（0..1），供涟漪与呼吸跟随使用。
  double micEnvelope = 0;

  /// 两种输入源"最近活跃者"仲裁：各自的最后活跃时刻。
  double _lastTouchInputTime = -999;
  double _lastMicInputTime = -999;

  /// 开启/关闭麦克风呼吸输入。传 null 即回到纯触控模式。
  void enableMicBreath(BreathMicEngine? engine) {
    micEngine = engine;
    micBreathEnabled = engine != null;
    if (engine == null) {
      _lastMicInputTime = -999;
      micEnvelope = 0;
    }
  }

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
  /// 相机坐标 = 基准跟随位置 + 极缓的呼吸微动（第 11 轮：与呼吸相位
  /// 同相，幅度仅约 2 逻辑像素，整个世界随之极轻地"一起呼吸"）。
  Vector2 spiritPos = Vector2.zero();
  final Vector2 _camBase = Vector2.zero();
  Vector2 _spiritVelocity = Vector2.zero();
  final Vector2 _goalVelocity = Vector2.zero();
  Vector2? _touchPoint;

  /// 渲染用相机坐标的复用缓冲（第 16 轮性能审计）：camPos 原来是
  /// getter 每次调用都分配新 Vector2，而每个组件每帧都要读它——
  /// 现在每帧 update 开头算一次，所有组件共享同一个实例（只读）。
  final Vector2 _camPos = Vector2.zero();

  /// 光灵当前速度（供尾迹微粒等生命感细节读取）。
  Vector2 get spiritVelocity => _spiritVelocity;

  /// 渲染用相机坐标（基准 + 呼吸微动）。每帧 update 开头重算一次，
  /// 各组件每帧读取共享同一实例（绝不修改它）。
  Vector2 get camPos => _camPos;

  // ---- 开场苏醒（第 11 轮）：每次进入静境，世界从纯黑缓缓亮起 ----
  /// 开场进度（0..1，约 3.5 秒走完）。
  double introT = 0;

  /// 开场的平滑缓动（smoothstep），供星空/光灵按各自节奏苏醒。
  double get introEase {
    final t = introT.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  // ---- 平静的积累（第 11 轮）：长 time 平稳呼吸后光灵更亮更舒展 ----
  /// 本次会话累计的平稳循环数（只增不减，封顶在 calmGlow 内取用）。
  int _calmCycles = 0;

  /// 平静积累度（0..1，约 10 个平稳循环满）：体现在光灵的亮度与舒展上。
  double get calmGlow => (_calmCycles / 10).clamp(0.0, 1.0);

  // ---- 世界的回应（第 11 轮）：稀有、无声——远处的星同时眨了一下眼 ----
  double _blinkT = -1;
  double _lastBlinkTime = -999;

  /// 眨眼强度（0..1，约 0.9 秒一次柔和的起落），绝无提示文字。
  double get blinkStrength {
    if (_blinkT < 0) return 0;
    final t = (_blinkT / 0.9).clamp(0.0, 1.0);
    return math.sin(math.pi * t);
  }

  /// 光灵当前在「焦虑之渊」的深度（0..1，按区域深度带随漫游自然过渡）。
  double abyssDepth = 0;

  /// 光灵当前在「疲惫荒原」的深度（0..1，世界上部旷野带，与渊镜像对称）。
  double heathDepth = 0;

  /// 光灵当前在「纷心雾林」的深度（0..1，世界左/右接缝水平带，第 13 轮）。
  double mistDepth = 0;

  /// 呼吸平稳度：|Δprogress| 的低通值，低于阈值视为"平稳呼吸"。
  double _breathJitter = 0;

  /// 当前是否处于平稳呼吸（供星岛苏醒判定）。
  bool get breathSteady => _breathJitter > 0.004 && _breathJitter < 0.35;

  /// 呼吸抖动的低通值（供星花判定"紊乱"：抖动过大即呼吸乱了）。
  double get breathJitterLevel => _breathJitter;

  /// 当前是否按住（吸气中）——开场引导的提示词切换用（第 23 轮）。
  bool get breathPressing => _pressing;

  /// 当前呼吸相位 0..1（0=呼尽，1=吸满）——开场引导的淡入淡出用。
  double get breathPhase => _breathProgress;

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
    await longNight.load();
    await longAbsence.load();
    // 久别重逢（第 42 轮）：先读上一次时刻再写回本次（读到的那份才算"上次"）。
    unawaitedLongAbsenceMark();
    awakeningValue.value = awakening.value;

    final stars = <_Star>[];
    // 画质档位：低档星空减半（第 16 轮），仅数量、不改变任何行为。
    for (int i = 0; i < Quality.current.skyStars; i++) {
      final r = _random.nextDouble();
      stars.add(
        _Star(
          position: Vector2(_random.nextDouble(), _random.nextDouble()),
          radius: 0.4 + _random.nextDouble() * 1.2,
          twinklePhase: _random.nextDouble() * math.pi * 2,
          twinkleSpeed: 0.5 + _random.nextDouble() * 1.5,
          random: r,
        ),
      );
    }
    _starfield = _Starfield(stars);
    add(_starfield);

    _spirit = LightSpirit(tint: seedColor);

    // 失眠之海：星潮背景 -> 焦虑之渊（海的更深处）-> 星兽 -> 星岛 -> 光灵。
    final sea = InsomniaSea();
    add(sea);
    add(WearyHeath());
    add(AnxietyAbyss());
    mistWood = MistWood();
    add(mistWood);
    // 星兽「惘」：雾林接缝带的守林者（第 17 轮），显形跟随雾沉降。
    mistGuardian = MistGuardian();
    add(mistGuardian);
    stillPath = StillPath(); // 静之径：区域间的余温旅程线（第 14 轮）。
    add(stillPath);
    beast = StarBeast();
    add(beast);
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
    // 星花花园：画在光灵身后（先 add 先画，被光灵覆盖）——呼吸的
    // 痕迹（第 55 轮），不给碎片不给分数，纯粹是世界的美与回应。
    add(_flowerGarden);

    add(_spirit);

    // 同频引路的星尘尾迹（第 27 轮）：画在光灵之上、演出层之下，
    // 粒子池固定，光灵未接近指尖时零渲染成本。
    add(CompanionDust());

    // 心镜碎片：本轮漫游程序放置 2~4 片，散布在世界中（远离光灵起点）。
    // 碎片按序号分配心境区域：i%4==1 沉入「焦虑之渊」深度带，
    // i%4==2 上浮「疲惫荒原」旷野带，i%4==3 漂入「纷心雾林」接缝带
    // （各自用专属偈语池）。
    final shardRng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final count = 2 + shardRng.nextInt(3);
    final abyssBand = GameRegion.anxietyAbyss;
    final heathBand = GameRegion.wearyHeath;
    for (int i = 0; i < count; i++) {
      final inAbyss = i % 4 == 1;
      final inHeath = i % 4 == 2;
      final inMist = i % 4 == 3;
      double ny;
      double nx = 0.06 + 0.88 * shardRng.nextDouble();
      if (inAbyss) {
        ny = abyssBand.depthStart +
            0.02 + shardRng.nextDouble() * (0.98 - abyssBand.depthStart);
      } else if (inHeath) {
        ny = heathBand.depthFull - 0.03 -
            shardRng.nextDouble() * (heathBand.depthFull - 0.02);
      } else if (inMist) {
        // 雾林碎片：贴着 x 接缝的林深处（nx 或 1-nx 小），ny 在门带中段。
        final side = shardRng.nextBool();
        final off = 0.04 + shardRng.nextDouble() * 0.20;
        nx = side ? off : 1.0 - off;
        ny = 0.33 + shardRng.nextDouble() * 0.32;
      } else {
        ny = 0.06 + 0.88 * shardRng.nextDouble();
      }
      final pos = Vector2(
        nx * worldPeriod.x,
        ny * worldPeriod.y,
      );
      final shard = MindShard(
        position: pos,
        phase: shardRng.nextDouble() * math.pi * 2,
        tint: inAbyss
            ? const Color(0xFFc9a0b8)
            : inHeath
            ? const Color(0xFFd8bc8e)
            : inMist
            ? const Color(0xFF9cc8b8)
            : ZenTheme.nebulaCyan,
        abyss: inAbyss,
        heath: inHeath,
        mist: inMist,
      );
      shards.add(shard);
      add(shard);
    }

    // 昼夜潮汐（第 36 轮）：按本地真实时刻的全屏极淡 tint（画在
    // 世界之上、声景天气与演出层之下，长夜激活时自动让位归零）。
    add(DayTideLayer());

    // 声景视听联动层（最顶层渲染，极淡）：夜雨雨丝 / 篝火暖色偏移。
    add(_NightWeather());

    // 「相会」演出（第 18 轮）：最后装配，星光连线与涟漪渲染在最上层；
    // 平时 idle 只做轻量条件检查，零渲染成本。
    reunion = ReunionEvent(beast: beast, guardian: mistGuardian, path: stillPath);
    add(reunion);

    // 「初次入静」开场呼吸引导（第 23 轮）：仅当从未完成过引导且本次
    // 未开启随息麦克风时装配（最上层渲染）；条件不满足即零打扰。
    await onboardingPref.load();
    if (!onboardingPref.onboarded && !micBreathEnabled) {
      onboarding = OnboardingOverlay(pref: onboardingPref);
      add(onboarding!);
    }

    // 「满醒」终幕（第 28 轮）：最后装配，光潮与提亮渲染在最上层；
    // idle 时只做一次纯函数触发判定，零渲染成本。
    fullAwake = FullAwakeEvent(beast: beast, guardian: mistGuardian);
    add(fullAwake);

    // 「晨星」（第 29 轮）：满醒后常驻的醒痕——只读"已演过"标记，
    // 未满醒过时零渲染成本；画在演出层之上，不与演出争光（互斥在点击侧）。
    morningStar = MorningStar();
    add(morningStar);

    // 「久别重逢」演出（第 42 轮）：最后装配，进入初期只做一次判定，
    // 未命中零渲染成本。
    add(LongAbsenceEvent());

    // 「惑星」（第 43 轮）：偶发的心结微挑战——状态机纯逻辑在
    // perplex_planet.dart，这里只装配组件（hidden 时零渲染成本）。
    add(PerplexPlanet());
  }

  /// 久别时刻写回（fire-and-forget，失败静默——演出不依赖它成功）。
  void unawaitedLongAbsenceMark() {
    // ignore: discarded_futures
    longAbsence.markVisitNow(DateTime.now());
  }

  /// 「星兽低语」（第 32 轮）：长夜里距玩家较近的那只星兽身旁
  /// 极淡地浮现一句入睡偈（UI 层调度触发；此处只选兽与渲染）。
  /// 重复触发时旧低语直接退场（synth 只有一句，礼仪一致）。
  void showBeastWhisper(String text) {
    // 距玩家较近的那只星兽（环绕最短距离判定）。
    final dSleep = _wrapDistance2(beast.pos, spiritPos);
    final dWang = _wrapDistance2(mistGuardian.pos, spiritPos);
    showBeastWhisperFor(text, followMist: dWang < dSleep);
  }

  /// 指定跟随某只星兽的低语（第 51 轮「注视」用：谁回望谁低语）。
  void showBeastWhisperFor(String text, {required bool followMist}) {
    beastWhisper?.removeFromParent();
    beastWhisper = BeastWhisperText(text: text, followMist: followMist);
    add(beastWhisper!);
  }

  /// 当前进行中的星兽低语（null = 无；触摸打断用）。
  BeastWhisperText? beastWhisper;

  /// 两点环绕最短距离的平方（复用 wrapDelta 的最短差约定）。
  double _wrapDistance2(Vector2 a, Vector2 b) {
    final d = a - b;
    wrapDelta(d);
    return d.length2;
  }

  /// 用户开启随息麦克风时取消引导（零打扰原则）：立即退场并打上
  /// 已引导标记，之后永不再现。
  void cancelOnboarding() {
    onboarding?.removeFromParent();
    onboarding = null;
    // ignore: discarded_futures
    onboardingPref.markOnboarded();
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
    _lastTouchInputTime = _time;
    _touchPoint = event.canvasPosition.clone();

    // 晨星（第 29 轮）：点击命中检测——与各演出互斥（演出中点击无效，
    // 后到者让先的既有约定）。呼吸按压照常进行，互不惊扰。
    if (onboarding == null &&
        !reunion.active &&
        !fullAwake.active &&
        !farewellPlaying) {
      final p = event.canvasPosition;
      _tapWorldTmp
        ..x = camPos.x + p.x - size.x / 2
        ..y = camPos.y + p.y - size.y / 2;
      morningStar.onTap(_tapWorldTmp);
    }

    // 星兽低语（第 32 轮）：用户任何触摸立即淡出当前低语。
    beastWhisper?.dismiss();
  }

  /// 点击命中检测用的复用缓冲（零分配）。
  final Vector2 _tapWorldTmp = Vector2.zero();

  @override
  void onTapUp(TapUpEvent event) {
    _pressing = false;
    _lastTouchInputTime = _time;
    _touchPoint = null;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressing = false;
    _lastTouchInputTime = _time;
    _touchPoint = null;
  }

  @override
  void update(double dt) {
    // 相机渲染坐标每帧先算一次（所有组件共享，避免 getter 重复分配）。
    _camPos
      ..setFrom(_camBase)
      ..x += math.cos(_breathProgress * math.pi * 2 - math.pi / 2) * 1.4
      ..y += math.sin(_breathProgress * math.pi * 2 - math.pi / 2) * 2.2;
    super.update(dt);
    _time += dt;

    // 开场苏醒：约 3.5 秒从纯黑缓缓亮起（每次进入，克制而快）。
    if (introT < 1) introT = (introT + dt / 3.5).clamp(0.0, 1.0);

    // 世界的回应：眨眼的起落（约 0.9 秒，极柔）。
    if (_blinkT >= 0) {
      _blinkT += dt;
      if (_blinkT > 0.9) _blinkT = -1;
    }

    _updateBreath(dt);
    _updateAwakening(dt);
    _updateCompanion(dt);
    _updateDrift(dt);
    _updateShards(dt);

    // 长夜渐变：约 4 秒缓缓滑向目标，不瞬跳。
    final nightGoal = _nightTarget ? 1.0 : 0.0;
    nightAmount += (nightGoal - nightAmount) * math.min(1.0, dt * 0.8);
    if ((nightAmount - nightGoal).abs() < 0.002) nightAmount = nightGoal;

    // 声景视听联动：雨丝/暖色极缓跟随（淡入淡出与声音交叉渐变同量级）。
    final rainGoal = (_sceneTarget == SoundscapeScene.rain) ? 1.0 : 0.0;
    final warmGoal = (_sceneTarget == SoundscapeScene.campfire) ? 1.0 : 0.0;
    rainAmount += (rainGoal - rainAmount) * math.min(1.0, dt * 0.5);
    warmthAmount += (warmGoal - warmthAmount) * math.min(1.0, dt * 0.5);
    if (rainAmount < 0.003) rainAmount = 0;
    if (warmthAmount < 0.003) warmthAmount = 0;
  }

  /// 进入/退出长夜（声音淡入淡出由 UI 层的声景引擎负责）。
  void setNight(bool on) {
    _nightTarget = on;
  }

  /// 晨光告别（第 26 轮）：t∈0..1，驱动星兽眯眼（睁眼目标等比压低，
  /// 沿用每只眼约 4 秒的既有渐变——天亮时分缓缓眯起，不是惊醒闭眼）。
  void setFarewell(double t) {
    beast.squint = t.clamp(0.0, 1.0);
  }

  /// 碎片吸入完成：记录收集史 + 通知 UI 浮现禅语。不打断漫游。
  void _updateShards(double dt) {
    // 逆序遍历：避免每帧复制列表（减少 GC 压力）。
    for (var i = shards.length - 1; i >= 0; i--) {
      final shard = shards[i];
      if (!shard.isAbsorbed) continue;
      shards.removeAt(i);
      remove(shard);
      shardCollection.add(
        ShardRecord(
          time: DateTime.now(),
          text: shard.koan,
          // 相会双星碎片：专属收录区域「两兽之间」（第 18 轮）。
          region: shard.reunion ? '两兽之间' : regionNameFor(spiritPos),
        ),
      );
      shardMessage.value = shard.koan;
      beast.state.onShard();
    }
  }

  /// 同频引路（第 27 轮）：把触点换算成世界坐标喂给状态机；接近中
  /// 且长按点落在静之径上时，给该段路径「续余温」（沿用既有机制）。
  void _updateCompanion(double dt) {
    final tp = _touchPoint;
    if (tp != null && _pressing) {
      final tw = _touchWorld ??= Vector2.zero();
      tw.x = camPos.x + tp.x - size.x / 2;
      tw.y = camPos.y + tp.y - size.y / 2;
    } else {
      _touchWorld = null;
    }

    // 演出互斥：开场引导 / 相会演出 / 满醒终幕进行中不触发（也不打断已开始的）。
    final blocked =
        onboarding != null || reunion.active || fullAwake.active;
    final tw2 = _touchWorld;
    var withinStop = false;
    if (tw2 != null) {
      final dx = tw2.x - spiritPos.x;
      final dy = tw2.y - spiritPos.y;
      final wx =
          dx.abs() > worldPeriod.x / 2 ? dx - worldPeriod.x * dx.sign : dx;
      final wy =
          dy.abs() > worldPeriod.y / 2 ? dy - worldPeriod.y * dy.sign : dy;
      withinStop =
          wx * wx + wy * wy < CompanionGuide.stopDistance * CompanionGuide.stopDistance;
    }
    companion.update(
      holding: _pressing,
      withinStopDistance: withinStop,
      blocked: blocked,
      dt: dt,
    );

    // 长按点在径上（<onPathDistance）→ 额外续余温：该段微亮如被走过。
    if (companion.state == CompanionState.approaching && tw2 != null) {
      if (stillPath.distanceToPoint(tw2) < StillPath.onPathDistance) {
        stillPath.warmNearPoint(tw2, dt);
      }
    }
  }

  /// 呼吸即移动：吸气蓄力——光灵缓缓朝触点上浮；
  /// 呼气滑行——沿当前方向缓缓漂移，无急停。
  /// 同频引路（第 27 轮）接近中：改走极缓漂移通道（缓动、无急加速，
  /// 目标速度仅 12px/s），停驻距离内悬停；停驻期光灵轻轻收停在原地。
  void _updateDrift(double dt) {
    final companionActive = companion.state == CompanionState.approaching;
    final damping = math.exp(-dt * (companion.state == CompanionState.resting ? 2.5 : 0.22));
    _spiritVelocity.scale(damping);

    if (companionActive) {
      final target = _touchWorld;
      if (companion.moving && target != null) {
        // 极缓的追踪速度（一阶惯性，无急加速），至多 12px/s。
        var dx = target.x - spiritPos.x;
        var dy = target.y - spiritPos.y;
        if (dx.abs() > worldPeriod.x / 2) dx -= worldPeriod.x * dx.sign;
        if (dy.abs() > worldPeriod.y / 2) dy -= worldPeriod.y * dy.sign;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > CompanionGuide.stopDistance) {
          final speed = math.min(12.0, dist * 0.35);
          _goalVelocity.setValues(dx / dist * speed, dy / dist * speed);
          _spiritVelocity +=
              (_goalVelocity - _spiritVelocity) * math.min(1.0, dt * 1.4);
        }
      }
    } else if (_pressing) {
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
    wrap(spiritPos);

    // 区域深度：按光灵所在归一化坐标平滑过渡（渊在海的更深处，
    // 荒原在世界上部的旷野带，雾林在世界左右接缝的水平边缘带）。
    final ny = spiritPos.y / worldPeriod.y;
    abyssDepth = GameRegion.anxietyAbyss.depthAt(ny);
    heathDepth = GameRegion.wearyHeath.depthAt(ny);
    mistDepth = GameRegion.mistWood.depthAtPoint(
      spiritPos.x / worldPeriod.x,
      ny,
    );

    // 相机极缓跟随：光灵在屏幕上只做小幅游移，世界在四周流动。
    final camDelta = spiritPos - _camBase;
    wrapDelta(camDelta);
    _camBase.add(camDelta * math.min(1.0, dt * 1.1));
    // 相机与光灵保持在同一环绕单元，避免周期折叠时的坐标跳变。
    _camBase.x = spiritPos.x + (_camBase.x - spiritPos.x) % worldPeriod.x;
    _camBase.y = spiritPos.y + (_camBase.y - spiritPos.y) % worldPeriod.y;
  }

  /// 按环绕周期把坐标折回世界单元（供星兽等组件复用）。
  void wrap(Vector2 v) {
    v.x = v.x % worldPeriod.x;
    v.y = v.y % worldPeriod.y;
  }

  /// 把位移向量折算成最短环绕差（供星兽等组件计算环绕距离）。
  void wrapDelta(Vector2 v) {
    if (v.x > worldPeriod.x / 2) v.x -= worldPeriod.x;
    if (v.x < -worldPeriod.x / 2) v.x += worldPeriod.x;
    if (v.y > worldPeriod.y / 2) v.y -= worldPeriod.y;
    if (v.y < -worldPeriod.y / 2) v.y += worldPeriod.y;
  }

  Vector2 get gameSize => size;

  void _updateBreath(double dt) {
    _prevBreathProgress = _breathProgress;
    _cycleTime += dt;

    // 麦克风包络镜像：游戏侧再低通一次（引擎已慢平滑，这里是双保险），
    // 并用"包络有明显变化"作为麦克风输入活跃的信号（最近活跃者仲裁）。
    final mic = micEngine;
    final micLive = mic != null && micBreathEnabled && mic.isRunning;
    if (micLive) {
      final env = mic.envelope;
      if ((env - micEnvelope).abs() > 0.008) _lastMicInputTime = _time;
      micEnvelope += (env - micEnvelope) * math.min(1.0, dt * 3.0);
    } else {
      micEnvelope += (0 - micEnvelope) * math.min(1.0, dt * 2.0);
      if (micEnvelope < 0.002) micEnvelope = 0;
    }
    // 两种输入源取最近活跃者：触控随时可接管，气息重新起伏时自然交还。
    final touchWins = _lastTouchInputTime >= _lastMicInputTime;
    final micWins = micLive && !touchWins;

    // 平滑向目标推进：跟随输入速度，从不瞬跳、不惩罚过快。
    if (_pressing) {
      _breathProgress = (_breathProgress + dt / inhaleDuration).clamp(0.0, 1.0);
      _idleTime = 0;
    } else if (micWins) {
      // 麦克风模式（随息）：吹气是呼——音量包络高 = 呼气段（进度下沉），
      // 回落安静 = 吸气段（进度回升）。柔和跟随（约 0.4s 惯性），
      // 相位来源可替换：下游苏醒度/漫游/星岛/碎片/星兽全部复用不变。
      final micTarget = 1.0 - micEnvelope;
      _breathProgress +=
          (micTarget - _breathProgress) * math.min(1.0, dt * 2.4);
      _breathProgress = _breathProgress.clamp(0.0, 1.0);
      _idleTime = 0; // 有真实气息输入就不进入空闲自动节奏。
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
        cycleCount++;
        _calmCycles++;
        // 稀有的"世界回应"：约 6% 的平稳循环后，远处的星同时眨一下眼。
        // 无文字无音效，只是世界活着的一次轻颤。
        if (_random.nextDouble() < 0.06 && _time - _lastBlinkTime > 40) {
          _blinkT = 0;
          _lastBlinkTime = _time;
        }
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

    // 呼吸之音（第 44 轮）：UI 层在开关开启时注入回调；引擎每帧
    // 把相位/方向/平稳度喂出去，发声与让位（duck）由声景引擎负责。
    final breathCb = onBreathTone;
    if (breathCb != null) {
      breathCb(_breathProgress, delta > 0, breathSteady);
    }
  }

  bool _lastCompletedCycle = false;

  void _updateAwakening(double dt) {
    awakening.update(dt, completedCycle: _lastCompletedCycle);
    _lastCompletedCycle = false;
    var value = awakening.value;
    // 久别回礼（第 42 轮）：演出期间世界提前 10% 苏醒——仅视觉，
    // 不碰 AwakeningState 的持久化数值（回礼是情感，不是货币）。
    if (longAbsenceActive) {
      value = (value + LongAbsenceEvent.awakeningGift).clamp(0.0, 1.0);
    }
    awakeningValue.value = value;
  }

  /// 「久别重逢」演出是否进行中（由 LongAbsenceEvent 置位，游戏侧镜像）。
  bool longAbsenceActive = false;

  void _setHint(String? hint) {
    if (breathHint.value != hint) {
      breathHint.value = hint;
    }
  }

  @override
  void onRemove() {
    awakening.save();
    beast.state.save();
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

  // 复用的画笔与缓存的星云着色器（减少每帧分配）。
  final Paint _starPaint = Paint();
  final Paint _nebulaPaint = Paint();
  final Paint _bgPaint = Paint(); // 底色画笔复用（每帧只换色）。
  Shader? _nebulaShader;
  int _nebulaKey = -1;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final aw = awakening;
    final intro = game.introEase;

    // 深空底色：苏醒度越高，背景色温越暖亮（黑 -> 靛蓝微光）。
    final bg = Color.lerp(
      ZenTheme.voidBlack,
      const Color(0xFF101828),
      0.35 * aw,
    )!;
    // 长夜：整体转入更深的夜色（比苏醒底色更暗）。
    final night = game.nightAmount;
    final deepBg = Color.lerp(bg, const Color(0xFF030711), 0.85 * night)!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _bgPaint..color = deepBg);

    // 中央星云微光：随苏醒度扩散、色温偏暖（着色器按量化参数缓存）。
    final lenQ = (size.length / 8).round();
    final key =
        ((aw * 50).round() * 10000 + (night * 50).round()) * 100000 + lenQ;
    if (key != _nebulaKey || _nebulaShader == null) {
      _nebulaKey = key;
      final nebulaInner = Color.lerp(
        ZenTheme.deepSpace,
        ZenTheme.nebulaCyan.withValues(alpha: 0.55),
        0.4 * aw,
      )!;
      _nebulaShader = RadialGradient(
        colors: [nebulaInner.withValues(alpha: 0.85 + 0.15 * aw), deepBg],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.x / 2, size.y / 2),
          radius: size.length / (1.6 - 0.2 * aw),
        ),
      );
    }
    _nebulaPaint.shader = _nebulaShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _nebulaPaint);

    // 世界的回应（第 11 轮）：眨眼时远处的星柔和地一起亮一下。
    final blink = game.blinkStrength;

    for (final star in stars) {
      // 开场苏醒：星按各自的时刻逐颗亮起（克制的错落，不整齐划一）。
      final reveal = ((intro * 1.55 - star.revealDelay) / 0.28).clamp(0.0, 1.0);
      if (reveal <= 0) continue;

      final twinkle =
          0.55 +
          0.45 * math.sin(_elapsed * star.twinkleSpeed * 2 + star.twinklePhase);
      // 亮度与闪烁幅度随苏醒度增强；高苏醒时更多星星参与闪烁。
      final active =
          star.twinkleSpeed > 1.6 - 1.1 * aw || aw > 0.85 || night > 0.5;
      final twinkleAmp = active ? 0.25 + 0.5 * aw : 0.0;
      // 长夜：星更亮，暗星也被轻轻托起。
      var brightness =
          (0.22 + 0.35 * aw + 0.22 * night) + twinkleAmp * twinkle;
      if (blink > 0 && reveal > 0.9) {
        brightness += 0.38 * blink * star.blinkAffinity;
      }
      brightness = (brightness * (0.12 + 0.88 * reveal)).clamp(0.0, 1.0);
      _starPaint.color = ZenTheme.starWhite.withValues(alpha: brightness);
      canvas.drawCircle(
        Offset(star.position.x * size.x, star.position.y * size.y),
        star.radius,
        _starPaint,
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
    required double random,
  }) : revealDelay = 0.15 + random * 1.2,
       blinkAffinity = random * random;

  final Vector2 position;
  final double radius;
  final double twinklePhase;
  final double twinkleSpeed;

  /// 开场苏醒的错落时刻（0..~1.35，越大亮起越晚）。
  final double revealDelay;

  /// "世界眨眼"的亲和度（0..1，平方分布——只有少数星明显回应）。
  final double blinkAffinity;
}

/// "光灵"：呼吸脉动的光球。
/// 吸气（progress 上升）时扩张上升并更亮，呼气时凝聚下沉。
/// [glowBoost] 随世界苏醒度增强光晕强度。
class LightSpirit extends Component with HasGameReference<JingjingGame> {
  LightSpirit({required this.tint}) {
    // 环绕微粒的固定参数（预生成，避免每帧分配 Random 与对象）。
    // 数量按画质档位削减（第 16 轮），只减数量不减呼吸感。
    final rng = math.Random(42);
    for (int i = 0; i < Quality.current.orbParticles; i++) {
      _particles.add(
        _OrbParticle(
          angle: (i / Quality.current.orbParticles) * math.pi * 2 +
              rng.nextDouble() * 0.5,
          distFactor: 0.5 + rng.nextDouble() * 0.5,
          size: 1.5 + rng.nextDouble() * 2.5,
        ),
      );
    }
  }

  final Color tint;

  /// 环绕微粒数量（按画质档位，见构造函数）。
  static const int particleCount = 18;
  final List<_OrbParticle> _particles = [];

  /// 标签文字的预排版（只 layout 一次）。
  TextPainter? _labelPainter;

  // ---- 第 16 轮性能审计：光灵原本每帧新建 7 个 RadialGradient 着色器
  //（6 层辉光 + 本体），是每帧最贵的分配。改为：着色器统一按固定
  // 半径 100 构建，绘制时用 canvas 缩放到实际半径（径向渐变缩放后
  // 视觉完全一致）；alpha 变化（辉光强度/半径）按粗粒度量化缓存，
  // 呼吸是准周期的，缓存暖机后几乎零重建。
  static const double _shaderRadius = 100;
  final Map<int, Shader> _glowShaders = {};
  final Map<int, Shader> _bodyShaders = {};
  final List<Paint> _glowPaints = List.generate(6, (_) => Paint());
  final Paint _bodyPaint = Paint();
  final Paint _trailPaint = Paint();
  final Paint _particlePaint = Paint();
  final Paint _ripplePaint = Paint();
  final Path _orbPath = Path();

  Shader? _glowShader(int layer, double glow) {
    final q = (glow * 20).round().clamp(0, 60); // 0.05 步进
    final key = layer * 100 + q;
    return _glowShaders[key] ??= () {
      final g = q / 20; // 用量化后的 glow 构建缓存（视觉差异不可感）
      final opacity = (0.12 - layer * 0.018) * g; // 每层基准透明度 × 辉光
      return RadialGradient(
        colors: [
          tint.withValues(alpha: (opacity * 2).clamp(0.0, 1.0)),
          ZenTheme.nebulaPurple.withValues(alpha: opacity.clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: _shaderRadius),
      );
    }();
  }

  Shader _bodyShader() {
    final q = (breatheProgress * 40).round().clamp(0, 40); // 0.025 步进
    return _bodyShaders[q] ??= RadialGradient(
      colors: [
        ZenTheme.starWhite.withValues(alpha: 0.92),
        tint.withValues(alpha: 0.75),
        ZenTheme.nebulaPurple.withValues(alpha: 0.4),
        ZenTheme.voidBlack.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    ).createShader(
      Rect.fromCircle(center: Offset.zero, radius: _shaderRadius),
    );
  }

  /// 0..1，由呼吸输入层驱动（平滑跟随，不瞬跳）。
  double breatheProgress = 0;

  /// 苏醒度光晕增益（约 0.75..1.25）。
  double glowBoost = 1;

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final intro = game.introEase;
    if (intro <= 0.01) return; // 开场：世界还黑着，光灵尚未醒来。
    final calm = game.calmGlow;
    final t = game.time;

    // 光灵世界坐标 -> 屏幕坐标：随漫游在屏上小幅游移。
    final base = Offset(size.x / 2, size.y / 2 - size.y * 0.04);
    final drift = Offset(
      game.spiritPos.x - game.camPos.x,
      game.spiritPos.y - game.camPos.y,
    );
    final center = base + drift;

    // 呼吸派生量。平静的积累：更亮、更舒展（长 time 平稳呼吸的痕迹）。
    final expansion = 0.55 + 0.45 * breatheProgress + 0.05 * calm;
    final rise = -size.y * 0.05 * breatheProgress;
    final orbCenter = Offset(center.dx, center.dy + rise);
    final maxRadius = math.min(size.x, size.y) * 0.18;
    // 长夜：光晕收拢变柔——外层辉光更小更淡，本体稍收。
    final nightSoften = 1.0 - 0.3 * game.nightAmount;
    final radius =
        maxRadius * expansion * nightSoften * (0.55 + 0.45 * intro);
    final glow =
        (0.35 + 0.65 * breatheProgress) *
        glowBoost *
        nightSoften *
        (0.25 + 0.75 * intro) *
        (1 + 0.18 * calm);

    // 多层呼吸光晕：着色器按固定半径缓存，绘制时缩放到实际半径。
    for (int i = 5; i >= 0; i--) {
      final layerRadius = radius * 1.2 + i * radius * 0.28 * (0.5 + glow);
      final shader = _glowShader(i, glow);
      if (shader == null) continue;
      final paint = _glowPaints[i]..shader = shader;
      canvas.save();
      canvas.translate(orbCenter.dx, orbCenter.dy);
      canvas.scale(layerRadius / _shaderRadius);
      canvas.drawCircle(Offset.zero, _shaderRadius, paint);
      canvas.restore();
    }

    // 光球本体：边缘带轻微呼吸噪声形变（顶点微扰而非贴图），
    // 光灵像一滴活着的 光，而不是一枚标准的圆。
    _bodyPaint.shader = _bodyShader();
    final orb = _orbPath..reset();
    const segments = 28;
    for (int i = 0; i <= segments; i++) {
      final a = i / segments * math.pi * 2;
      final wobble =
          1 +
          0.028 * math.sin(a * 3 + t * 1.1) +
          0.02 * math.sin(a * 5 - t * 0.7);
      final r = radius * wobble;
      final p = Offset(
        orbCenter.dx + math.cos(a) * r,
        orbCenter.dy + math.sin(a) * r,
      );
      if (i == 0) {
        orb.moveTo(p.dx, p.dy);
      } else {
        orb.lineTo(p.dx, p.dy);
      }
    }
    orb.close();
    canvas.drawPath(orb, _bodyPaint);

    // 尾迹微粒（第 11 轮）：朝游动方向的反向留下一串渐隐的光尘，
    // 让光灵的移动有"穿过世界"的朝向感。数量按画质档位削减。
    final vel = game.spiritVelocity;
    final speed = vel.length;
    if (speed > 5) {
      final dx = vel.x / speed;
      final dy = vel.y / speed;
      final trail = Quality.current.spiritTrail;
      for (int i = 1; i <= trail; i++) {
        final d = i * radius * 0.24 * (0.6 + breatheProgress * 0.6);
        final fade = (1 - i / (trail + 1)) * 0.11 * intro;
        canvas.drawCircle(
          Offset(orbCenter.dx - dx * d, orbCenter.dy - dy * d),
          1.6 + (trail - i) * 0.4,
          _trailPaint..color = tint.withValues(alpha: fade),
        );
      }
    }

    // 声息涟漪（第 9 轮）：麦克风呼吸开启时，光灵边缘一圈极淡的涟漪
    // 随音量包络脉动（alpha 峰值仅 0.15），世界感知到"真实的气息"。
    if (game.micBreathEnabled && game.micEnvelope > 0.015) {
      final pulse = game.micEnvelope;
      final ringPaint = _ripplePaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = tint.withValues(alpha: 0.15 * pulse);
      canvas.drawCircle(
        orbCenter,
        radius * (1.32 + 0.28 * pulse),
        ringPaint,
      );
      // 更外一圈更淡的余韵，让涟漪有层次而非单线。
      ringPaint.color = tint.withValues(alpha: 0.07 * pulse);
      canvas.drawCircle(
        orbCenter,
        radius * (1.62 + 0.42 * pulse),
        ringPaint,
      );
    }

    // 环绕微粒：吸气时外扩、呼气时收拢。
    final particleOpacity =
        ((0.75 - breatheProgress * 0.45) * (0.4 + glow * 0.6) * intro)
            .clamp(0.0, 1.0);
    for (final particle in _particles) {
      final wobbleAngle = particle.angle + math.sin(t * 0.6 + particle.angle * 3) * 0.12;
      final distance =
          radius * 1.25 +
          breatheProgress * radius * 0.9 * particle.distFactor;
      final p = Offset(
        orbCenter.dx + math.cos(wobbleAngle) * distance,
        orbCenter.dy + math.sin(wobbleAngle) * distance,
      );
      canvas.drawCircle(
        p,
        particle.size,
        _particlePaint..color = ZenTheme.starWhite.withValues(
          alpha: particleOpacity,
        ),
      );
    }

    // 底部提示文字：预排版一次，开场后稳定呈现。
    if (intro > 0.55) {
      final label = _labelPainter ??= TextPainter(
        text: TextSpan(
          text: '光灵 · 随呼吸起伏',
          style: TextStyle(
            color: ZenTheme.textMuted.withValues(alpha: 0.62),
            fontSize: 13,
            letterSpacing: 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(orbCenter.dx - label.width / 2, orbCenter.dy + radius + 42),
      );
    }
  }
}

/// 光灵环绕微粒的固定参数（预生成，渲染零分配）。
class _OrbParticle {
  _OrbParticle({
    required this.angle,
    required this.distFactor,
    required this.size,
  });

  final double angle;
  final double distFactor;
  final double size;
}

/// 声景视听联动层（第 8 轮）：夜雨时叠加极淡雨丝缓落，篝火时背景
/// 带极微弱暖色偏移。强度与长夜程度相乘（退出长夜自然消散），
/// CYBER-ZEN 克制原则——只是"感到"，从不显眼。
class _NightWeather extends Component with HasGameReference<JingjingGame> {
  _NightWeather() {
    // 雨丝数量按画质档位削减（第 16 轮）。
    final rng = math.Random(7);
    for (int i = 0; i < Quality.current.rainDrops; i++) {
      drops.add(
        _RainStreak(
          x: rng.nextDouble(),
          y0: rng.nextDouble(),
          speed: 0.35 + rng.nextDouble() * 0.3,
          length: 14 + rng.nextDouble() * 22,
          drift: 0.04 + rng.nextDouble() * 0.05,
        ),
      );
    }
  }

  final List<_RainStreak> drops = [];

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final night = game.nightAmount;

    // 篝火：极微弱暖色偏移（几乎只是底色的"体温"）。
    final warm = game.warmthAmount * night;
    if (warm > 0.004) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = const Color(0xFF62341a).withValues(alpha: 0.055 * warm),
      );
    }

    // 夜雨：≤20 条细雨丝缓落，斜率极小，alpha 峰值仅 0.10。
    final rain = game.rainAmount * night;
    if (rain > 0.004) {
      final t = game.time;
      final paint = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (final d in drops) {
        final y = ((d.y0 + t * d.speed) % 1) * (size.y + d.length) - d.length;
        final x = ((d.x + t * d.drift * 0.3) % 1) * size.x;
        paint.color = ZenTheme.starWhite.withValues(alpha: 0.10 * rain);
        canvas.drawLine(
          Offset(x, y),
          Offset(x + d.length * 0.08, y + d.length),
          paint,
        );
      }
    }
  }
}

class _RainStreak {
  _RainStreak({
    required this.x,
    required this.y0,
    required this.speed,
    required this.length,
    required this.drift,
  });

  final double x;
  final double y0;
  final double speed;
  final double length;
  final double drift;
}

/// 星花花园（第 55 轮）——呼吸的痕迹。
///
/// 光灵平稳呼吸约 40s 注满一次"花开"，在光灵身后（延迟若干帧的旧
/// 位置）种下一朵星花：花瓣数 5~7 由确定性 seed 决定，颜色取自
/// CYBER-ZEN 冷色系（青/淡紫/月白）。定长池上限 [kFlowerPoolMax] 朵，
/// 满了最旧的花化光尘谢幕（FIFO）。
///
/// 纪律（写死，防后续轮误加）：
/// - 星花开花时**不给碎片、不给分数**——它纯粹是世界的美与回应
///   （愿景支柱 5：温柔正反馈），不是经济系统的一部分；
/// - 定长池 + 构造期预生成，每帧零分配；alpha 按 0.02 步进量化；
/// - 花随全局呼吸相位轻微张合；呼吸紊乱时所有在屏花缓慢收拢变暗
///   （花谢不是惩罚——变暗但不消失），恢复后缓慢重开；
/// - 长夜时段（nightAmount）星花自动闭合入眠：闭合不是消失。
class BreathFlowerGarden extends Component with HasGameReference<JingjingGame> {
  BreathFlowerGarden() {
    for (int i = 0; i < kFlowerPoolMax; i++) {
      _pool.add(_Flower());
    }
  }

  static const int _trailLen = 180; // 180 帧 ≈ 3s 延迟（60fps）
  static const double _dustSeconds = 1.6;
  static const int _dustSlots = 4;

  final List<_Flower> _pool = [];
  final List<Vector2> _trail = List.generate(_trailLen, (_) => Vector2.zero());
  final List<_FlowerDust> _dusts = List.generate(
    _dustSlots,
    (_) => _FlowerDust(),
  );
  int _trailHead = 0;
  bool _trailFull = false;
  int _spawnCounter = 0;
  int _dustHead = 0;

  // 花开/花谢状态（内存态，不持久化）。
  double _dwell = 0;
  double _steadySm = 0;
  double _chaos = 0;

  // 画笔预生成（零每帧分配）。
  final Paint _petalPaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _corePaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _dustPaint = Paint();

  /// 延迟若干帧的光灵旧位置（环形缓冲最旧一帧）。
  Vector2 get _delayedPos =>
      _trailFull ? _trail[_trailHead] : game.spiritPos;

  void _spawnFlower() {
    final idx = flowerPoolNextIndex(_spawnCounter);
    final f = _pool[idx];
    if (f.alive) {
      // 池满：最旧的一朵化光尘谢幕（FIFO，圆环取模天然选中它）。
      final d = _dusts[_dustHead];
      _dustHead = (_dustHead + 1) % _dustSlots;
      d
        ..active = true
        ..t = 0
        ..pos.setFrom(f.position)
        ..petalColor = f.petalColor;
    }
    final seed = _spawnCounter * 7 + 3;
    // 星花映境（第 56 轮）：花记得它出生的地方——按种花瞬间光灵
    // （延迟轨迹的旧位）所处的心境区域取一组调色/瓣形，此后花不再
    // 随光灵移动换色；同区之内再以确定性 seed 做亮度/相位微差，
    // 避免同一片心境里的花整齐划一。
    final mood = _moodForSpawn();
    final palette = flowerPaletteFor(mood);
    final (brighten, phase) = flowerKinVariance(seed);
    final petal = Color.lerp(palette.petal, palette.core, 1 - brighten)!;
    f
      ..alive = true
      ..seed = seed
      ..petals = (flowerPetalCount(seed) + palette.petalAdjust).clamp(4, 8)
      ..petalColor = petal
      ..coreColor = palette.core
      ..rotPhase = (seed % 628) / 100.0 + phase
      ..position.setFrom(_delayedPos);
    _spawnCounter++;
  }

  /// 种花瞬间光灵旧位所处的心境（先惑星近旁，再静之径，最后深度带）。
  FlowerMood _moodForSpawn() {
    final p = _delayedPos;
    for (final c in game.children) {
      if (c is PerplexPlanet &&
          (c.machine.phase == PerplexPhase.drifting ||
              c.machine.phase == PerplexPhase.dissolving)) {
        final d = regionWrapDelta(p, c.pos);
        if (d.length < 120) return FlowerMood.perplex;
      }
    }
    if (game.stillPath.distanceToPoint(p) < StillPath.onPathDistance) {
      return FlowerMood.stillPath;
    }
    return _moodOfRegion(GameRegion.regionAt(p));
  }

  static FlowerMood _moodOfRegion(GameRegion r) {
    if (identical(r, GameRegion.anxietyAbyss)) return FlowerMood.anxietyAbyss;
    if (identical(r, GameRegion.wearyHeath)) return FlowerMood.wearyHeath;
    if (identical(r, GameRegion.mistWood)) return FlowerMood.mistWood;
    return FlowerMood.insomniaSea;
  }

  @override
  void update(double dt) {
    final steady = game.breathSteady;
    final chaotic = game.breathJitterLevel >= 0.35;

    // 低通平稳度（与惑星通达同款滤波，绝不瞬跳）。
    _steadySm +=
        ((steady ? 1.0 : 0.0) - _steadySm) * math.min(1.0, dt * 0.8);

    // 花开累积：注满即种花、归零循环。
    final before = _dwell;
    _dwell = flowerBloomDwellNext(
      dwellSeconds: _dwell,
      dt: dt,
      breathSteady: steady,
    );
    if (before < kFlowerBloomSeconds && _dwell >= kFlowerBloomSeconds) {
      _spawnFlower();
      _dwell = 0; // 循环：重新累积下一次花开。
    }

    // 花谢记账：紊乱累积，平稳缓慢消退（花缓慢重开）。
    _chaos = flowerChaosNext(
      chaoticSeconds: _chaos,
      dt: dt,
      chaotic: chaotic,
      breathSteady: steady,
    );

    // 光灵位置轨迹入环（复用缓冲，零分配）。
    _trail[_trailHead].setFrom(game.spiritPos);
    _trailHead = (_trailHead + 1) % _trailLen;
    if (_trailHead == 0) _trailFull = true;

    // 谢幕光尘推进。
    for (final d in _dusts) {
      if (d.active) {
        d.t += dt;
        if (d.t >= _dustSeconds) d.active = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final intro = game.introEase;
    if (intro <= 0.01) return; // 开场世界还黑着，星花未醒。
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final wither = flowerWitherProgress(chaoticSeconds: _chaos);
    final sway = flowerBreathSway(game.breathPhase);
    final night = game.nightAmount;

    for (final f in _pool) {
      if (!f.alive) continue;
      final (open, glow) = flowerVisual(1.0, wither, night: night);
      if (open <= 0.001) continue; // 闭合入眠：不消失，只是不画。
          final alpha = _q(open * 0.55 * intro);
          if (alpha <= 0) continue;
          final color = f.petalColor;
      // 环绕绘制（世界锁定的 1.0 视差 + 3x3 镜像，同星岛约定）。
      for (int ox = -1; ox <= 1; ox++) {
        for (int oy = -1; oy <= 1; oy++) {
          final wx =
              f.position.x + ox * period.x - game.camPos.x;
          final wy =
              f.position.y + oy * period.y - game.camPos.y;
          final cx = size.x / 2 + wx;
          final cy = size.y / 2 + wy;
          if (cx < -60 || cx > size.x + 60 || cy < -60 || cy > size.y + 60) {
            continue; // 屏外剔除。
          }
          _renderFlower(canvas, cx, cy, f, open, glow, sway, alpha, color);
        }
      }
    }

    // 谢幕光尘：化开的一瞬，温柔地散去。
    for (final d in _dusts) {
      if (!d.active) continue;
      final t = (d.t / _dustSeconds).clamp(0.0, 1.0);
      final a = _q((1 - t) * 0.18 * intro);
      if (a <= 0) continue;
      final r = 6 + 26 * t;
      _dustPaint
        ..color = d.petalColor.withValues(alpha: a)
        ..blendMode = BlendMode.screen;
      for (int ox = -1; ox <= 1; ox++) {
        for (int oy = -1; oy <= 1; oy++) {
          final cx = size.x / 2 + d.pos.x + ox * period.x - game.camPos.x;
          final cy = size.y / 2 + d.pos.y + oy * period.y - game.camPos.y;
          if (cx < -60 || cx > size.x + 60 || cy < -60 || cy > size.y + 60) {
            continue;
          }
          canvas.drawCircle(Offset(cx, cy), r, _dustPaint);
        }
      }
    }
  }

  void _renderFlower(
    Canvas canvas,
    double cx,
    double cy,
    _Flower f,
    double open,
    double glow,
    double sway,
    double alpha,
    Color color,
  ) {
    final center = Offset(cx, cy);
    // 底辉：极淡的一圈，随呼吸张合微微舒缩。
    _glowPaint
      ..color = color.withValues(alpha: _q(glow * 0.10))
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, (10 + 8 * open) * sway, _glowPaint);
    // 花瓣：从花心放射的细光线，张合随花开进度与呼吸相位。
    _petalPaint
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 2.2;
    final len = (9 + 13 * open) * sway;
    for (int i = 0; i < f.petals; i++) {
      final a = f.rotPhase + (i / f.petals) * math.pi * 2;
      canvas.drawLine(
        center,
        Offset(cx + math.cos(a) * len, cy + math.sin(a) * len * 0.9),
        _petalPaint,
      );
    }
    // 花心：再暗也留一点芯光——变暗但不消失。
    _corePaint
      ..color = f.coreColor.withValues(alpha: _q(glow * 0.5))
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, 2.2, _corePaint);
  }

  static double _q(double v) => (v.clamp(0.0, 1.0) * 50).round() / 50.0;
}

/// 一朵星花（定长池成员，字段复用，零每帧分配）。
///
/// petalColor/coreColor 在种花瞬间按出生地心境一次性确定——花记得
/// 它出生的地方，之后不随光灵移动换色。
class _Flower {
  final Vector2 position = Vector2.zero();
  bool alive = false;
  int seed = 0;
  int petals = 5;
  Color petalColor = const Color(0xFF9fd8e8);
  Color coreColor = const Color(0xFFe6f5f9);
  double rotPhase = 0;
}

/// 谢幕光尘（定长槽复用）：沿用谢幕之花出生地的花瓣色。
class _FlowerDust {
  final Vector2 pos = Vector2.zero();
  bool active = false;
  double t = 0;
  Color petalColor = const Color(0xFF9fd8e8);
}
