import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/meditation_provider.dart';
import '../ui/breathing_orb.dart';
import '../ui/glass_panel.dart';
import '../ui/starfield.dart';

class MeditationScreen extends StatefulWidget {
  final int durationMinutes;
  final BreathSettings settings;

  const MeditationScreen({
    super.key,
    required this.durationMinutes,
    required this.settings,
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
  int _phaseRemainingSeconds = 0;

  late AnimationController _breathController;
  late AnimationController _smoothBreathController;
  String _phase = '吸气';
  String _displayPhase = '吸气';
  double _breathProgress = 0.0;
  double _displayBreathProgress = 0.0;

  late BreathSettings _settings;

  double _mouseX = 0.5;
  double _mouseY = 0.5;
  int _lastParallaxUpdate = 0;

  void _updateParallax(double x, double y) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastParallaxUpdate > 500) {
      _lastParallaxUpdate = now;
      setState(() {
        _mouseX = x;
        _mouseY = y;
      });
    }
  }

  Color get _primaryColor {
    try {
      return context.read<MeditationProvider>().seedColor;
    } catch (_) {
      return ZenTheme.nebulaCyan;
    }
  }

  Color get _secondaryColor {
    try {
      return ZenTheme.secondaryFor(
        context.read<MeditationProvider>().seedColor,
      );
    } catch (_) {
      return ZenTheme.nebulaPurple;
    }
  }

  bool get _isDarkMode {
    try {
      return context.read<MeditationProvider>().isDarkMode;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = widget.settings;
    _remainingSeconds = widget.durationMinutes * 60;

    _breathController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _settings.totalCycle),
    )..addListener(_updateBreathPhase);

    _smoothBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startCountdown();
  }

  void _updateBreathPhase() {
    final progress = _breathController.value;
    final inhaleEnd = _settings.inhale / _settings.totalCycle;
    final holdEnd = (_settings.inhale + _settings.hold) / _settings.totalCycle;

    String newPhase;
    double newProgress;
    bool critical = false;
    int remaining = 0;

    if (progress < inhaleEnd) {
      newPhase = '吸气';
      newProgress = progress / inhaleEnd;
      remaining = ((1 - newProgress) * _settings.inhale).ceil().clamp(
        1,
        _settings.inhale,
      );
    } else if (progress < holdEnd) {
      newPhase = '屏息';
      newProgress = 1.0;
      final holdProgress = (progress - inhaleEnd) / (holdEnd - inhaleEnd);
      remaining = ((1 - holdProgress) * _settings.hold).ceil().clamp(
        1,
        _settings.hold,
      );
      if (remaining <= 1.5) critical = true;
    } else {
      newPhase = '呼气';
      newProgress = 1.0 - ((progress - holdEnd) / (1 - holdEnd));
      remaining = (newProgress * _settings.exhale).ceil().clamp(
        1,
        _settings.exhale,
      );
    }

    if (newPhase != _phase) {
      _animatePhaseTransition(newPhase, newProgress);
    }

    if ((newProgress - _breathProgress).abs() > 0.01 ||
        remaining != _phaseRemainingSeconds) {
      setState(() {
        _phase = newPhase;
        _breathProgress = newProgress;
        _phaseRemainingSeconds = remaining;
      });
    }
  }

  void _animatePhaseTransition(String newPhase, double newProgress) {
    _displayPhase = newPhase;
    _displayBreathProgress = newProgress;

    _smoothBreathController.reset();
    _smoothBreathController.forward();
  }

  double get _smoothedProgress {
    if (!_smoothBreathController.isAnimating) {
      return _breathProgress;
    }
    return Tween<double>(begin: _displayBreathProgress, end: _breathProgress)
        .animate(
          CurvedAnimation(
            parent: _smoothBreathController,
            curve: Curves.easeInOut,
          ),
        )
        .value;
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
    _smoothBreathController.dispose();
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
      body: GestureDetector(
        onPanUpdate: (details) {
          // Throttled parallax (2fps max)
          final size = MediaQuery.of(context).size;
          _updateParallax(
            (details.localPosition.dx / size.width).clamp(0.0, 1.0),
            (details.localPosition.dy / size.height).clamp(0.0, 1.0),
          );
        },
        onTapDown: (details) {
          // Tap updates parallax immediately
          final size = MediaQuery.of(context).size;
          _updateParallax(
            (details.localPosition.dx / size.width).clamp(0.0, 1.0),
            (details.localPosition.dy / size.height).clamp(0.0, 1.0),
          );
        },
        child: MouseRegion(
          onHover: (event) {
            _updateParallax(
              event.position.dx / MediaQuery.of(context).size.width,
              event.position.dy / MediaQuery.of(context).size.height,
            );
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
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                _isDarkMode
                    ? ZenTheme.voidBlack
                    : HSLColor.fromColor(
                        _primaryColor,
                      ).withLightness(0.95).toColor(),
                _isDarkMode
                    ? ZenTheme.deepSpace.withValues(alpha: 0.5)
                    : HSLColor.fromColor(
                        _primaryColor,
                      ).withLightness(0.98).toColor(),
              ],
            ),
          ),
        ),
        Starfield(
          mouseX: _mouseX,
          mouseY: _mouseY,
          primaryColor: _primaryColor,
          isDarkMode: _isDarkMode,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(flex: 1),
                // Fixed height container prevents layout jump
                SizedBox(height: 290, child: _buildOrbSection()),
                const Spacer(flex: 1),
                // Single horizontal card: timer left, buttons right
                _buildPortraitControls(),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                _isDarkMode
                    ? ZenTheme.voidBlack
                    : HSLColor.fromColor(
                        _primaryColor,
                      ).withLightness(0.95).toColor(),
                _isDarkMode
                    ? ZenTheme.deepSpace.withValues(alpha: 0.5)
                    : HSLColor.fromColor(
                        _primaryColor,
                      ).withLightness(0.98).toColor(),
              ],
            ),
          ),
        ),
        Starfield(
          mouseX: _mouseX,
          mouseY: _mouseY,
          primaryColor: _primaryColor,
          isDarkMode: _isDarkMode,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildOrbSection()),
                const SizedBox(width: 24),
                Expanded(child: Center(child: _buildControls())),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final textColor = _isDarkMode ? ZenTheme.starWhite : Colors.black87;
    final mutedColor = _isDarkMode ? ZenTheme.textMuted : Colors.black54;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _exit,
          icon: Icon(Icons.close, color: mutedColor),
        ),
        Expanded(
          child: Text(
            _isCountingDown ? '准备' : _phase,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
            ),
          ),
        ),
        Text(
          '${_settings.inhale}-${_settings.hold}-${_settings.exhale}',
          style: TextStyle(color: mutedColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOrbSection() {
    final orbSize = 220.0;
    final countdownFontSize = 48.0;
    final phaseLabel = _isCountingDown ? '准备' : _phase;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: orbSize,
          height: orbSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Always render orb (invisible during countdown)
              Opacity(
                opacity: _isCountingDown ? 0.0 : 1.0,
                child: BreathingOrb(
                  breatheProgress: _smoothedProgress,
                  phase: _phase,
                  isPaused: _isPaused,
                  onTap: _togglePause,
                ),
              ),
              // Countdown text or phase countdown
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isCountingDown
                    ? Text(
                        '$_countdown',
                        key: ValueKey('ready-$_countdown'),
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 100,
                          fontWeight: FontWeight.w100,
                        ),
                      )
                    : Text(
                        '$_phaseRemainingSeconds',
                        key: ValueKey('countdown-$_phaseRemainingSeconds'),
                        style: TextStyle(
                          color:
                              (_isDarkMode
                                      ? ZenTheme.starWhite
                                      : Colors.black87)
                                  .withValues(alpha: 0.9),
                          fontSize: countdownFontSize,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: _primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Phase indicator - always visible
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  phaseLabel,
                  key: ValueKey(phaseLabel),
                  style: TextStyle(
                    color: _isDarkMode ? ZenTheme.textHigh : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitControls() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1 - (_remainingSeconds / (widget.durationMinutes * 60));
    final cardColor = _isDarkMode
        ? ZenTheme.surface.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.98);
    final textColor = _isDarkMode ? ZenTheme.starWhite : Colors.black87;
    final shadowColor = Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.1);

    // Single card: timer + progress on left, buttons on right
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Timer (left) + Status (right), same size
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w100,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _isPaused ? '已暂停' : '冥想中',
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: Circle (left) + Buttons (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circle progress
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: _isDarkMode
                          ? ZenTheme.surfaceBright.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_primaryColor),
                    ),
                  ],
                ),
              ),
              // Buttons
              Row(
                children: [
                  _ControlButton(
                    label: _isPaused ? '继续' : '暂停',
                    icon: _isPaused ? Icons.play_arrow : Icons.pause,
                    onPressed: _togglePause,
                    primaryColor: _primaryColor,
                    isDarkMode: _isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _ControlButton(
                    label: '结束',
                    icon: Icons.stop,
                    isPrimary: false,
                    onPressed: _exit,
                    primaryColor: _primaryColor,
                    isDarkMode: _isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1 - (_remainingSeconds / (widget.durationMinutes * 60));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? ZenTheme.surface.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Timer (left) + Status (right), same size
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: _isDarkMode ? ZenTheme.starWhite : Colors.black87,
                  fontSize: 32,
                  fontWeight: FontWeight.w100,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _isPaused ? '已暂停' : '冥想中',
                style: TextStyle(
                  color: _isDarkMode ? ZenTheme.starWhite : Colors.black87,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: Circle (left) + Buttons (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circle progress
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: _isDarkMode
                          ? ZenTheme.surfaceBright.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_primaryColor),
                    ),
                  ],
                ),
              ),
              // Buttons
              Row(
                children: [
                  _ControlButton(
                    label: _isPaused ? '继续' : '暂停',
                    icon: _isPaused ? Icons.play_arrow : Icons.pause,
                    onPressed: _togglePause,
                    primaryColor: _primaryColor,
                    isDarkMode: _isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _ControlButton(
                    label: '结束',
                    icon: Icons.stop,
                    isPrimary: false,
                    onPressed: _exit,
                    primaryColor: _primaryColor,
                    isDarkMode: _isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onPressed;
  final Color primaryColor;
  final bool isDarkMode;

  const _ControlButton({
    required this.label,
    required this.icon,
    this.isPrimary = true,
    required this.onPressed,
    required this.primaryColor,
    required this.isDarkMode,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isPrimary
        ? null
        : (widget.isDarkMode ? ZenTheme.deepSpace : Colors.grey.shade200)
              .withValues(alpha: 0.5);
    final textColor = widget.isPrimary
        ? (widget.isDarkMode ? ZenTheme.voidBlack : Colors.white)
        : (widget.isDarkMode ? ZenTheme.starWhite : Colors.black87);
    final borderColor = widget.isPrimary
        ? widget.primaryColor
        : (widget.isDarkMode ? ZenTheme.textMuted : Colors.grey.shade400)
              .withValues(alpha: 0.3);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.isPrimary
              ? LinearGradient(
                  colors: [
                    widget.primaryColor,
                    ZenTheme.secondaryFor(widget.primaryColor),
                  ],
                )
              : null,
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
