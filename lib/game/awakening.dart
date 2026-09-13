import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 世界苏醒度（0..1）：唯一进度。
///
/// 持续平稳的完整呼吸循环缓慢提升；停止交互后缓慢回落，但不会归零，
/// 也没有任何负反馈提示——世界只是安静下来。
class AwakeningState {
  AwakeningState();

  static const String _prefKey = 'jingxin.awakening.v1';

  /// 回落底线：世界永远不会完全沉睡归零。
  static const double floor = 0.02;

  /// 完成一个平稳呼吸循环的提升量（约 8s 一循环，满值约需 13 分钟静呼吸）。
  ///
  /// 配平注（第 22 轮巡检）：0→1 全程无卡死点——自动呼吸引导本身
  /// 即可产生平稳循环；回落速率 0.002/s 远低于静呼吸的 0.075/min
  /// 增速，不会出现"边呼吸边倒退"。整体 10~20 分钟可达世界苏醒，
  /// 与星兽近旁累计（约 11min）、惘的显形（约 1min/次）时间尺度错落。
  static const double cycleGain = 0.01;

  /// 无交互多久后开始缓慢回落。
  static const double decayDelay = 10.0;

  /// 回落速率（每秒），极缓、无感。
  static const double decayRate = 0.002;

  double _value = floor;
  double _sinceCycle = 0;
  double _sinceSave = 0;
  bool _loaded = false;
  bool _dirty = false;

  double get value => _value;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _value = (prefs.getDouble(_prefKey) ?? floor).clamp(0.0, 1.0);
    } catch (_) {
      _value = floor;
    }
  }

  /// 每帧推进。[completedCycle] 为真表示刚完成一次平稳的完整呼吸循环。
  void update(double dt, {required bool completedCycle}) {
    if (completedCycle) {
      _value = (_value + cycleGain).clamp(0.0, 1.0);
      _sinceCycle = 0;
      _dirty = true;
    } else {
      _sinceCycle += dt;
      if (_sinceCycle > decayDelay && _value > floor) {
        _value = (_value - decayRate * dt).clamp(floor, 1.0);
        _dirty = true;
      }
    }
    _sinceSave += dt;
    if (_sinceSave > 5 && _dirty) {
      _dirty = false;
      _sinceSave = 0;
      save();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, _value);
    } catch (_) {
      // 持久化失败静默忽略，游戏体验不受影响。
    }
  }

  @visibleForTesting
  void debugSetValue(double v) => _value = v.clamp(0.0, 1.0);
}
