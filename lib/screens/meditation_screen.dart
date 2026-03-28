import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meditation_session.dart';
import '../providers/meditation_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/breathing_circle.dart';

class MeditationScreen extends StatefulWidget {
  final int durationMinutes;
  final MeditationMode mode;

  const MeditationScreen({
    super.key,
    required this.durationMinutes,
    required this.mode,
  });

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late Timer _timer;
  int _remainingSeconds = 0;
  bool _isPaused = false;
  bool _isCountingDown = true;
  int _countdown = 3;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Stopwatch _stopwatch;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.durationMinutes * 60;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
    _startCountdown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isPaused && !_isCountingDown) {
      _pausedAt = DateTime.now();
      _stopwatch.stop();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
      _remainingSeconds = (_remainingSeconds - elapsed).clamp(
        0,
        _remainingSeconds,
      );
      _stopwatch.start();
      _pausedAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
      });
      if (_countdown <= 0) {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _startMeditation();
      }
    });
  }

  void _startMeditation() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _completeSession();
        }
      }
    });
  }

  void _completeSession() async {
    final session = MeditationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now().subtract(
        Duration(minutes: widget.durationMinutes),
      ),
      durationSeconds: widget.durationMinutes * 60,
      mode: widget.mode,
      completed: true,
    );
    await context.read<MeditationProvider>().addSession(session);

    if (!mounted) return;
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.accent, size: 32),
            SizedBox(width: 12),
            Text('冥想完成', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.durationMinutes}分钟',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.mode.displayName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('完成', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '结束冥想?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '确定要提前结束这次冥想吗?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final elapsedSeconds =
                  (widget.durationMinutes * 60) - _remainingSeconds;
              if (elapsedSeconds > 60) {
                final session = MeditationSession(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  startTime: DateTime.now().subtract(
                    Duration(seconds: elapsedSeconds),
                  ),
                  durationSeconds: elapsedSeconds,
                  mode: widget.mode,
                  completed: false,
                );
                await context.read<MeditationProvider>().addSession(session);
              }
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('结束', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isCountingDown
              ? _buildCountdown()
              : _buildMeditationContent(),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '准备好开始了吗',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            '$_countdown',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 120,
              fontWeight: FontWeight.w100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeditationContent() {
    final progress = 1 - (_remainingSeconds / (widget.durationMinutes * 60));

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _showExitConfirmation,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    widget.mode.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: _buildModeContent()),
            _buildBottomControls(progress),
          ],
        ),
      ],
    );
  }

  Widget _buildModeContent() {
    switch (widget.mode) {
      case MeditationMode.breathing:
        return const BreathingCircle(
          breatheInSeconds: 4,
          holdSeconds: 7,
          breatheOutSeconds: 8,
          instruction: '4-7-8 呼吸法：吸气4秒，屏息7秒，呼气8秒',
        );
      case MeditationMode.mindfulness:
        return _MindfulnessContent(
          elapsedRatio: 1 - (_remainingSeconds / (widget.durationMinutes * 60)),
        );
      case MeditationMode.guided:
        return _GuidedContent(
          remainingSeconds: _remainingSeconds,
          totalSeconds: widget.durationMinutes * 60,
        );
      case MeditationMode.relaxation:
        return _RelaxationContent(
          remainingSeconds: _remainingSeconds,
          totalSeconds: widget.durationMinutes * 60,
        );
    }
  }

  Widget _buildBottomControls(double progress) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: AppColors.secondaryBackground,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isPaused = !_isPaused;
                  });
                },
                icon: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 40,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w300,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPaused ? '已暂停' : '冥想中',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MindfulnessContent extends StatelessWidget {
  final double elapsedRatio;

  const _MindfulnessContent({required this.elapsedRatio});

  List<String> get _bodyParts => [
    '脚趾',
    '双脚',
    '腿部',
    '腹部',
    '胸部',
    '手臂',
    '双手',
    '肩膀',
    '颈部',
    '头部',
  ];

  @override
  Widget build(BuildContext context) {
    final partIndex = (elapsedRatio * _bodyParts.length).floor().clamp(
      0,
      _bodyParts.length - 1,
    );
    final currentPart = _bodyParts[partIndex];
    final progress = (elapsedRatio * _bodyParts.length) - partIndex;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 180 * progress,
                height: 180 * progress,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            '感受你的$currentPart',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '放松并感受这个部位的温度和感觉',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '${partIndex + 1} / ${_bodyParts.length}',
            style: const TextStyle(color: AppColors.accent, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _GuidedContent extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const _GuidedContent({
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  List<String> get _steps => [
    '找一个舒适的姿势坐好',
    '轻轻闭上眼睛',
    '深呼吸三次，放松身体',
    '将注意力放在呼吸上',
    '感受空气通过鼻腔',
    '让思绪如云朵飘过',
    '不要追逐或阻止想法',
    '只是观察，然后放下',
    '继续专注呼吸',
    '准备好回到现实',
  ];

  @override
  Widget build(BuildContext context) {
    final stepIndex = ((1 - (remainingSeconds / totalSeconds)) * _steps.length)
        .floor()
        .clamp(0, _steps.length - 1);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 200 * (1 - remainingSeconds / totalSeconds),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _steps[stepIndex],
              key: ValueKey(stepIndex),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelaxationContent extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const _RelaxationContent({
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (remainingSeconds / totalSeconds);
    final waveOffset = progress * 20;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
              progress,
            )!,
            AppColors.primaryBackground,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(seconds: 3),
                    width: 180 + (index * 40) + waveOffset,
                    height: 180 + (index * 40) + waveOffset,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(
                          alpha: 0.1 - (index * 0.03),
                        ),
                        width: 1,
                      ),
                    ),
                  );
                }),
                const Text('🌊', style: TextStyle(fontSize: 60)),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              '海浪轻拍岸边',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '想象自己躺在海滩上\n海风轻拂，浪声阵阵',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
