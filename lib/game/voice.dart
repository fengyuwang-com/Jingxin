/// 「闻声」引导词轻声朗读引擎门面：按平台条件导出实现。
///
/// Web 平台（主要目标）：`voice_web.dart` 用 dart:js_interop +
/// package:web 调浏览器原生 SpeechSynthesis 朗读禅语与入睡引导，
/// 无任何新依赖、无任何云端服务——声音来自设备本地的语音合成。
/// 优先挑选中文（zh-CN）声音；声音列表由浏览器异步加载
/// （onvoiceschanged），加载完成前后都可通过 [VoiceEngine.available]
/// 感知；rate ≈0.85、pitch ≈0.95、volume ≈0.5，轻声、慢速。
///
/// 非 Web 平台：`voice_stub.dart` 优雅降级为完全静音
/// （isSupported=false，UI 直接隐藏开关）。
///
/// 朗读礼仪（克制是第一原则）：
/// - 新朗读前先 cancel 旧的 utterance（synth 全局只有一个队列）；
/// - 朗读分两类：禅语（koan，读完为止，不因触摸取消）与
///   入睡引导（whisper，用户任何触摸立即 cancel）；
/// - 退出静境 / 声景停止 / 切后台 → cancelAll；
/// - 朗读期间通过回调通知外部把声景 master gain duck 到 0.3
///   （1 秒过渡，读完 2 秒恢复），避免声音打架。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'voice_stub.dart' if (dart.library.js_interop) 'voice_web.dart';

/// 朗读种类：决定打断礼仪（见 library 注释）。
enum VoiceKind {
  /// 禅语：碎片偈语 / 星图回看。读完为止，不因触摸取消。
  koan,

  /// 入睡引导：长夜里极低频率的极短句。用户任何触摸立即取消。
  whisper,
}

/// 轻声朗读引擎接口。
abstract class VoiceEngine {
  /// 当前平台是否可能可用（Web 且浏览器提供 speechSynthesis）。
  bool get isSupported;

  /// 是否有可用的声音（声音列表异步加载，加载完会通知）。
  /// false 时 UI 隐藏开关、speak 静默跳过。
  ValueListenable<bool> get available;

  /// 朗读开始（外部据此把声景 duck 下去）。
  void Function(VoiceKind kind)? onSpeakingStart;

  /// 朗读结束/被取消/出错（外部据此让声景缓缓恢复）。
  void Function(VoiceKind kind)? onSpeakingEnd;

  /// 轻声读一句。内部先 cancel 旧朗读；无可用声音时静默跳过。
  void speak(String text, {required VoiceKind kind});

  /// 按礼仪规则取消：只取消 whisper；若正在读禅语则不动它。
  void cancelWhisper();

  /// 取消一切朗读（退出静境/切后台/声景停止时）。
  void cancelAll();
}

/// 「闻声」开关持久化（shared_preferences，key jingxin.voice.v1）。
/// 默认关闭——朗读永远是被邀请进来的，不是自己闯进来的。
class VoicePreference {
  static const String _key = 'jingxin.voice.v1';

  bool enabled = false;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_key) ?? false;
    } catch (_) {
      enabled = false;
    }
  }

  Future<void> save(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}
