import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../ui/glass_panel.dart';
import '../ui/starfield.dart';
import 'meditation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _durationMinutes = 5;
  double _dragStartY = 0;
  int _dragStartDuration = 5;
  double _mouseX = 0.5;
  double _mouseY = 0.5;

  void _startDrag(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragStartDuration = _durationMinutes;
  }

  void _onDrag(DragUpdateDetails details) {
    final delta = (_dragStartY - details.globalPosition.dy) / 5;
    setState(() {
      _durationMinutes = (_dragStartDuration + delta.round()).clamp(1, 60);
    });
  }

  void _startMeditation() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            MeditationScreen(durationMinutes: _durationMinutes),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mouseX = event.position.dx / MediaQuery.of(context).size.width;
            _mouseY = event.position.dy / MediaQuery.of(context).size.height;
          });
        },
        child: Stack(
          children: [
            Starfield(mouseX: _mouseX, mouseY: _mouseY),
            SafeArea(
              child: isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            '静心',
            style: TextStyle(
              color: ZenTheme.starWhite,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CYBER-ZEN',
            style: TextStyle(
              color: ZenTheme.nebulaCyan,
              fontSize: 12,
              letterSpacing: 8,
            ),
          ),
          const Spacer(),
          _buildDurationSelector(),
          const Spacer(),
          _buildQuickStart(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  '静心',
                  style: TextStyle(
                    color: ZenTheme.starWhite,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'CYBER-ZEN',
                  style: TextStyle(
                    color: ZenTheme.nebulaCyan,
                    fontSize: 14,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 40),
                _buildDurationSelector(),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(child: _buildQuickStart()),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return GestureDetector(
      onVerticalDragStart: _startDrag,
      onVerticalDragUpdate: _onDrag,
      child: GlassPanel(
        child: Column(
          children: [
            const Text(
              '滑动调节时长',
              style: TextStyle(color: ZenTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              '$_durationMinutes',
              style: const TextStyle(
                color: ZenTheme.nebulaCyan,
                fontSize: 72,
                fontWeight: FontWeight.w100,
              ),
            ),
            const Text(
              '分钟',
              style: TextStyle(color: ZenTheme.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildQuickDurations(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDurations() {
    final quickDurations = [3, 5, 10, 15];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: quickDurations.map((d) {
        final isSelected = _durationMinutes == d;
        return GestureDetector(
          onTap: () => setState(() => _durationMinutes = d),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? ZenTheme.nebulaCyan.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? ZenTheme.nebulaCyan
                    : ZenTheme.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$d',
              style: TextStyle(
                color: isSelected ? ZenTheme.nebulaCyan : ZenTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickStart() {
    return Center(
      child: GestureDetector(
        onTap: _startMeditation,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ZenTheme.nebulaCyan.withValues(alpha: 0.3),
                ZenTheme.nebulaPurple.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: ZenTheme.nebulaCyan.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZenTheme.deepSpace.withValues(alpha: 0.8),
                border: Border.all(color: ZenTheme.nebulaCyan, width: 1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: ZenTheme.nebulaCyan,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '开始',
                    style: TextStyle(
                      color: ZenTheme.starWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
