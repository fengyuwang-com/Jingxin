/// 呼吸之音（第 44 轮）：把呼吸相位映射成一把极轻的琴。
///
/// 理念：呼吸本身可以成为音乐，但永远默认安静——开关默认关，
/// 开启后吸气随进度沿五声音阶（宫商角徵羽，C-D-E-G-A）极轻上行，
/// 呼气对称下行回落；呼吸紊乱时用"更少的音"回应（跟随既有
/// 「乱了世界变暗」的语义，音量衰减而不是消失）。
///
/// 本文件只有纯函数与纯持久化：相位→音高/增益的映射可在任何平台
/// 单测；Web 端发声由 soundscape_web.dart 调 Web Audio 完成。
library;

import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// 五声音阶（宫商角徵羽）上行两段的频率表：C4 起，C-D-E-G-A 循环。
/// 呼吸音只在这张表上取音，绝不出现半音——五声天然无尖角。
const List<double> kBreathPentatonic = <double>[
  261.63, // 宫 C4
  293.66, // 商 D4
  329.63, // 角 E4
  392.00, // 徵 G4
  440.00, // 羽 A4
  523.25, // 宫 C5
  587.33, // 商 D5
  659.26, // 角 E5
  783.99, // 徵 G5
  880.00, // 羽 A5
];

/// 呼吸之音的峰值增益上限（极轻，位于声景层之下仍清晰可闻）。
const double kBreathToneMaxGain = 0.06;

/// 呼吸紊乱（不平稳）时的增益衰减系数：用更少的音回应，不是静默。
const double kBreathUnsteadyGainFactor = 0.35;

/// 一次呼吸取音的结果：正弦振荡器此刻应走向的频率与增益。
class BreathTone {
  const BreathTone({required this.frequency, required this.gain});

  /// 目标频率（Hz）。
  final double frequency;

  /// 目标增益（0..kBreathToneMaxGain，端点处为 0——无咔哒声的根）。
  final double gain;

  @override
  bool operator ==(Object other) =>
      other is BreathTone &&
      other.frequency == frequency &&
      other.gain == gain;

  @override
  int get hashCode => Object.hash(frequency, gain);
}

/// 相位→音高/增益的纯映射（Web 端每帧调用，测试逐点校验）。
///
/// - [phase]：呼吸进度 0..1（0=呼尽，1=吸满）。
/// - [inhaling]：true=吸气段（沿音阶上行），false=呼气段（对称下行）。
/// - [steady]：呼吸是否平稳（跟随既有 breathSteady 判定）。
///
/// 连续性设计：增益用钟形包络，相位两端严格为 0——无论换向还是
/// 换气都不会有突跳；吸气终点与呼气起点取同一枚最高音，来回是一
/// 条不断开的线。
BreathTone breathToneFor({
  required double phase,
  required bool inhaling,
  required bool steady,
}) {
  final p = phase.clamp(0.0, 1.0).toDouble();
  final table = kBreathPentatonic;
  // 走过的音级位置：吸气从最低音升到最高音，呼气原路返回。
  final pos = inhaling ? p : 1.0 - p;
  final steps = table.length - 1;
  final scaled = pos * steps;
  final index = scaled.round().clamp(0, steps).toInt();
  final frequency = table[index];

  // 钟形增益：sin(pi * pos)——相位中段最轻柔地亮起，两端归零。
  var gain = kBreathToneMaxGain * math.sin(math.pi * pos);
  // 呼吸紊乱：用更少的音回应（同一旋律，只把光调暗）。
  if (!steady) gain *= kBreathUnsteadyGainFactor;
  return BreathTone(frequency: frequency, gain: gain);
}

/// 呼吸之音开关的持久化：独立新键 `jingxin.breathsound.v1`。
///
/// 不复用 `jingxin.soundscape.v1` 的理由：那个键存的是声景场景枚举
/// 名（字符串），呼吸之音是正交的布尔开关（与选哪个声景无关，也
/// 可以单独存在）；塞进同一个键需要拼接/解析约定，反而脆。
/// 默认值：关——呼吸永远默认安静。
class BreathSoundPreference {
  static const String key = 'jingxin.breathsound.v1';

  bool _enabled = false;
  bool _loaded = false;

  /// 当前开关（未加载/读不到时为默认关）。
  bool get enabled => _enabled;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(key) ?? false;
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> save(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, enabled);
    } catch (_) {}
  }
}
