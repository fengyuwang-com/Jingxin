/// 「闻声」静音降级实现（非 Web 平台）。
///
/// 朗读在本平台完全静音：isSupported=false → UI 直接隐藏开关，
/// speak 为空操作。后续可引入 flutter_tts 补齐原生语音合成。
library;

import 'package:flutter/foundation.dart';

import 'voice.dart';

class VoiceEngineImpl implements VoiceEngine {
  @override
  bool get isSupported => false;

  @override
  ValueListenable<bool> get available => ValueNotifier<bool>(false);

  @override
  void Function(VoiceKind kind)? onSpeakingStart;

  @override
  void Function(VoiceKind kind)? onSpeakingEnd;

  @override
  void speak(
    String text, {
    required VoiceKind kind,
    double rate = 0.85,
    double volume = 0.5,
  }) {}

  @override
  void cancelWhisper() {}

  @override
  void cancelAll() {}
}
