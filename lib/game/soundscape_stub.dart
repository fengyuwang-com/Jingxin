/// 静音降级实现（非 Web 平台）。
///
/// 长夜模式在本平台没有任何声音，UI 照常工作；声景选择仍可记录。
/// 后续可用 audioplayers + 程序预生成的噪声文件补齐原生声景。
library;

import 'soundscape.dart';

class SoundscapeEngineImpl implements SoundscapeEngine {
  SoundscapeScene _scene = SoundscapeScene.sea;

  @override
  SoundscapeScene get scene => _scene;

  @override
  bool get isActive => false;

  @override
  Future<void> start({double fadeIn = 4.0}) async {}

  @override
  Future<void> stop({double fadeOut = 3.0}) async {}

  @override
  Future<void> select(SoundscapeScene scene, {double crossfade = 2.5}) async {
    _scene = scene;
  }

  @override
  void duck({required bool active}) {}

  @override
  void silence({double seconds = 1.0}) {}

  @override
  void setBreathSoundEnabled(bool enabled) {}

  @override
  void updateBreathTone({
    required double phase,
    required bool inhaling,
    required bool steady,
  }) {}
}
