/// 星兽「注视」（第 51 轮）。
///
/// 理念：玩家把光灵停在星兽近旁足够久、呼吸又平稳时，星兽会"回望"
/// ——一次极克制的注视演出。不是奖励动画，更像被夜里的什么
/// 安静地看见了。
///
/// 规则（全部纯函数，状态由 [BeastGazeCtl] 在游戏层内存持有，不持久化）：
/// - 星兽未半醒（苏醒度 < [kGazeMinAwakening]）则注视永为 0；
/// - 在近旁且呼吸平稳时，注视进度以约 [kGazeFillSeconds]（45s）
///   smoothstep 平滑注满 0→1；
/// - 呼吸乱了按 [kGazeBrokenDecayPerSecond] 快速退回（8s 内掉一半）；
///   平稳地离开则按 [kGazeLeftDecayPerSecond] 慢慢收回目光；
/// - progress 越过 [kGazePulseThreshold]（0.55）触发一次注视脉冲：
///   眼睛短暂亮起 + 一条极细光丝，[kGazePulseSeconds]（3.5s）自然消散；
///   每只星兽每夜至多 [kGazeMaxPulsesPerNight] 次；
/// - progress 注满（=1）时可浮出一句极短低语，冷却 [kGazeWhisperCooldownSeconds]。
library;

import 'dart:math' as math;

/// 注满注视所需的有效驻留秒数（约 45s）。
const double kGazeFillSeconds = 45.0;

/// 触发注视的最低苏醒度（眠的 value / 惘的 reveal，未半醒永不回望）。
const double kGazeMinAwakening = 0.5;

/// 注视脉冲阈值：progress 越过此值触发一次眼睛亮起 + 光丝。
const double kGazePulseThreshold = 0.55;

/// 注视脉冲时长（秒）：眼睛亮起与光丝自然消散的一个来回。
const double kGazePulseSeconds = 3.5;

/// 每只星兽每夜至多注视脉冲次数（防滥用，内存态）。
const int kGazeMaxPulsesPerNight = 2;

/// 呼吸乱时的注视流失速度（dwell 秒/秒）——快。
/// 配平注：从注满的任意进度起，8 秒内进度至少掉一半
/// （dwell 快速流失 + 失稳软压低双重保证）。
const double kGazeBrokenDecayPerSecond = 1.6;

/// 平稳离开时的注视流失速度（dwell 秒/秒）——慢，像慢慢收回目光。
const double kGazeLeftDecayPerSecond = 0.4;

/// 注满后的低语冷却（秒）。
const double kGazeWhisperCooldownSeconds = 120.0;

/// 注视低语池（极短，像一句轻声的确认）。
const List<String> kGazeWhispers = [
  '它望过来了。',
  '被安静地看见了。',
  '你们曾一同呼吸。',
  '夜还长，它陪着你。',
];

double _smooth(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

/// 注视进度映射（纯函数）。
///
/// [dwellSeconds] 是"有效驻留秒数"——由调用方按条件增减维护；
/// [breathSteadiness] 0..1 平稳度（应为低通后的连续值，绝不瞬跳），
/// 失稳时对进度软压低（与 dwell 快速流失叠加，保证 8s 内掉一半）；
/// [beastAwakening] 星兽苏醒度，未半醒恒 0。
double beastGazeProgress({
  required double dwellSeconds,
  required double breathSteadiness,
  required double beastAwakening,
}) {
  if (beastAwakening < kGazeMinAwakening) return 0;
  final p = _smooth((dwellSeconds / kGazeFillSeconds).clamp(0.0, 1.0));
  final s = breathSteadiness.clamp(0.0, 1.0);
  return p * (0.55 + 0.45 * s);
}

/// 单帧推进有效驻留秒数（纯函数，状态在调用方）。
///
/// 近旁且平稳 → 累积；平稳地离开 → 慢速流失；呼吸乱 → 快速流失；
/// 未半醒 → 直接归零（永为 0）。结果恒夹在 0..[kGazeFillSeconds]。
double beastGazeDwellNext({
  required double dwellSeconds,
  required double dt,
  required bool near,
  required bool breathSteady,
  required double beastAwakening,
}) {
  if (beastAwakening < kGazeMinAwakening) return 0;
  if (near && breathSteady) {
    return (dwellSeconds + dt).clamp(0.0, kGazeFillSeconds);
  }
  final rate =
      breathSteady ? kGazeLeftDecayPerSecond : kGazeBrokenDecayPerSecond;
  return (dwellSeconds - rate * dt).clamp(0.0, kGazeFillSeconds);
}

/// 注视视觉映射（纯函数）：progress → 眼睛亮度/注视强度 0..1。
///
/// 输出按 0.02 步进量化（渲染端直接用作 alpha，符合量化纪律）；
/// 单调不减、两端归零/归一，前段极弱（不喧宾夺主），越接近注满越亮。
double beastGazeVisual(double progress) {
  final p = progress.clamp(0.0, 1.0);
  final s = _smooth(p);
  return (s * 50).round() / 50.0; // 0.02 步进量化
}

/// 注视脉冲包络（纯函数）：[kGazePulseSeconds] 内 sin 起落，两端归零。
double beastGazePulseEnvelope(double t) {
  if (t <= 0 || t >= kGazePulseSeconds) return 0;
  return math.sin(math.pi * t / kGazePulseSeconds);
}

/// 单只星兽的注视控制器（游戏层内存态，不持久化）。
class BeastGazeCtl {
  /// 有效驻留秒数（0..[kGazeFillSeconds]）。
  double dwell = 0;

  /// 当前注视进度 0..1。
  double progress = 0;

  /// 本夜已触发的注视脉冲次数。
  int pulsesThisNight = 0;

  // 失稳平滑：呼吸平稳与否的低通（显示连续性，绝不瞬跳）。
  double _steadySm = 1.0;
  double _pulseT = -1; // <0 = 无脉冲演出
  double _whisperCooldown = 0;
  bool _whisperArmed = true;
  bool _whisperRequest = false;

  /// 当前脉冲演出的包络 0..1（无脉冲时 0）。
  double get pulseEnvelope =>
      _pulseT < 0 ? 0 : beastGazePulseEnvelope(_pulseT);

  /// 开启一晚：清空每夜脉冲计数（与星兽低语同款记账）。
  void beginNight() {
    pulsesThisNight = 0;
  }

  /// 每帧推进：喂入近旁/平稳/苏醒度，维护 dwell、进度、脉冲与低语请求。
  void update({
    required double dt,
    required bool near,
    required bool breathSteady,
    required double beastAwakening,
  }) {
    _steadySm += ((breathSteady ? 1.0 : 0.0) - _steadySm) *
        math.min(1.0, dt * 0.8);
    dwell = beastGazeDwellNext(
      dwellSeconds: dwell,
      dt: dt,
      near: near,
      breathSteady: breathSteady,
      beastAwakening: beastAwakening,
    );
    final prev = progress;
    progress = beastGazeProgress(
      dwellSeconds: dwell,
      breathSteadiness: _steadySm,
      beastAwakening: beastAwakening,
    );

    if (_pulseT >= 0) {
      _pulseT += dt;
      if (_pulseT >= kGazePulseSeconds) _pulseT = -1;
    }
    if (_whisperCooldown > 0) _whisperCooldown = math.max(0, _whisperCooldown - dt);

    // 注视脉冲：progress 自下而上越过阈值时触发一次，每夜限量。
    if (_pulseT < 0 &&
        pulsesThisNight < kGazeMaxPulsesPerNight &&
        prev < kGazePulseThreshold &&
        progress >= kGazePulseThreshold) {
      _pulseT = 0;
      pulsesThisNight++;
    }

    // 注满低语：progress=1 时请求一次，冷却 2 分钟；掉回 0.9 以下重新武装。
    if (progress >= 0.999) {
      if (_whisperArmed && _whisperCooldown <= 0) {
        _whisperArmed = false;
        _whisperCooldown = kGazeWhisperCooldownSeconds;
        _whisperRequest = true;
      }
    } else if (progress < 0.9) {
      _whisperArmed = true;
    }
  }

  /// 取走一次低语请求（有则 true 并清零）。
  bool consumeWhisperRequest() {
    final r = _whisperRequest;
    _whisperRequest = false;
    return r;
  }
}
