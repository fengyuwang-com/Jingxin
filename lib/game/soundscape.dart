/// 声景引擎门面：按平台条件导出实现。
///
/// Web 平台（主要目标）：`soundscape_web.dart` 用 dart:js_interop +
/// package:web 调 Web Audio API，程序合成粉红噪声（Paul Kellet 滤波法，
/// 比白噪更柔），经低通滤波 + 极慢音量起伏（海潮呼吸感）输出"海之白噪音"。
///
/// 非 Web 平台：`soundscape_stub.dart` 优雅降级为静音（后续可引入
/// audioplayers + 预生成粉红噪声 buffer 补齐原生实现）。
library;

export 'soundscape_stub.dart' if (dart.library.js_interop) 'soundscape_web.dart';

/// 声景接口：进入长夜淡入，退出长夜淡出。
abstract class SeaSoundscape {
  /// 是否真的在发声（Web 合成实现为 true，静音降级为 false）。
  bool get isActive;

  /// 开始播放并在 [fadeIn] 秒内极缓淡入。
  /// 必须在用户手势（如点击长夜入口）的调用栈内首次调用，
  /// 以满足浏览器自动播放策略（AudioContext 在手势后创建/resume）。
  Future<void> start({double fadeIn = 4.0});

  /// 在 [fadeOut] 秒内淡出并停止。
  Future<void> stop({double fadeOut = 3.0});
}
