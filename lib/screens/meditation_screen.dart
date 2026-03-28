import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../ui/breathing_orb.dart';
import '../ui/glass_panel.dart';
import '../ui/starfield.dart';

class MeditationScreen extends StatefulWidget {
  final int durationMinutes;

  const MeditationScreen({super.key, required this.durationMinutes});

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

  late AnimationController _breathController;
  String _phase = '吸气';
  double _breathProgress = 0.0;

  final int _inhaleSeconds = 4;
  final int _holdSeconds = 7;
  final int _exhaleSeconds = 8;

  double _mouseX = 0.5;
  double _mouseY = 0.5;

  final _breathDuration = 19;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.durationMinutes * 60;

    _breathController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _breathDuration),
    )..addListener(_updateBreathPhase);

    _startCountdown();
  }

  void _updateBreathPhase() {
    final progress = _breathController.value;
    final inhaleEnd = _inhaleSeconds / _breathDuration;
    final holdEnd = (_inhaleSeconds + _holdSeconds) / _breathDuration;

    String newPhase;
    double newProgress;

    if (progress < inhaleEnd) {
      newPhase = '吸气';
      newProgress = progress / inhaleEnd;
    } else if (progress < holdEnd) {
      newPhase = '屏息';
      newProgress = 1.0;
    } else {
      newPhase = '呼气';
      newProgress = 1.0 - ((progress - holdEnd) / (1 - holdEnd));
    }

    if (newPhase != _phase || (newProgress - _breathProgress).abs() > 0.01) {
      setState(() {
        _phase = newPhase;
        _breathProgress = newProgress;
      });
    }
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _breathController.repeat();
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
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _breathController.stop();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isPaused && !_isCountingDown) {
      _breathController.stop();
    } else if (state == AppLifecycleState.resumed && !_isCountingDown) {
      _breathController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _breathController.stop();
    } else {
      _breathController.repeat();
    }
  }

  void _exit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZenTheme.deepSpace.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('结束冥想?', style: TextStyle(color: ZenTheme.starWhite)),
        content: const Text(
          '确定要退出吗?',
          style: TextStyle(color: ZenTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mouseX = event.position.dx / MediaQuery.of(context).size.width;
            _mouseY = event.position.dy / MediaQuery.of(context).size.height;
          });
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: isLandscape
                  ? _buildLandscapeLayout(constraints)
                  : _buildPortraitLayout(constraints),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    return Stack(
      children: [
        Starfield(mouseX: _mouseX, mouseY: _mouseY),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildOrbSection(),
                const Spacer(),
                _buildControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    return Stack(
      children: [
        Starfield(mouseX: _mouseX, mouseY: _mouseY),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(child: _buildOrbSection()),
                const SizedBox(width: 24),
                Expanded(child: _buildControls()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _exit,
          icon: const Icon(Icons.close, color: ZenTheme.textMuted),
        ),
        Text(
          _isCountingDown ? '准备' : _phase,
          style: const TextStyle(
            color: ZenTheme.starWhite,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildOrbSection() {
    if (_isCountingDown) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '准备好',
              style: TextStyle(color: ZenTheme.textMuted, fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              '$_countdown',
              style: const TextStyle(
                color: ZenTheme.nebulaCyan,
                fontSize: 120,
                fontWeight: FontWeight.w100,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 280,
          height: 280,
          child: BreathingOrb(
            breatheProgress: _breathProgress,
            phase: _phase,
            isPaused: _isPaused,
            onTap: _togglePause,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _phase,
          style: const TextStyle(
            color: ZenTheme.starWhite,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1 - (_remainingSeconds / (widget.durationMinutes * 60));

    return GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: ZenTheme.starWhite,
              fontSize: 48,
              fontWeight: FontWeight.w100,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: ZenTheme.deepSpace,
                  valueColor: const AlwaysStoppedAnimation(ZenTheme.nebulaCyan),
                ),
                IconButton(
                  onPressed: _togglePause,
                  icon: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: ZenTheme.starWhite,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPaused ? '已暂停' : '冥想中',
            style: const TextStyle(color: ZenTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZenButton(
                label: _isPaused ? '继续' : '暂停',
                icon: _isPaused ? Icons.play_arrow : Icons.pause,
                onPressed: _togglePause,
              ),
              const SizedBox(width: 16),
              ZenButton(
                label: '结束',
                icon: Icons.stop,
                isPrimary: false,
                onPressed: _exit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
