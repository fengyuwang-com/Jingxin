import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'soundscape.dart';

/// Web 实现：Web Audio 程序合成三种声景（无音频文件）。
///
/// - 海潮：粉红噪声（Paul Kellet 滤波法，8 秒无缝循环）经低通滤出柔和
///   底噪，0.06Hz 极慢 LFO 模拟涌落（约 16 秒一次）；
/// - 夜雨：粉红噪声雨幕底（带通收窄更柔）+ 稀疏"雨滴"瞬态（短促带通
///   脉冲，随机间隔与音高，密度低而柔）+ 极低频遥远雷滚（约每 25~60 秒）；
/// - 篝火：低频暖噪声底 + 稀疏"噼啪"脉冲簇，整体音量随极慢 LFO 微微摇曳；
/// - 所有声景汇入同一个 master gain（0.5）再输出，防爆音；
/// - 切换声景交叉渐变：旧声景淡出、新声景淡入（各约 2.5 秒）；
/// - 淡入/淡出全部走各层的 GainNode ramp；
/// - AudioContext 延迟到 [start]（用户手势内）才创建，规避自动播放限制。
class SoundscapeEngineImpl implements SoundscapeEngine {
  web.AudioContext? _ctx;
  web.GainNode? _master;

  /// 各声景层（懒构建，构建后保留以便交叉渐变复用）。
  final Map<SoundscapeScene, _Layer> _layers = {};

  SoundscapeScene _scene = SoundscapeScene.sea;
  bool _playing = false;

  /// 是否处于朗读 duck 状态（start 时也尊重该状态）。
  bool _ducked = false;

  @override
  SoundscapeScene get scene => _scene;

  @override
  bool get isActive => _playing;

  // ---- 生命周期 ----

  @override
  Future<void> start({double fadeIn = 4.0}) async {
    if (_playing) return;
    try {
      // 自动播放策略：必须在用户手势调用栈内创建/resume。
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      final master = _master ??= _createMaster(ctx);
      final layer = _layers.putIfAbsent(_scene, () => _createLayer(_scene));
      if (!layer.built) layer.build();
      layer.setAudible(true);
      layer.fadeTo(layer.targetVolume, fadeIn);

      _playing = true;
      // master 保持常开（0.5，朗读 duck 时 0.3），淡入淡出全部由各层 bus 负责。
      master.gain.value = _ducked ? 0.3 : 0.5;
    } catch (_) {
      // 浏览器不支持/被策略拦截：静默降级，不打扰长夜。
      _playing = false;
    }
  }

  @override
  Future<void> stop({double fadeOut = 3.0}) async {
    if (!_playing) return;
    _playing = false;
    try {
      final ctx = _ctx!;
      for (final layer in _layers.values) {
        if (!layer.audible) continue;
        layer.setAudible(false);
        layer.fadeTo(0.0001, fadeOut);
      }
      // 淡出完成后挂起上下文，省电且下次手势可 resume 复用。
      await Future<void>.delayed(
        Duration(milliseconds: (fadeOut * 1000).ceil()),
      );
      if (!_playing) {
        await ctx.suspend().toDart;
      }
    } catch (_) {}
  }

  @override
  Future<void> select(SoundscapeScene scene, {double crossfade = 2.5}) async {
    if (scene == _scene) return;
    _scene = scene;
    if (!_playing) return; // 未播放：只记录选择，start 时生效。
    try {
      final ctx = _ctx!;
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }
      final oldLayers = _layers.values.where((l) => l.audible).toList();
      for (final old in oldLayers) {
        old.setAudible(false);
        old.fadeTo(0.0001, crossfade);
      }
      final layer = _layers.putIfAbsent(scene, () => _createLayer(scene));
      if (!layer.built) layer.build();
      layer.setAudible(true);
      layer.fadeTo(layer.targetVolume, crossfade);
    } catch (_) {
      // 切换失败静默降级。
    }
  }

  @override
  void duck({required bool active}) {
    _ducked = active;
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null || !_playing) return;
    try {
      final now = ctx.currentTime;
      // duck 约 1 秒压下去，恢复约 2 秒缓缓浮回来——比朗读本身更柔。
      final seconds = active ? 1.0 : 2.0;
      master.gain.cancelScheduledValues(now);
      master.gain.setValueAtTime(master.gain.value, now);
      master.gain.linearRampToValueAtTime(active ? 0.3 : 0.5, now + seconds);
    } catch (_) {
      // duck 失败无伤大雅：朗读照常进行。
    }
  }

  web.GainNode _createMaster(web.AudioContext ctx) {
    final master = ctx.createGain();
    master.gain.value = 0.5;
    master.connect(ctx.destination);
    return master;
  }

  _Layer _createLayer(SoundscapeScene scene) {
    final ctx = _ctx!;
    final master = _master!;
    final layer = switch (scene) {
      SoundscapeScene.sea => _SeaLayer(ctx, master),
      SoundscapeScene.rain => _RainLayer(ctx, master),
      SoundscapeScene.campfire => _CampfireLayer(ctx, master),
    };
    layer.host = this;
    return layer;
  }

  // ---- 共用噪声素材（懒生成、跨层复用）----

  web.AudioBuffer? _pinkBuffer;
  web.AudioBuffer? _brownBuffer;
  web.AudioBuffer? _shortBurstBuffer;

  /// 8 秒粉红噪声循环 buffer（Paul Kellet 滤波近似）。
  web.AudioBuffer pinkBuffer(web.AudioContext ctx) {
    final cached = _pinkBuffer;
    if (cached != null) return cached;
    const seconds = 8;
    final rate = ctx.sampleRate;
    final length = (rate * seconds).toInt();
    final data = Float32List(length);

    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    final rng = math.Random();
    for (int i = 0; i < length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      data[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      b6 = white * 0.115926;
    }

    final buffer = ctx.createBuffer(1, length, rate);
    // JSFloat32Array.toDart 与底层内存共享，直接整段写入。
    buffer.getChannelData(0).toDart.setAll(0, data);
    _pinkBuffer = buffer;
    return buffer;
  }

  /// 4 秒棕色噪声循环 buffer（随机游走），用于雷滚与篝火暖底。
  web.AudioBuffer brownBuffer(web.AudioContext ctx) {
    final cached = _brownBuffer;
    if (cached != null) return cached;
    const seconds = 4;
    final rate = ctx.sampleRate;
    final length = (rate * seconds).toInt();
    final data = Float32List(length);
    double last = 0;
    final rng = math.Random();
    for (int i = 0; i < length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      last = (last + 0.02 * white) / 1.02;
      data[i] = last * 3.2;
    }
    final buffer = ctx.createBuffer(1, length, rate);
    buffer.getChannelData(0).toDart.setAll(0, data);
    _brownBuffer = buffer;
    return buffer;
  }

  /// 短白噪声脉冲 buffer（雨滴/噼啪的瞬态素材）。
  web.AudioBuffer shortBurstBuffer(web.AudioContext ctx) {
    final cached = _shortBurstBuffer;
    if (cached != null) return cached;
    const seconds = 0.06;
    final rate = ctx.sampleRate;
    final length = (rate * seconds).toInt();
    final data = Float32List(length);
    final rng = math.Random();
    for (int i = 0; i < length; i++) {
      // 极短指数衰减的脉冲，避免"咔"的硬边。
      data[i] = (rng.nextDouble() * 2 - 1) * (1 - i / length);
    }
    final buffer = ctx.createBuffer(1, length, rate);
    buffer.getChannelData(0).toDart.setAll(0, data);
    _shortBurstBuffer = buffer;
    return buffer;
  }
}

/// 声景层基类：bus gain 专职交叉渐变淡入淡出，层内结构自管。
abstract class _Layer {
  _Layer(this.ctx, this.master) : rng = math.Random();

  final web.AudioContext ctx;
  final web.GainNode master;
  final math.Random rng;

  late final web.GainNode bus;
  bool built = false;

  /// 是否正在发声（决定瞬态调度计时器是否工作）。
  bool audible = false;

  /// 该层淡入完成后的目标音量（bus 上的稳态值）。
  double get targetVolume;

  late SoundscapeEngineImpl host;

  /// 懒构建层内节点。bus 只建一次。
  void build() {
    bus = ctx.createGain();
    bus.gain.value = 0;
    bus.connect(master);
    built = true;
    buildNodes();
  }

  /// 构建层内常驻节点（噪声底、LFO 等）。
  void buildNodes();

  /// 瞬态（雨滴/噼啪/雷）调度开关。
  void setAudible(bool v) {
    audible = v;
    onAudibleChanged();
  }

  void onAudibleChanged() {}

  void fadeTo(double target, double seconds) {
    final now = ctx.currentTime;
    bus.gain.cancelScheduledValues(now);
    bus.gain.setValueAtTime(bus.gain.value, now);
    bus.gain.linearRampToValueAtTime(target, now + seconds);
  }

  /// 循环噪声底：buffer source -> filters -> gain，返回末端 gain。
  web.GainNode addNoiseBed(
    web.AudioBuffer buffer, {
    required List<web.BiquadFilterNode> filters,
    required double gain,
    double playbackRate = 1,
  }) {
    final src = ctx.createBufferSource();
    src.buffer = buffer;
    src.loop = true;
    src.playbackRate.value = playbackRate;
    web.AudioNode node = src;
    for (final f in filters) {
      node.connect(f);
      node = f;
    }
    final g = ctx.createGain();
    g.gain.value = gain;
    node.connect(g);
    g.connect(bus);
    src.start();
    return g;
  }

  web.BiquadFilterNode filter(String type, double frequency, double q) {
    final f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.value = frequency;
    f.Q.value = q;
    return f;
  }

  /// 极慢 LFO 轻推某个 gain 参数（涌落/摇曳）。
  void addLfo(web.AudioParam target, double rateHz, double depth) {
    final osc = ctx.createOscillator();
    osc.frequency.value = rateHz;
    final g = ctx.createGain();
    g.gain.value = depth;
    osc.connect(g);
    g.connect(target);
    osc.start();
  }

  /// 播放一次瞬态脉冲（雨滴/噼啪）：短噪声 -> 滤波 -> 快速包络。
  void playBurst({
    required web.AudioBuffer buffer,
    required String filterType,
    required double frequency,
    required double q,
    required double peak,
    required double attack,
    required double decay,
    double playbackRate = 1,
  }) {
    final now = ctx.currentTime;
    final src = ctx.createBufferSource();
    src.buffer = buffer;
    src.playbackRate.value = playbackRate;
    final f = filter(filterType, frequency, q);
    final g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.linearRampToValueAtTime(peak, now + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, now + attack + decay);
    src.connect(f);
    f.connect(g);
    g.connect(bus);
    src.start(now);
    src.stop(now + attack + decay + 0.05);
  }
}

/// 海潮层（第 6 轮原版：粉红噪声 + 低通 + 0.06Hz 涌落）。
class _SeaLayer extends _Layer {
  _SeaLayer(super.ctx, super.master);

  @override
  double get targetVolume => 0.18;

  @override
  void buildNodes() {
    final engine = host;
    addNoiseBed(
      engine.pinkBuffer(ctx),
      filters: [filter('lowpass', 480, 0.4)],
      gain: 1,
    );
    addLfo(bus.gain, 0.06, targetVolume * 0.22);
  }
}

/// 夜雨层：雨幕底 + 稀疏雨滴瞬态 + 遥远雷滚。
class _RainLayer extends _Layer {
  _RainLayer(super.ctx, super.master);

  Timer? _dropTimer;
  Timer? _thunderTimer;

  @override
  double get targetVolume => 0.11;

  @override
  void buildNodes() {
    final engine = host;
    // 雨幕底：粉红噪声经带通收窄（低而柔，绝不刺耳）。
    addNoiseBed(
      engine.pinkBuffer(ctx),
      filters: [filter('lowpass', 1400, 0.5), filter('highpass', 320, 0.5)],
      gain: 1,
    );
  }

  @override
  void onAudibleChanged() {
    if (audible) {
      _scheduleNextDrop();
      _scheduleNextThunder();
    } else {
      _dropTimer?.cancel();
      _thunderTimer?.cancel();
    }
  }

  /// 雨滴：随机间隔 90~410ms 一滴（密度低而柔），随机音高与亮度。
  void _scheduleNextDrop() {
    _dropTimer?.cancel();
    _dropTimer = Timer(Duration(milliseconds: 90 + rng.nextInt(320)), () {
      if (!audible) return;
      playBurst(
        buffer: host.shortBurstBuffer(ctx),
        filterType: 'bandpass',
        frequency: 700 + rng.nextDouble() * 2600,
        q: 5 + rng.nextDouble() * 8,
        peak: 0.05 + rng.nextDouble() * 0.10,
        attack: 0.004,
        decay: 0.05 + rng.nextDouble() * 0.08,
        playbackRate: 0.6 + rng.nextDouble() * 1.2,
      );
      _scheduleNextDrop();
    });
  }

  /// 遥远雷滚：约 25~60 秒一次，极低频缓慢涨落，只可感知、从不惊扰。
  void _scheduleNextThunder() {
    _thunderTimer?.cancel();
    _thunderTimer = Timer(Duration(milliseconds: 25000 + rng.nextInt(35000)), () {
      if (!audible) return;
      final now = ctx.currentTime;
      final src = ctx.createBufferSource();
      src.buffer = host.brownBuffer(ctx);
      src.loop = true;
      src.playbackRate.value = 0.4;
      final lowpass = filter('lowpass', 90 + rng.nextDouble() * 30, 0.6);
      final g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, now);
      g.gain.linearRampToValueAtTime(0.10 + rng.nextDouble() * 0.05, now + 2.2);
      g.gain.linearRampToValueAtTime(0.0001, now + 7.5);
      src.connect(lowpass);
      lowpass.connect(g);
      g.connect(bus);
      src.start(now);
      src.stop(now + 8);
      _scheduleNextThunder();
    });
  }
}

/// 篝火层：低频暖噪声底 + 稀疏噼啪脉冲簇 + 极慢音量摇曳。
class _CampfireLayer extends _Layer {
  _CampfireLayer(super.ctx, super.master);

  Timer? _crackleTimer;

  @override
  double get targetVolume => 0.13;

  @override
  void buildNodes() {
    // 暖底：棕色噪声低通，只剩低频的"暖"。
    addNoiseBed(
      host.brownBuffer(ctx),
      filters: [filter('lowpass', 220, 0.5)],
      gain: 1,
    );
    // 整体音量随极慢 LFO（约 20 秒一次）微微摇曳。
    addLfo(bus.gain, 0.05, targetVolume * 0.18);
  }

  @override
  void onAudibleChanged() {
    if (audible) {
      _scheduleNextCluster();
    } else {
      _crackleTimer?.cancel();
    }
  }

  /// 噼啪簇：每 0.25~1.4 秒一簇，每簇 1~3 声极短宽带脉冲。
  void _scheduleNextCluster() {
    _crackleTimer?.cancel();
    _crackleTimer = Timer(Duration(milliseconds: 250 + rng.nextInt(1150)), () {
      if (!audible) return;
      final count = 1 + rng.nextInt(3);
      for (int i = 0; i < count; i++) {
        playBurst(
          buffer: host.shortBurstBuffer(ctx),
          filterType: 'highpass',
          frequency: 1000 + rng.nextDouble() * 2500,
          q: 0.7,
          peak: 0.04 + rng.nextDouble() * 0.16,
          attack: 0.002,
          decay: 0.008 + rng.nextDouble() * 0.022,
          playbackRate: 0.7 + rng.nextDouble() * 1.1,
        );
      }
      _scheduleNextCluster();
    });
  }
}
