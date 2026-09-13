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
/// 唯一存活的状态是两个 0..1 的包络标量和一个基线标量。麦克风流与
/// 轨道在 [stop] 时被彻底释放；开启状态与灵敏度不做音频持久化。
///
/// 信号链：MediaStream -> MediaStreamAudioSourceNode -> AnalyserNode
/// （不接 destination，避免回授啸叫）。40ms 轮询取 RMS，先减去
/// 慢速自动增益跟踪出的"环境底噪基线"（非对称低通：向上涨极慢、
/// 数十秒尺度跟随环境，向下跌快——房间安静下来立刻归位），
/// 再按灵敏度柔和映射，最后两级低通（τ≈0.25s + τ≈0.55s，
/// 总时间常数 ≥0.5s），输出缓慢如潮汐的呼吸强度，杜绝抖动。
class BreathMicEngineImpl implements BreathMicEngine {
  web.MediaStream? _stream;
  web.AudioContext? _ctx;
  web.AnalyserNode? _analyser;
  web.MediaStreamAudioSourceNode? _source;
  Timer? _poll;

  final Float32List _samples = Float32List(_fftSize);
  double _fastEnv = 0; // 第一级低通（跟随较快，仍无毛刺）。
  double _slowEnv = 0; // 第二级低通（呼吸级慢滑，最终输出）。
  double _baseline = 0; // 慢速自动增益的环境底噪基线（RMS 尺度）。
  double _lastTick = 0;

  MicSensitivity _sensitivity = MicSensitivity.medium;

  bool _running = false;

  /// 采样窗：1024 点 ≈ 21ms @48kHz，覆盖多个音频周期取 RMS 足够稳。
  static const int _fftSize = 1024;

  /// 轮询间隔（秒）。
  static const double _tickSeconds = 0.04;

  /// 底噪安全余量（RMS）：略高于基线才算"有气息"，杜绝贴地抖动。
  static const double _margin = 0.006;

  /// 归一化尺度基准：RMS 超出基线约 0.15（近口鼻吹气/说话音量）即满强度，
  /// 再按灵敏度档位缩放。
  static const double _span = 0.15;

  /// 基线跟踪时间常数（秒）：向上涨极慢（跟随环境底噪，几十秒尺度），
  /// 向下跌较快（环境安静下来立刻归位，呼气段不被误吸进基线）。
  static const double _baselineRiseTau = 30;
  static const double _baselineFallTau = 1.5;

  @override
  void setSensitivity(MicSensitivity sensitivity) {
    _sensitivity = sensitivity;
  }

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
      // 只在用户手势调用栈内被触发（调用方保证）。
      // 浏览器不支持时 mediaDevices 为 undefined，此处抛出会被下方
      // catch 捕获并静默降级为 false，绝不惊扰玩家。
      final stream = await web.window.navigator.mediaDevices
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
      _baseline = 0;
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
    _baseline = 0;
  }

  /// 一次轮询：取时间域采样 -> RMS -> 慢速自动增益去底噪 -> 柔和映射
  /// （含灵敏度档位）-> 两级低通。
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

      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final dt = (now - _lastTick).clamp(0.005, 0.5);
      _lastTick = now;

      // 慢速自动增益：基线非对称低通跟踪环境底噪。
      // 高于基线（吹气/气息）→ 基线以数十秒尺度极缓上爬（短暂呼气
      // 拉不动它）；低于基线（安静）→ 基线较快落回，房间转静立即归位。
      final tau = rms > _baseline ? _baselineRiseTau : _baselineFallTau;
      _baseline += (rms - _baseline) * (1 - math.exp(-dt / tau));

      // 去底噪 + 灵敏度缩放 + 柔和压缩映射（smoothstep 软膝）。
      final above = (rms - _baseline - _margin).clamp(0.0, double.infinity);
      final span = _span * _sensitivity.scale;
      final x = (above / span).clamp(0.0, 1.0);
      final target = x * x * (3 - 2 * x);

      // 第一级低通 τ≈0.25s：吃掉采样窗间的毛刺。
      _fastEnv += (target - _fastEnv) * (1 - math.exp(-dt / 0.25));
      // 第二级低通 τ≈0.55s：呼吸级的慢滑，总时间常数 ≥0.5s。
      _slowEnv += (_fastEnv - _slowEnv) * (1 - math.exp(-dt / 0.55));
    } catch (_) {
      // 分析失败静默：包络保持，不惊扰世界。
    }
  }
}
