/// 静音降级实现（非 Web 平台）。
///
/// 长夜模式在本平台没有任何声音，UI 照常工作。
/// 后续可用 audioplayers + 程序预生成的粉红噪声文件补齐原生声景。
library;

import 'soundscape.dart';
///
/// 长夜模式在本平台没有任何声音，UI 照常工作。
/// 后续可用 audioplayers + 程序预生成的粉红噪声文件补齐原生声景。
class SeaSoundscapeImpl implements SeaSoundscape {
  @override
  bool get isActive => false;

  @override
  Future<void> start({double fadeIn = 4.0}) async {}

  @override
  Future<void> stop({double fadeOut = 3.0}) async {}
}
