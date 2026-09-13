import 'breath_mic.dart';

/// 非 Web 平台 stub：麦克风呼吸静默不可用。
///
/// 原生平台后续可引入 record/permission_handler 等补齐真实实现；
/// 目前 [isSupported] 恒为 false，UI 层据此直接隐藏入口图标，
/// 用户永远不会遇到弹窗或报错。
class BreathMicEngineImpl implements BreathMicEngine {
  @override
  bool get isSupported => false;

  @override
  bool get isRunning => false;

  @override
  double get envelope => 0;

  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}
}
