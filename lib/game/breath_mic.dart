/// 麦克风呼吸输入层门面：按平台条件导出实现。
///
/// 【隐私声明】本层只做**实时音量包络分析**（AnalyserNode 时间域 RMS），
/// 绝不录音、绝不缓存音频数据、绝不向任何地方传输——采样缓冲在每帧
/// 读取后被直接覆盖，除了一个 0..1 的"呼吸强度"数字外什么都不留下。
/// getUserMedia 只在用户点击手势的调用栈内被调用，绝不自动请求。
///
/// 映射哲学（刻意不做的部分）：不做真正的"呼吸分类"，只做柔和的
/// "音量包络 = 呼吸强度"映射——对麦克风吹气/让麦克风靠近口鼻时
/// 音量升高 ≈ 吸气，安静 ≈ 呼气。包络慢平滑（时间常数 ≥0.5s），
/// 杜绝抖动，让世界跟随气息而非噪音。
///
/// Web 平台：`breath_mic_web.dart` 用 dart:js_interop + package:web
/// （与 soundscape_web 同规范）取 getUserMedia 麦克风流。
/// 非 Web 平台：`breath_mic_stub.dart` 静默不可用。
library;

export 'breath_mic_stub.dart' if (dart.library.js_interop) 'breath_mic_web.dart';

/// 麦克风呼吸输入引擎接口。
abstract class BreathMicEngine {
  /// 当前平台是否可能可用（Web 且浏览器支持 getUserMedia）。
  /// 只是"可能"——真正的可用性要等 [start] 里权限被允许才知道。
  bool get isSupported;

  /// 是否正在运行（已获得麦克风流并持续输出包络）。
  bool get isRunning;

  /// 平滑后的呼吸强度包络（0..1）。未运行时恒为 0。
  double get envelope;

  /// 请求麦克风权限并开始分析。必须在用户手势（点击）调用栈内调用。
  /// 成功返回 true；权限被拒 / 无设备 / 不支持 / 任何异常返回 false，
  /// 绝不抛出、绝不让调用方崩溃。
  Future<bool> start();

  /// 停止分析并彻底释放麦克风流与轨道。
  Future<void> stop();
}
