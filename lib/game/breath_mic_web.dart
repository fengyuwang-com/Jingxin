import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'breath_mic.dart';

/// Web 实现：getUserMedia + AnalyserNode 时间域 RMS 音量包络。
///
/// 【隐私声明】只做实时音量分析，绝不录音、绝不存储、绝不传输。
/// 采样缓冲（Float32List）每帧被 getFloatTimeDomainData 直接覆盖，
/// 唯一存活的状态是一个 0..1 的包络标量。麦克风流与轨道在 [stop]
/// 时被彻底释放；开启状态不做任何持久化（每次会话重新选择）。
///
/// 信号链：MediaStream -> MediaStreamAudioSourceNode -> AnalyserNode
/// （不接 destination，避免回授啸叫）。40ms 轮询取 RMS，先去底噪、
/// 再柔和映射，最后两级低通（τ≈0.25s + τ≈0.55s，总时间常数 ≥0.5s），
/// 输出缓慢如潮汐的呼吸强度，杜绝抖动。
class BreathMicEngineImpl implements BreathMicEngine {
  web.MediaStream? _stream;
  web.AudioContext? _ctx;
  web.AnalyserNode? _analyser;
  web.MediaStreamAudioSourceNode? _source;
  Timer? _poll;

  Float32List _samples = Float32List(_fftSize);
  double _fastEnv = 0; // 第一级低通（跟随较快，仍无毛刺）。
  double _slowEnv = 0; // 第二级低通（呼吸级慢滑，最终输出）。
  double _lastTick = 0;

  bool _running = false;

  /// 采样窗：1024 点 ≈ 21ms @48kHz，覆盖多个音频周期取 RMS 足够稳。
  static const int _fftSize = 1024;

  /// 轮询间隔（秒）。
  static const double _tickSeconds = 0.04;

  /// 底噪门限：低于此 RMS 视为环境安静（呼气侧）。
  static const double _noiseFloor = 0.012;

  /// 归一化尺度：RMS 超过约 0.16（近口鼻吹气/说话音量）即满强度。
  static const double _sensitivity = 0.15;

  @override
  bool get isSupported => true;

  @override
  bool get isRunning => _running;

  @override
  double get envelope => _slowEnv;

  @override
  Future<bool> start() async {
    if (_running) return true;
    try {
      final media = web.window.navigator.mediaDevices;
      if (media == null) return false; // 浏览器不支持 getUserMedia。

      // 只在用户手势调用栈内被触发（调用方保证）。
      final stream = await media
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;

      final ctx = web.AudioContext();
      final source = ctx.createMediaStreamSource(stream);
      final analyser = ctx.createAnalyser();
      analyser.fftSize = _fftSize;
      analyser.smoothingTimeConstant = 0; // 平滑自己做，时间常数可控。
      source.connect(analyser); // 刻意不连 destination：只分析、不回放。

      _stream = stream;
      _ctx = ctx;
      _source = source;
      _analyser = analyser;
      _fastEnv = 0;
      _slowEnv = 0;
      _lastTick = DateTime.now().millisecondsSinceEpoch / 1000;
      _running = true;

      _poll?.cancel();
      _poll = Timer.periodic(
        Duration(milliseconds: (_tickSeconds * 1000).round()),
        (_) => _tick(),
      );
      return true;
    } catch (_) {
      // 权限拒绝 / 无设备 / 任何异常：彻底清理并返回 false，绝不抛出。
      await stop();
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _poll?.cancel();
    _poll = null;
    try {
      _source?.disconnect();
      _stream?.getTracks().toDart.forEach((t) => t.stop());
      await _ctx?.close().toDart;
    } catch (_) {}
    _source = null;
    _analyser = null;
    _stream = null;
    _ctx = null;
    _fastEnv = 0;
    _slowEnv = 0;
  }

  /// 一次轮询：取时间域采样 -> RMS -> 去底噪柔和映射 -> 两级低通。
  void _tick() {
    if (!_running) return;
    try {
      final analyser = _analyser;
      if (analyser == null) return;
      analyser.getFloatTimeDomainData(_samples.toJS);

      double sum = 0;
      for (int i = 0; i < _samples.length; i++) {
        final s = _samples[i];
        sum += s * s;
      }
      final rms = math.sqrt(sum / _samples.length);

      // 去底噪 + 柔和压缩映射（smoothstep 软膝，靠近满量程不生硬）。
      final above = (rms - _noiseFloor).clamp(0.0, double.infinity);
      final x = (above / _sensitivity).clamp(0.0, 1.0);
      final target = x * x * (3 - 2 * x);

      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final dt = (now - _lastTick).clamp(0.005, 0.5);
      _lastTick = now;

      // 第一级低通 τ≈0.25s：吃掉采样窗间的毛刺。
      _fastEnv += (target - _fastEnv) * (1 - math.exp(-dt / 0.25));
      // 第二级低通 τ≈0.55s：呼吸级的慢滑，总时间常数 ≥0.5s。
      _slowEnv += (_fastEnv - _slowEnv) * (1 - math.exp(-dt / 0.55));
    } catch (_) {
      // 分析失败静默：包络保持，不惊扰世界。
    }
  }
}
