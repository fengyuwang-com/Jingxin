import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/breath_mic.dart';
import '../game/jingjing_game.dart';
import '../game/koans.dart';
import '../game/soundscape.dart';
import '../game/voice.dart';
import 'star_map_screen.dart';

/// 静境游戏画面：全屏 Flame GameWidget 展示呼吸光灵，可返回首页。
///
/// 第 2 轮：极简状态呈现——苏醒度以顶端一条极细渐变光线表达
/// （不显示数字，避免"分数感"），吸气/呼气提示词淡入淡出。
class JingjingScreen extends StatefulWidget {
  const JingjingScreen({super.key, this.seedColor = ZenTheme.nebulaCyan});

  final Color seedColor;

  @override
  State<JingjingScreen> createState() => _JingjingScreenState();
}

class _JingjingScreenState extends State<JingjingScreen>
    with WidgetsBindingObserver {
  late final JingjingGame _game;
  Timer? _koanTimer;

  /// 开场引导的一行淡字：进入静境时浮现又自行淡去。
  bool _showIntroLine = true;
  Timer? _introTimer;

  /// 声景引擎（Web 合成实现；非 Web 平台静音降级）。
  /// 懒创建：首次进入长夜（用户手势内）才真正初始化 AudioContext。
  SoundscapeEngine? _soundscape;

  /// 声景选择持久化与当前选择（默认海潮）。
  final SoundscapePreference _pref = SoundscapePreference();
  SoundscapeScene _scene = SoundscapeScene.sea;

  /// 长夜模式：true 时世界缓缓入夜，声景极缓淡入。
  bool _nightMode = false;

  // ---- 麦克风呼吸（第 9 轮）：完全可选、默认关闭、不持久化 ----
  /// 麦克风引擎（懒创建，只在用户点击手势内 start）。
  BreathMicEngine? _micEngine;

  /// 当前平台是否显示入口（非 Web stub 不可用 → 图标隐藏）。
  bool _micAvailable = false;

  /// 麦克风模式开启中。
  bool _micOn = false;

  /// 随息灵敏度（3 档，持久化 jingxin.mic.sens.v1）。
  final MicSensitivityPreference _micSensPref = MicSensitivityPreference();
  MicSensitivity _micSens = MicSensitivity.medium;

  /// 本次会话是否已开启过随息（首次开启时给一行"只听气息，不留声音"）。
  bool _micEverOn = false;

  /// 轻提示文字（玻璃拟态 toast，如"随息未就绪，轻触亦可行"）。
  String? _toastText;
  Timer? _toastTimer;

  // ---- 闻声（第 12 轮）：引导词轻声朗读，完全可选、默认关闭 ----
  /// 朗读引擎（Web 用浏览器原生 SpeechSynthesis；非 Web stub 静音，
  /// isSupported=false → UI 直接隐藏开关）。
  final VoiceEngine _voice = VoiceEngineImpl();

  /// 朗读开关持久化（key jingxin.voice.v1，默认关）。
  final VoicePreference _voicePref = VoicePreference();
  bool _voiceOn = false;

  /// 长夜入睡引导的随机低频朗读计时器（90~150 秒一次）。
  Timer? _whisperTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = JingjingGame(seedColor: widget.seedColor);
    _game.shardMessage.addListener(_onShardMessage);
    // 开场引导：一行淡字缓缓浮现，约 6 秒后自行淡去，绝无按钮。
    _introTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showIntroLine = false);
    });
    // 麦克风可用性探测（不请求权限，只看平台是否可能支持）。
    _micAvailable = BreathMicEngineImpl().isSupported;
    _micSensPref.load().then((_) {
      if (mounted) setState(() => _micSens = _micSensPref.value);
    });
    _pref.load().then((_) {
      if (!mounted) return;
      setState(() => _scene = _pref.scene);
      _game.setSoundscapeScene(_pref.scene);
    });
    // 闻声：朗读时把声景 master gain 轻压下去，读完缓缓恢复。
    _voice.onSpeakingStart = (_) => _soundscape?.duck(active: true);
    _voice.onSpeakingEnd = (_) => _soundscape?.duck(active: false);
    _voicePref.load().then((_) {
      if (!mounted) return;
      setState(() => _voiceOn = _voicePref.enabled);
      _syncWhisperTimer();
    });
  }

  /// 碎片被吸入：禅语玻璃面板淡入，停留数秒后自行淡出。
  /// 不打断漫游，也不需要玩家做任何操作。
  void _onShardMessage() {
    final koan = _game.shardMessage.value;
    if (koan == null) return;
    _koanTimer?.cancel();
    _game.shardMessage.value = null;
    _showKoan(koan);
  }

  void _showKoan(String koan) {
    setState(() => _koanText = koan);
    // 闻声：开启朗读时轻声读出这句禅语（禅语不因触摸取消，让它读完）。
    if (_voiceOn) _voice.speak(koan, kind: VoiceKind.koan);
    _koanTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _koanText = null);
    });
  }

  String? _koanText;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introTimer?.cancel();
    _game.shardMessage.removeListener(_onShardMessage);
    _koanTimer?.cancel();
    _toastTimer?.cancel();
    _whisperTimer?.cancel();
    _soundscape?.stop(fadeOut: 1.5);
    _voice.cancelAll(); // 退出静境：一切朗读停止。
    unawaited(_micEngine?.stop()); // 彻底释放麦克风流与轨道。
    _game.awakening.save();
    super.dispose();
  }

  /// 生命周期安全（第 11 轮）：切到后台时声景缓缓停下，
  /// 回到前台时若仍在长夜则再缓缓浮起——声音不惊扰、不泄漏。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      unawaited(_soundscape?.stop(fadeOut: 0.8));
      _voice.cancelAll(); // 切后台：朗读立即停止，绝不从后台冒出声音。
    } else if (state == AppLifecycleState.resumed && _nightMode) {
      final engine = _soundscape ??= SoundscapeEngineImpl();
      unawaited(engine.start(fadeIn: 3.0));
    }
  }

  /// 开/关麦克风呼吸输入。getUserMedia 只在此点击手势的调用栈内触发；
  /// 失败（权限拒绝/无设备/不支持）→ 一行淡字提示并自动回到触控模式，
  /// 绝不弹错误对话框、绝不反复请求。开启状态不持久化（每次会话重新
  /// 选择），灵敏度档位持久化。
  Future<void> _toggleMic() async {
    if (_micOn) {
      setState(() => _micOn = false);
      _game.enableMicBreath(null);
      unawaited(_micEngine?.stop()); // 不用时彻底释放轨道。
      return;
    }
    final engine = _micEngine ??= BreathMicEngineImpl();
    engine.setSensitivity(_micSens);
    final ok = await engine.start(); // 手势调用栈内请求权限。
    if (!mounted) {
      unawaited(engine.stop());
      return;
    }
    if (!ok) {
      // 静默回退到触控模式：一行淡字，绝不弹错误对话框。
      _showToast('随息未就绪，轻触亦可行');
      return;
    }
    setState(() => _micOn = true);
    _game.enableMicBreath(engine);
    if (!_micEverOn) {
      _micEverOn = true;
      _showToast('只听气息，不留声音'); // 隐私说明：一次、一行、极淡。
    }
  }

  /// 切换随息灵敏度：立即生效并持久化，不打断呼吸。
  Future<void> _selectMicSensitivity(MicSensitivity s) async {
    setState(() => _micSens = s);
    _micEngine?.setSensitivity(s);
    await _micSensPref.save(s);
  }

  void _showToast(String text) {
    setState(() => _toastText = text);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  /// 进入/退出长夜：世界渐暗 + 星更亮（game 侧渐变），白噪音淡入淡出。
  /// 首次点击（用户手势）时才创建 AudioContext，规避浏览器自动播放限制。
  Future<void> _toggleNight() async {
    final entering = !_nightMode;
    setState(() => _nightMode = entering);
    _game.setNight(entering);
    if (entering) {
      await _game.longNight.markVisited();
      final engine = _soundscape ??= SoundscapeEngineImpl();
      await engine.select(_scene); // 未播放时只记录选择
      unawaited(engine.start(fadeIn: 4.0));
      _syncWhisperTimer(); // 闻声：长夜里随机低频的入睡引导。
    } else {
      _whisperTimer?.cancel();
      _voice.cancelAll(); // 退出长夜：声景淡出的同时朗读也停。
      unawaited(_soundscape?.stop(fadeOut: 3.0));
    }
  }

  /// 长夜入睡引导：每 90~150 秒随机一次，轻声读一句极短句。
  /// 极低频率——引导词是夜里偶尔飘过的一句，不是旁白。
  void _syncWhisperTimer() {
    _whisperTimer?.cancel();
    if (!_nightMode || !_voiceOn) return;
    _whisperTimer = Timer(Duration(seconds: 90 + math.Random().nextInt(61)), () {
      if (!mounted || !_nightMode || !_voiceOn) return;
      _voice.speak(Koans.nextWhisper(), kind: VoiceKind.whisper);
      _syncWhisperTimer();
    });
  }

  /// 开/关「闻声」：持久化；关闭时停掉一切朗读与长夜计时器。
  Future<void> _toggleVoice() async {
    final on = !_voiceOn;
    setState(() => _voiceOn = on);
    await _voicePref.save(on);
    if (on) {
      _showToast('闻声已开');
      _syncWhisperTimer();
    } else {
      _whisperTimer?.cancel();
      _voice.cancelAll();
    }
  }

  /// 切换声景：交叉渐变（旧淡出/新淡入）+ 视听联动 + 持久化。
  Future<void> _selectScene(SoundscapeScene scene) async {
    if (scene == _scene) return;
    setState(() => _scene = scene);
    _game.setSoundscapeScene(scene);
    await _pref.save(scene);
    if (_nightMode) {
      unawaited(_soundscape?.select(scene, crossfade: 2.5));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.voidBlack,
      body: Stack(
        children: [
          // 游戏本体：包一层 Listener——用户任何触摸交互时，若正在
          // 朗读入睡引导则立即取消（禅语朗读不受影响，让它读完）。
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _voice.cancelWhisper(),
              child: GameWidget(game: _game),
            ),
          ),
          // 长夜遮罩：整体缓缓转入深夜色调（更暗），不挡任何操作。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(seconds: 4),
                curve: Curves.easeOut,
                color: _nightMode
                    ? const Color(0xFF02040C).withValues(alpha: 0.42)
                    : const Color(0xFF02040C).withValues(alpha: 0),
              ),
            ),
          ),
          // 顶端极细渐变光线：苏醒度的无声表达。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _game.awakeningValue,
              builder: (context, awakening, _) {
                final glow = (0.15 + 0.85 * awakening).clamp(0.0, 1.0);
                return Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.seedColor.withValues(alpha: 0.1 * glow),
                        widget.seedColor.withValues(alpha: 0.85 * glow),
                        ZenTheme.nebulaPurple.withValues(alpha: 0.85 * glow),
                        widget.seedColor.withValues(alpha: 0.1 * glow),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.seedColor.withValues(alpha: 0.35 * glow),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 开场引导：一行淡字缓缓浮现又自行淡去——这是第一口气之前的
          // 唯一提示，无按钮、不打扰。
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(0, -0.32),
                child: AnimatedOpacity(
                  opacity: _showIntroLine ? 1 : 0,
                  duration: const Duration(milliseconds: 2200),
                  curve: Curves.easeOut,
                  child: Text(
                    '你的呼吸，点亮这个世界',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZenTheme.textMuted.withValues(alpha: 0.42),
                      fontSize: 13,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 呼吸提示词：淡入淡出，随呼吸方向切换。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: ValueListenableBuilder<String?>(
                  valueListenable: _game.breathHint,
                  builder: (context, hint, _) {
                    return AnimatedOpacity(
                      opacity: hint == null ? 0 : 1,
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOut,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 900),
                        child: Text(
                          hint ?? ' ',
                          key: ValueKey(hint),
                          style: TextStyle(
                            color: ZenTheme.textMuted.withValues(alpha: 0.7),
                            fontSize: 15,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // 心镜碎片禅语：玻璃拟态面板，淡入-停留-淡出，不可交互不打断漫游。
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 72),
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _koanText == null ? 0 : 1,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _koanText == null
                        ? const SizedBox.shrink()
                        : _KoanGlassPanel(text: _koanText!),
                  ),
                ),
              ),
            ),
          ),
          // 长夜提示：世界睡了，你也可以睡了。极淡、缓缓浮现。
          Positioned(
            bottom: 86,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _nightMode ? 1 : 0,
                duration: const Duration(seconds: 3),
                curve: Curves.easeOut,
                child: Text(
                  '世界睡了，你也可以睡了',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ZenTheme.textMuted.withValues(alpha: 0.45),
                    fontSize: 13,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),
          ),
          // 声景选择：长夜里浮现的三个小字（海潮 · 夜雨 · 篝火），
          // 玻璃拟态、无滑块无设置页；只有长夜中可点。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 122),
                child: IgnorePointer(
                  ignoring: !_nightMode,
                  child: AnimatedOpacity(
                    opacity: _nightMode ? 1 : 0,
                    duration: const Duration(seconds: 3),
                    curve: Curves.easeOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: ZenTheme.surfaceDim.withValues(alpha: 0.32),
                          border: Border.all(
                            color: ZenTheme.nebulaCyan.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final scene in SoundscapeScene.values) ...[
                              if (scene != SoundscapeScene.sea)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      color: ZenTheme.textMuted.withValues(
                                        alpha: 0.25,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectScene(scene),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    scene.label,
                                    style: TextStyle(
                                      color: ZenTheme.textMuted.withValues(
                                        alpha: scene == _scene ? 0.9 : 0.38,
                                      ),
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 轻提示 toast：玻璃拟态小字，如"未能听见你的呼吸"，自来自去。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 170),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _toastText == null ? 0 : 1,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _toastText == null
                          ? const SizedBox.shrink()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: ZenTheme.surfaceDim.withValues(
                                    alpha: 0.5,
                                  ),
                                  border: Border.all(
                                    color: ZenTheme.nebulaCyan.withValues(
                                      alpha: 0.16,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _toastText!,
                                  style: TextStyle(
                                    color: ZenTheme.textMuted.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: 13,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 右下角极小的声息入口：麦克风呼吸的开与关，克制如一缕气息。
          // 非 Web 平台（stub 不可用）整个入口隐藏，绝不弹窗打扰。
          if (_micAvailable)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 62),
                  child: IconButton(
                    tooltip: _micOn ? '回到触控呼吸' : '用真实的呼吸',
                    icon: Icon(
                      _micOn ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                      size: 20,
                      color: ZenTheme.textMuted.withValues(
                        alpha: _micOn ? 0.85 : 0.5,
                      ),
                    ),
                    onPressed: _toggleMic,
                  ),
                ),
              ),
            ),
          // 随息灵敏度三小字（低 · 中 · 高）：仅随息开启时浮现，
          // 玻璃拟态、克制；切换立即生效并持久化。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: IgnorePointer(
                  ignoring: !_micOn,
                  child: AnimatedOpacity(
                    opacity: _micOn ? 1 : 0,
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: ZenTheme.surfaceDim.withValues(alpha: 0.28),
                          border: Border.all(
                            color: ZenTheme.nebulaCyan.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 6, right: 2),
                              child: Text(
                                '随息',
                                style: TextStyle(
                                  color: ZenTheme.textMuted.withValues(
                                    alpha: 0.32,
                                  ),
                                  fontSize: 11,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            for (final s in MicSensitivity.values)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectMicSensitivity(s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    s.label,
                                    style: TextStyle(
                                      color: ZenTheme.textMuted.withValues(
                                        alpha: s == _micSens ? 0.9 : 0.35,
                                      ),
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 左下角极小的喇叭入口（第 12 轮「闻声」）：禅语轻声朗读的
          // 开关，与随息/长夜入口同一风格的角落图标。浏览器尚未加载出
          // 任何可用声音时（available=false）整个入口隐藏，绝不弹窗。
          if (_voice.isSupported)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 62),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _voice.available,
                    builder: (context, available, _) {
                      if (!available) return const SizedBox.shrink();
                      return IconButton(
                        tooltip: _voiceOn ? '闻声 · 轻声念' : '闻声',
                        icon: Icon(
                          _voiceOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 20,
                          color: ZenTheme.textMuted.withValues(
                            alpha: _voiceOn ? 0.85 : 0.5,
                          ),
                        ),
                        onPressed: _toggleVoice,
                      );
                    },
                  ),
                ),
              ),
            ),
          // 右下角极小的月亮入口：长夜的开关，克制如一枚月痕。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: _nightMode ? '退出长夜' : '长夜',
                  icon: Icon(
                    _nightMode ? Icons.nightlight_round : Icons.nightlight_outlined,
                    size: 20,
                    color: ZenTheme.textMuted.withValues(
                      alpha: _nightMode ? 0.85 : 0.5,
                    ),
                  ),
                  onPressed: _toggleNight,
                ),
              ),
            ),
          ),
          // 左下角极小的星图入口：克制、半透明，像风景里的一扇小窗。
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: '我的静境星图',
                  icon: Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: ZenTheme.textMuted.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: ZenMotion.page,
                        pageBuilder: (_, _, _) => StarMapScreen(
                          // 闻声（可选）：点星时轻声读那句偈语——仅当
                          // 用户开了朗读才传，否则完全静默。
                          onSpeakKoan: _voiceOn
                              ? (koan) => _voice.speak(
                                  koan,
                                  kind: VoiceKind.koan,
                                )
                              : null,
                        ),
                        transitionsBuilder: (_, animation, _, child) =>
                            FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: ZenMotion.pageCurve,
                              ),
                              child: child,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: '返回',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: ZenTheme.textMuted,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 禅语玻璃面板：毛玻璃 + 细边微光，呈现碎片上的句子。
class _KoanGlassPanel extends StatelessWidget {
  const _KoanGlassPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: ZenTheme.surfaceDim.withValues(alpha: 0.5),
          border: Border.all(
            color: ZenTheme.nebulaCyan.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ZenTheme.textHigh,
            fontSize: 15,
            height: 1.7,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
