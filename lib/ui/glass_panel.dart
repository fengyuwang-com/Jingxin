import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double opacity;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final bool isDarkMode;
  final Color? tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.padding,
    this.borderRadius,
    this.isDarkMode = true,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? ZenTheme.surface : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (tint ?? surfaceColor).withValues(alpha: opacity),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: (tint ?? ZenTheme.nebulaCyan).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ZenButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const ZenButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
  });

  @override
  State<ZenButton> createState() => _ZenButtonState();
}

class _ZenButtonState extends State<ZenButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: widget.isPrimary
                    ? const LinearGradient(
                        colors: [ZenTheme.nebulaCyan, ZenTheme.nebulaPurple],
                      )
                    : null,
                color: widget.isPrimary
                    ? null
                    : ZenTheme.deepSpace.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: widget.isPrimary
                      ? ZenTheme.nebulaCyan
                      : ZenTheme.starWhite.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: widget.isPrimary
                    ? [
                        BoxShadow(
                          color: ZenTheme.nebulaCyan.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: widget.isPrimary
                          ? ZenTheme.voidBlack
                          : ZenTheme.starWhite,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isPrimary
                          ? ZenTheme.voidBlack
                          : ZenTheme.starWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
