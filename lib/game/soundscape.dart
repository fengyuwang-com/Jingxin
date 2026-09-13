/// 声景引擎门面：按平台条件导出实现。
///
/// Web 平台（主要目标）：`soundscape_web.dart` 用 dart:js_interop +
/// package:web 调 Web Audio API，纯程序合成三种声景（无任何音频文件）：
/// 海潮（粉红噪声 + 极慢涌落 LFO）、夜雨（雨幕底 + 稀疏雨滴瞬态 +
/// 遥远雷滚）、篝火（低频暖噪声底 + 噼啪脉冲簇 + 音量摇曳）。
/// 切换声景时交叉渐变（旧声景淡出、新声景淡入）。
///
/// 非 Web 平台：`soundscape_stub.dart` 优雅降级为静音（后续可引入
/// audioplayers + 预生成噪声 buffer 补齐原生实现）。
library;

import 'package:shared_preferences/shared_preferences.dart';

export 'soundscape_stub.dart' if (dart.library.js_interop) 'soundscape_web.dart';

/// 声景种类：海潮（默认）· 夜雨 · 篝火。
enum SoundscapeScene { sea, rain, campfire }

/// 声景的极简文字（声景切换 UI 用，克制的小字）。
extension SoundscapeSceneLabel on SoundscapeScene {
  String get label => switch (this) {
    SoundscapeScene.sea => '海潮',
    SoundscapeScene.rain => '夜雨',
    SoundscapeScene.campfire => '篝火',
  };
}

/// 声景接口：进入长夜淡入，退出长夜淡出；可在播放中交叉渐变切换。
abstract class SoundscapeEngine {
  /// 是否真的在发声（Web 合成实现为 true，静音降级为 false）。
  bool get isActive;

  /// 当前声景（未播放时也可设置，下次 start 生效）。
  SoundscapeScene get scene;

  /// 开始播放当前声景并在 [fadeIn] 秒内极缓淡入。
  /// 必须在用户手势（如点击长夜入口）的调用栈内首次调用，
  /// 以满足浏览器自动播放策略（AudioContext 在手势后创建/resume）。
  Future<void> start({double fadeIn = 4.0});

  /// 在 [fadeOut] 秒内淡出并停止。
  Future<void> stop({double fadeOut = 3.0});

  /// 切换声景：旧声景在约 [crossfade] 秒内淡出、新声景淡入（交叉渐变）。
  /// 未播放时只记录选择，不发声。
  Future<void> select(SoundscapeScene scene, {double crossfade = 2.5});
}

/// 声景选择持久化（shared_preferences，所有平台可用）。
class SoundscapePreference {
  static const String _key = 'jingxin.soundscape.v1';

  SoundscapeScene _scene = SoundscapeScene.sea;
  bool _loaded = false;

  SoundscapeScene get scene => _scene;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      for (final s in SoundscapeScene.values) {
        if (s.name == name) _scene = s;
      }
    } catch (_) {
      _scene = SoundscapeScene.sea;
    }
  }

  Future<void> save(SoundscapeScene scene) async {
    _scene = scene;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, scene.name);
    } catch (_) {}
  }
}
