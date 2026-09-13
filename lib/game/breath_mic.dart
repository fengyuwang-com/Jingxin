/// 麦克风呼吸输入层门面：按平台条件导出实现。
///
/// 【隐私声明】本层只做**实时音量包络分析**（AnalyserNode 时间域 RMS），
/// 绝不录音、绝不缓存音频数据、绝不向任何地方传输——采样缓冲在每帧
/// 读取后被直接覆盖，除了一个 0..1 的"呼吸强度"数字外什么都不留下。
/// getUserMedia 只在用户点击手势的调用栈内被调用，绝不自动请求。
///
/// 映射哲学（刻意不做的部分）：不做真正的"呼吸分类"，只做柔和的
/// "音量包络 = 呼吸强度"映射——对麦克风吹气（吹气是呼）时音量升高
/// = 呼气段，回落安静 = 吸气段。包络慢平滑（时间常数 ≥0.5s），
/// 杜绝抖动，让世界跟随气息而非噪音。基线由慢速自动增益跟踪
/// （数十秒尺度跟随环境底噪），灵敏度 3 档可调（见 [MicSensitivity]）。
///
/// Web 平台：`breath_mic_web.dart` 用 dart:js_interop + package:web
/// （与 soundscape_web 同规范）取 getUserMedia 麦克风流。
/// 非 Web 平台：`breath_mic_stub.dart` 静默不可用。
library;

export 'breath_mic_stub.dart' if (dart.library.js_interop) 'breath_mic_web.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// 随息灵敏度（3 档）：只改"多小的声音算一次呼吸"的尺度，
/// 不改变映射的柔和程度——低档更适合嘈杂环境，高档适合安静深夜。
enum MicSensitivity {
  low,
  medium,
  high;

  /// 包络满量程所需 RMS 的缩放系数（>1 更迟钝，<1 更灵敏）。
  double get scale => switch (this) {
    MicSensitivity.low => 1.7,
    MicSensitivity.medium => 1.0,
    MicSensitivity.high => 0.55,
  };

  String get label => switch (this) {
    MicSensitivity.low => '低',
    MicSensitivity.medium => '中',
    MicSensitivity.high => '高',
  };
}

/// 灵敏度选择持久化（key jingxin.mic.sens.v1）。
/// 只存一档偏好，绝不存任何音频相关数据。
class MicSensitivityPreference {
  static const _key = 'jingxin.mic.sens.v1';

  MicSensitivity value = MicSensitivity.medium;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      for (final s in MicSensitivity.values) {
        if (s.name == name) value = s;
      }
    } catch (_) {}
  }

  Future<void> save(MicSensitivity s) async {
    value = s;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, s.name);
    } catch (_) {}
  }
}

/// 麦克风呼吸输入引擎接口。
abstract class BreathMicEngine {
  /// 设置随息灵敏度（可随时切换，立即生效）。
  void setSensitivity(MicSensitivity sensitivity);

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
