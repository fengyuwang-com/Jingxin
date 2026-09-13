/// 长夜的「晨光告别」演出（第 26 轮）。
///
/// 理念：长夜不该"被退出"，而该"天亮"。当用户在长夜里持续安静
/// （或明确点了结束长夜），世界自下而上漫入一道暖金晨光，星兽
/// 缓缓眯眼，白噪音平滑淡出——像夜替你守完最后一班。
///
/// 触发判定与节奏常数抽成纯静态，便于测试；演出本身由
/// jingjing_screen 的 UI 层编排（晨光渐变 + 偈语淡字），
/// 音频淡出复用既有 soundscape 的 gain ramp（绝不爆音）。
class LongNightFarewell {
  LongNightFarewell._();

  /// 持续无触摸/呼吸操作达到该秒数（长夜中）→ 晨光告别开始。
  static const double idleThresholdSeconds = 90;

  /// 晨光自下而上漫入的时长（秒）。15s 级极缓渐变，克制不炫。
  static const double dawnSeconds = 15;

  /// 告别偈语淡入完成后停留的时长（秒），随后整体淡出。
  static const double koanHoldSeconds = 10;

  /// 告别偈语自身的淡入时长（秒）。
  static const double koanFadeSeconds = 2;

  /// 演出收尾：整体淡出回普通世界态的时长（秒）。
  static const double fadeSeconds = 5;

  /// 白噪音淡出时长（秒）：走既有 soundscape 层 gain ramp，平滑无爆音。
  /// 比视觉整体略长，让声音最后消失——"光先亮，声后歇"。
  static const double audioFadeSeconds = 20;

  /// 用户任何触摸跳过时的快速淡出时长（秒）：立即完成、不突兀。
  static const double skipSeconds = 0.9;

  /// 触发判定（纯函数）：
  /// - 明确点了结束长夜的按钮 → 无条件开始；
  /// - 否则需长夜中安静满 [idleThresholdSeconds]。
  static bool shouldBegin({
    required double idleSeconds,
    required bool manuallyEnded,
  }) {
    return manuallyEnded || idleSeconds >= idleThresholdSeconds;
  }
}
