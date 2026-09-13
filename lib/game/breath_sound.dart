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

// ---- 入睡礼让（第 45 轮）：夜越深，琴越轻 ----

/// 进入长夜后呼吸音降到「半档」（60%）的时刻（秒）。
const double kBreathLullHalfSeconds = 600;

/// 进入长夜后呼吸音降到「极轻」（35%）的时刻（秒）。
const double kBreathLullDeepSeconds = 1200;

/// 「半档」系数。
const double kBreathLullHalfFactor = 0.6;

/// 「极轻」系数。
const double kBreathLullDeepFactor = 0.35;

/// 两段边界前后各 [kBreathLullRampSeconds/2] 秒的平滑过渡窗总宽（秒）：
/// 用 smoothstep 在 60 秒里缓缓滑下去，绝不跳变。
const double kBreathLullRampSeconds = 60;

/// 晨光回涨（第 47 轮）：daylight 达到该值时呼吸音回涨到全量。
/// DayTide.daylight 以 6:00 过零、正午 +1，0.5 约在上午 9:00——
/// 太阳升起后的三个小时里，琴随晨光缓缓涨回来。
const double kBreathDawnFullDaylight = 0.5;

/// 晨光回涨进度（纯函数，0..1）：[daylight] 为 DayTide.daylight
///（-1..1，清晨从 0 起升）。daylight ≤ 0（天还没亮）时为 0——
/// 纯夜间礼让系数原样生效；daylight ≥ [kBreathDawnFullDaylight]
/// 时为 1——回涨完成。中间用 smoothstep（3t²-2t³，两端导数为
/// 零）过渡：6:00 太阳在地平线处回涨恰好从零开始，无起步顿挫。
double breathDawnProgress(double daylight) {
  if (daylight <= 0) return 0.0;
  final t = (daylight / kBreathDawnFullDaylight).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// 晨光回涨复合（纯函数）：把夜间礼让系数 [nightFactor]
///（breathNightFactor 的结果，0.35..1.0）与晨光进度复合——
/// 天亮后增益从夜间的低量沿晨光平滑涨回全量 1.0：
/// factor = nightFactor + (1 - nightFactor) × breathDawnProgress。
///
/// 连续性：nightFactor 对秒连续、daylight 对分钟连续，两侧都是
/// smoothstep 光滑过渡，复合无跳变；daylight ≤ 0 时严格等于
/// nightFactor（回涨不提前启动）。非长夜（nightFactor=1）时恒 1.0。
double breathDawnFactor(double daylight, double nightFactor) {
  final n = nightFactor.clamp(0.0, 1.0).toDouble();
  return n + (1.0 - n) * breathDawnProgress(daylight);
}

// ---- 晨光泛音（第 50 轮）：满醒日，世界醒来的第一声更亮 ----

/// 满醒日晨光泛音的峰值增益（极轻，不喧宾夺主）。
const double kBreathDawnOvertoneMaxGain = 0.12;

/// 晨光泛音增益（纯函数）：满醒日印当天（最近一次满醒的 yyyyMMdd
/// 与今天相同），晨光回涨段呼吸音之上叠一层极轻的高八度泛音——
/// [dawnProgress] 为 breathDawnProgress 的结果（0..1），用 smoothstep
///（两端导数为零）随晨光平滑升起，无起步顿挫；进度到 1 后保持峰值
///（世界已醒，声音亮着）。非满醒日恒 0——泛音是满醒纪念日独有的
/// 一层亮色。越界的 dawnProgress 钳制到 0..1。
double breathDawnOvertoneGain({
  required bool isFullAwakeDay,
  required double dawnProgress,
}) {
  if (!isFullAwakeDay) return 0.0;
  final t = dawnProgress.clamp(0.0, 1.0).toDouble();
  return kBreathDawnOvertoneMaxGain * t * t * (3 - 2 * t);
}

/// 随息（麦克风）联动：呼吸音随气息包络起伏的幅度（±15%）。
const double kBreathWobbleDepth = 0.15;

/// 长夜已持续 [seconds] 秒时，呼吸音的全局增益系数（纯函数）。
///
/// 三段平台：0~10 分钟全量 1.0 → 10~20 分钟「半档」0.6 → 20 分钟后
/// 「极轻」0.35；两段边界各用 60 秒 smoothstep 缓缓滑落（入睡的人
/// 不该听见任何"被调小"的动作）。呼吸相位映射不变，只乘这一系数；
/// 退出长夜时调用方把系数平滑 ramp 回 1.0。
double breathNightFactor(double seconds) {
  if (seconds <= 0) return 1.0;
  double f = 1.0;
  f = _lullStep(
    seconds,
    boundary: kBreathLullHalfSeconds,
    lowFactor: kBreathLullHalfFactor,
    incoming: f,
  );
  f = _lullStep(
    seconds,
    boundary: kBreathLullDeepSeconds,
    lowFactor: kBreathLullDeepFactor,
    incoming: f,
  );
  return f;
}

/// 单段礼让：边界前保持 [incoming]，边界后落到 [lowFactor]，
/// 边界前后各半窗用 smoothstep（3t²-2t³，两端导数为零）过渡。
double _lullStep(
  double seconds, {
  required double boundary,
  required double lowFactor,
  required double incoming,
}) {
  final half = kBreathLullRampSeconds / 2;
  if (seconds <= boundary - half) return incoming;
  if (seconds >= boundary + half) return lowFactor;
  final t = (seconds - (boundary - half)) / kBreathLullRampSeconds;
  final s = t * t * (3 - 2 * t);
  return incoming + (lowFactor - incoming) * s;
}

/// 随息（麦克风）联动（纯函数）：把平滑呼吸包络（0..1，见
/// jingjing_game.micEnvelope）映射成 ±15% 的音量起伏系数——
/// 气息饱满时琴声微微扬起、气息歇下时轻轻收回，像琴随呼吸呼吸。
///
/// 未开随息时调用方传 0.5（构造上恰为 1.0，呼吸音保持原档位）：
/// 这个"以中点为零"的约定让两条路径共用同一个纯函数，无需分支。
double breathWobbleFactor(double envelope) {
  final e = envelope.clamp(0.0, 1.0).toDouble();
  return (1.0 - kBreathWobbleDepth) + 2 * kBreathWobbleDepth * e;
}

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
