/// 「闻声」Web 实现：浏览器原生 SpeechSynthesis 轻声朗读。
///
/// - 声音来自设备本地语音合成，无网络请求、无新依赖；
/// - 优先挑选中文声音（lang 以 zh 开头，首选 zh-CN），
///   声音列表异步加载（onvoiceschanged）并同步到 [available]；
/// - utterance.lang 恒为 'zh-CN'（即便没有专门中文声音也设置，
///   让引擎按语言就近选择）；
/// - 语速 0.85、音高 0.95、音量 0.5——轻声、慢、低；
/// - 新朗读前 cancel 旧 utterance；cancelWhisper 只在当前读的是
///   入睡引导时才取消（禅语让它读完）。
library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'voice.dart';

class VoiceEngineImpl implements VoiceEngine {
  web.SpeechSynthesis? get _synth {
    try {
      return web.window.speechSynthesis;
    } catch (_) {
      return null;
    }
  }

  final ValueNotifier<bool> _available = ValueNotifier<bool>(false);
  bool _voicesHooked = false;

  /// 当前正在朗读的种类（null = 没在读）。
  VoiceKind? _currentKind;

  /// 抑制已取消 utterance 的 end 回调向外传播（退避场景自己恢复）。
  bool _cancelledInternally = false;

  @override
  bool get isSupported => _synth != null;

  @override
  ValueListenable<bool> get available => _available;

  @override
  void Function(VoiceKind kind)? onSpeakingStart;

  @override
  void Function(VoiceKind kind)? onSpeakingEnd;

  VoiceEngineImpl() {
    if (_synth == null) return;
    _refreshVoices();
    // 声音列表是异步加载的：监听 onvoiceschanged，并在近处再探测几次。
    _hookVoicesChanged();
  }

  void _hookVoicesChanged() {
    if (_voicesHooked) return;
    _voicesHooked = true;
    _synth?.onvoiceschanged = ((web.Event _) => _refreshVoices()).toJS;
    // 某些浏览器不触发 onvoiceschanged：温和地再探测几次。
    Future<void> probe(int n) async {
      if (n <= 0 || _available.value) return;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!isSupported) return;
      _refreshVoices();
      probe(n - 1);
    }

    probe(6);
  }

  void _refreshVoices() {
    try {
      final voices = _synth?.getVoices();
      _available.value = voices != null && voices.length > 0;
    } catch (_) {
      _available.value = false;
    }
  }

  /// 挑一个最适合的声音：优先 zh-CN，其次任何 zh，再次默认（null）。
  web.SpeechSynthesisVoice? _pickVoice() {
    try {
      final voices = _synth?.getVoices();
      if (voices == null) return null;
      web.SpeechSynthesisVoice? anyZh;
      for (int i = 0; i < voices.length; i++) {
        final v = voices.toDart[i];
        final lang = v.lang.toLowerCase();
        if (lang.startsWith('zh-cn')) return v;
        if (lang.startsWith('zh') && anyZh == null) anyZh = v;
      }
      return anyZh;
    } catch (_) {
      return null;
    }
  }

  @override
  void speak(
    String text, {
    required VoiceKind kind,
    double rate = 0.85,
    double volume = 0.5,
  }) {
    final synth = _synth;
    if (synth == null || text.isEmpty) return;
    try {
      // 礼仪：新朗读前先取消旧的（synth 全局只有一个队列）。
      _cancelledInternally = true;
      synth.cancel();

      final u = web.SpeechSynthesisUtterance(text);
      u.lang = 'zh-CN'; // 即便没有专门中文声音也设置，让引擎就近选择。
      final voice = _pickVoice();
      if (voice != null) u.voice = voice;
      u.rate = rate.clamp(0.1, 1.0);
      u.pitch = 0.95;
      u.volume = volume.clamp(0.0, 1.0);

      _currentKind = kind;
      _cancelledInternally = false;
      u.onend = ((web.Event _) => _onDone()).toJS;
      u.onerror = ((web.Event _) => _onDone()).toJS;
      onSpeakingStart?.call(kind);
      synth.speak(u);
    } catch (_) {
      _currentKind = null;
      _cancelledInternally = false;
    }
  }

  void _onDone() {
    if (_cancelledInternally) return;
    final kind = _currentKind;
    _currentKind = null;
    if (kind != null) onSpeakingEnd?.call(kind);
  }

  @override
  void cancelWhisper() {
    // 礼仪：只有当前读的是入睡引导时，触摸才取消；禅语让它读完。
    if (_currentKind != VoiceKind.whisper) return;
    try {
      _cancelledInternally = true;
      _synth?.cancel();
    } catch (_) {}
    _currentKind = null;
    _cancelledInternally = false;
    onSpeakingEnd?.call(VoiceKind.whisper);
  }

  @override
  void cancelAll() {
    try {
      _cancelledInternally = true;
      _synth?.cancel();
    } catch (_) {}
    final kind = _currentKind;
    _currentKind = null;
    _cancelledInternally = false;
    if (kind != null) onSpeakingEnd?.call(kind);
  }
}
