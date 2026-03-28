import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BreathingCircle extends StatefulWidget {
  final int breatheInSeconds;
  final int holdSeconds;
  final int breatheOutSeconds;
  final String instruction;

  const BreathingCircle({
    super.key,
    this.breatheInSeconds = 4,
    this.holdSeconds = 7,
    this.breatheOutSeconds = 8,
    required this.instruction,
  });

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  String _currentPhase = '吸气';
  int _secondsRemaining = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        seconds:
            widget.breatheInSeconds +
            widget.holdSeconds +
            widget.breatheOutSeconds,
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.6,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: widget.breatheInSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: widget.holdSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: widget.breatheOutSeconds.toDouble(),
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 0.8),
        weight: widget.breatheInSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 0.8),
        weight: widget.holdSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 0.4),
        weight: widget.breatheOutSeconds.toDouble(),
      ),
    ]).animate(_controller);

    _controller.addListener(_updatePhase);
    _controller.repeat();
  }

  void _updatePhase() {
    final progress = _controller.value;
    final totalCycle =
        widget.breatheInSeconds + widget.holdSeconds + widget.breatheOutSeconds;

    final inhaleEnd = widget.breatheInSeconds / totalCycle;
    final holdEnd = (widget.breatheInSeconds + widget.holdSeconds) / totalCycle;

    String newPhase;
    int secondsLeft;

    if (progress < inhaleEnd) {
      newPhase = '吸气';
      secondsLeft = ((1 - (progress / inhaleEnd)) * widget.breatheInSeconds)
          .ceil();
    } else if (progress < holdEnd) {
      newPhase = '屏息';
      secondsLeft =
          ((1 - ((progress - inhaleEnd) / (holdEnd - inhaleEnd))) *
                  widget.holdSeconds)
              .ceil();
    } else {
      newPhase = '呼气';
      secondsLeft =
          ((1 - ((progress - holdEnd) / (1 - holdEnd))) *
                  widget.breatheOutSeconds)
              .ceil();
    }

    if (newPhase != _currentPhase || secondsLeft != _secondsRemaining) {
      setState(() {
        _currentPhase = newPhase;
        _secondsRemaining = secondsLeft;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.7;
    final innerSize = circleSize * 0.72;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: _opacityAnimation.value),
                    AppColors.accent.withValues(
                      alpha: _opacityAnimation.value * 0.3,
                    ),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: _opacityAnimation.value * 0.5,
                    ),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _currentPhase,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '$_secondsRemaining',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 48,
            fontWeight: FontWeight.w200,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            widget.instruction,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
