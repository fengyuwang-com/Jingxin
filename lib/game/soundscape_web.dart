import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'soundscape.dart';

/// Web 实现：Web Audio 程序合成"海之白噪音"。
///
/// - 粉红噪声（Paul Kellet 近似滤波法）生成 8 秒无缝循环 buffer；
/// - BiquadFilter 低通（约 480Hz）滤掉毛刺，只留柔和底噪；
/// - 0.06Hz 极慢 LFO 轻推增益，模拟海潮起伏（约 16 秒一次涌落）；
/// - 淡入/淡出用 GainNode ramp，4 秒极缓浮现、3 秒缓退；
/// - AudioContext 延迟到 [start]（用户手势内）才创建，规避自动播放限制。
class SeaSoundscapeImpl implements SeaSoundscape {
  web.AudioContext? _ctx;
  web.GainNode? _master;
  bool _playing = false;

  @override
  bool get isActive => _playing;

  @override
  Future<void> start({double fadeIn = 4.0}) async {
    if (_playing) return;
    try {
      // 自动播放策略：必须在用户手势调用栈内创建/resume。
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      final buffer = _pinkNoiseBuffer(ctx);
      final src = ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;

      final lowpass = ctx.createBiquadFilter();
      lowpass.type = 'lowpass';
      lowpass.frequency.value = 480;
      lowpass.Q.value = 0.4;

      final master = ctx.createGain();
      master.gain.value = 0;

      // 极慢 LFO：涌落起伏叠加在淡入目标音量上。
      final lfo = ctx.createOscillator();
      lfo.frequency.value = 0.06;
      final lfoGain = ctx.createGain();
      lfoGain.gain.value = _targetVolume * 0.22;
      lfo.connect(lfoGain);
      lfoGain.connect(master.gain);
      lfo.start();

      src.connect(lowpass);
      lowpass.connect(master);
      master.connect(ctx.destination);
      src.start();

      final now = ctx.currentTime;
      master.gain.setValueAtTime(0, now);
      master.gain.linearRampToValueAtTime(_targetVolume, now + fadeIn);

      _master = master;
      _playing = true;
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
      final master = _master!;
      final now = ctx.currentTime;
      master.gain.cancelScheduledValues(now);
      master.gain.setValueAtTime(master.gain.value, now);
      master.gain.linearRampToValueAtTime(0.0001, now + fadeOut);
      // 淡出完成后挂起上下文，省电且下次手势可 resume 复用。
      await Future<void>.delayed(Duration(milliseconds: (fadeOut * 1000).ceil()));
      if (!_playing) {
        await ctx.suspend().toDart;
      }
    } catch (_) {}
  }

  /// 长夜音量：极轻，只作铺垫，不喧宾夺主。
  static const double _targetVolume = 0.18;

  /// 生成 8 秒粉红噪声循环 buffer（Paul Kellet 滤波近似）。
  web.AudioBuffer _pinkNoiseBuffer(web.AudioContext ctx) {
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
    return buffer;
  }
}
