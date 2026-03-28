import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/meditation_provider.dart';
import '../ui/glass_panel.dart';
import '../ui/starfield.dart';
import 'meditation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _dragStartY = 0;
  int _dragStartDuration = 5;
  double _mouseX = 0.5;
  double _mouseY = 0.5;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
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

  void _startDrag(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragStartDuration = context.read<MeditationProvider>().durationMinutes;
  }

  void _onDrag(DragUpdateDetails details) {
    final delta = (_dragStartY - details.globalPosition.dy) / 5;
    context.read<MeditationProvider>().setDuration(
      _dragStartDuration + delta.round(),
    );
  }

  void _startMeditation() {
    final provider = context.read<MeditationProvider>();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MeditationScreen(
          durationMinutes: provider.durationMinutes,
          settings: provider.settings,
        ),
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
    final provider = context.watch<MeditationProvider>();
    final primaryColor = provider.seedColor;
    final isDarkMode = provider.isDarkMode;

    return Scaffold(
      drawer: _buildNavigationDrawer(primaryColor, isDarkMode),
      body: GestureDetector(
        onLongPress: () => Scaffold.of(context).openDrawer(),
        onPanUpdate: (details) {
          // Open drawer when swiping from left edge
          if (details.globalPosition.dx < 50 && details.delta.dx > 2) {
            Scaffold.of(context).openDrawer();
          }
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
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      isDarkMode
                          ? ZenTheme.voidBlack
                          : HSLColor.fromColor(
                              primaryColor,
                            ).withLightness(0.95).toColor(),
                      isDarkMode
                          ? ZenTheme.deepSpace.withValues(alpha: 0.5)
                          : HSLColor.fromColor(
                              primaryColor,
                            ).withLightness(0.98).toColor(),
                    ],
                  ),
                ),
              ),
              Starfield(
                mouseX: _mouseX,
                mouseY: _mouseY,
                primaryColor: primaryColor,
                isDarkMode: isDarkMode,
              ),
              SafeArea(
                child: isLandscape
                    ? _buildLandscapeLayout(primaryColor, isDarkMode)
                    : _buildPortraitLayout(primaryColor, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(Color primaryColor, bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? ZenTheme.surface : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '设置',
                    style: TextStyle(
                      color: isDarkMode ? ZenTheme.textHigh : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
              height: 1,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDarkModeToggle(isDarkMode, primaryColor),
                    const SizedBox(height: 24),
                    Text(
                      '主题颜色',
                      style: TextStyle(
                        color: isDarkMode ? ZenTheme.textMuted : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildColorSelector(primaryColor),
                    const SizedBox(height: 24),
                    Divider(
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: 0.06),
                      height: 1,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '自定义呼吸',
                      style: TextStyle(
                        color: isDarkMode ? ZenTheme.textMuted : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomBreathSliders(isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(bool isDarkMode, Color primaryColor) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isDarkMode ? '黑夜模式' : '白天模式',
              style: TextStyle(
                color: isDarkMode ? ZenTheme.textMuted : Colors.black87,
                fontSize: 14,
              ),
            ),
            Switch(
              value: isDarkMode,
              onChanged: (value) => provider.setDarkMode(value),
              activeColor: primaryColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorSelector(Color primaryColor) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ZenTheme.seedColors.map((color) {
            final isSelected =
                provider.seedColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => provider.setSeedColor(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCustomBreathSliders(bool isDarkMode) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        return Column(
          children: [
            _buildSlider(
              label: '吸气',
              value: settings.inhale.toDouble(),
              color: provider.seedColor,
              isDarkMode: isDarkMode,
              onChanged: (v) {
                provider.setCustomSettings(
                  settings.copyWith(inhale: v.round()),
                );
                provider.setPattern(BreathPattern.custom);
              },
            ),
            const SizedBox(height: 8),
            _buildSlider(
              label: '憋气',
              value: settings.hold.toDouble(),
              color: provider.seedColor,
              isDarkMode: isDarkMode,
              onChanged: (v) {
                provider.setCustomSettings(settings.copyWith(hold: v.round()));
                provider.setPattern(BreathPattern.custom);
              },
            ),
            const SizedBox(height: 8),
            _buildSlider(
              label: '呼气',
              value: settings.exhale.toDouble(),
              color: provider.seedColor,
              isDarkMode: isDarkMode,
              onChanged: (v) {
                provider.setCustomSettings(
                  settings.copyWith(exhale: v.round()),
                );
                provider.setPattern(BreathPattern.custom);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              color: isDarkMode
                  ? ZenTheme.textHigh.withValues(alpha: 0.8)
                  : Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: isDarkMode
                  ? Colors.white24
                  : Colors.grey.shade400,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(value: value, min: 1, max: 15, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${value.round()}s',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSlider(Color primaryColor, bool isDarkMode) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '冥想时长',
                  style: TextStyle(
                    color: isDarkMode ? ZenTheme.textMuted : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${provider.durationMinutes} 分钟',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: primaryColor,
                inactiveTrackColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.grey.shade300,
                thumbColor: primaryColor,
                overlayColor: primaryColor.withValues(alpha: 0.15),
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: provider.durationMinutes.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => provider.setDuration(v.round()),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRhythmChips(Color primaryColor, bool isDarkMode) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '呼吸节奏',
              style: TextStyle(
                color: isDarkMode ? ZenTheme.textMuted : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BreathPattern.values.map((pattern) {
                final isSelected = provider.pattern == pattern;
                String label;
                switch (pattern) {
                  case BreathPattern.fourSevenEight:
                    label = '4-7-8';
                  case BreathPattern.fiveFiveFive:
                    label = '5-5-5';
                  case BreathPattern.custom:
                    label = '自定义';
                }
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => provider.setPattern(pattern),
                  selectedColor: primaryColor.withValues(alpha: 0.25),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? primaryColor
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  backgroundColor: isDarkMode
                      ? ZenTheme.surfaceBright.withValues(alpha: 0.6)
                      : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.6)
                        : (isDarkMode
                              ? ZenTheme.textMuted.withValues(alpha: 0.2)
                              : Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartButton(Color primaryColor, bool isDarkMode) {
    final secondaryColor = ZenTheme.secondaryFor(primaryColor);

    return Center(
      child: GestureDetector(
        onTap: _startMeditation,
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.25),
                secondaryColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? ZenTheme.surface.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.95),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: primaryColor, size: 44),
                  const SizedBox(height: 4),
                  Text(
                    '开始',
                    style: TextStyle(
                      color: isDarkMode ? ZenTheme.textHigh : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
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

  Widget _buildPortraitLayout(Color primaryColor, bool isDarkMode) {
    final textColor = isDarkMode ? ZenTheme.starWhite : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: primaryColor),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Text(
                  '静心',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // MD3 Card for settings
          GlassPanel(
            isDarkMode: isDarkMode,
            opacity: isDarkMode ? 0.18 : 0.95,
            tint: isDarkMode ? ZenTheme.surfaceDim : Colors.grey.shade50,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDurationSlider(primaryColor, isDarkMode),
                const SizedBox(height: 16),
                Divider(
                  color: (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.06,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRhythmChips(primaryColor, isDarkMode),
              ],
            ),
          ),
          const Spacer(),
          _buildStartButton(primaryColor, isDarkMode),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(Color primaryColor, bool isDarkMode) {
    final textColor = isDarkMode ? ZenTheme.starWhite : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: primaryColor),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '静心',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  isDarkMode: isDarkMode,
                  opacity: isDarkMode ? 0.18 : 0.95,
                  tint: isDarkMode ? ZenTheme.surfaceDim : Colors.grey.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDurationSlider(primaryColor, isDarkMode),
                      const SizedBox(height: 12),
                      Divider(
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                      const SizedBox(height: 12),
                      _buildRhythmChips(primaryColor, isDarkMode),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: _buildStartButton(primaryColor, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(Color primaryColor, bool isDarkMode) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onVerticalDragStart: _startDrag,
          onVerticalDragUpdate: _onDrag,
          child: GlassPanel(
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                const Text(
                  '滑动调节时长',
                  style: TextStyle(color: ZenTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Text(
                  '${provider.durationMinutes}',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 72,
                    fontWeight: FontWeight.w100,
                  ),
                ),
                const Text(
                  '分钟',
                  style: TextStyle(color: ZenTheme.textMuted, fontSize: 16),
                ),
                const SizedBox(height: 20),
                _buildQuickDurations(provider, primaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickDurations(MeditationProvider provider, Color primaryColor) {
    final quickDurations = [3, 5, 10, 15];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: quickDurations.map((d) {
        final isSelected = provider.durationMinutes == d;
        return GestureDetector(
          onTap: () => provider.setDuration(d),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : ZenTheme.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$d',
              style: TextStyle(
                color: isSelected ? primaryColor : ZenTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRhythmSelector(Color primaryColor, bool isDarkMode) {
    return Consumer<MeditationProvider>(
      builder: (context, provider, _) {
        final secondaryColor = ZenTheme.secondaryFor(primaryColor);
        return GlassPanel(
          isDarkMode: isDarkMode,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text(
                '节奏:',
                style: TextStyle(color: ZenTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(width: 16),
              ...BreathPattern.values.map((pattern) {
                final isSelected = provider.pattern == pattern;
                String label;
                switch (pattern) {
                  case BreathPattern.fourSevenEight:
                    label = '4-7-8';
                  case BreathPattern.fiveFiveFive:
                    label = '5-5-5';
                  case BreathPattern.custom:
                    label = '自定义';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => provider.setPattern(pattern),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? secondaryColor.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? secondaryColor
                              : ZenTheme.textMuted.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? secondaryColor
                              : ZenTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStart(Color primaryColor, bool isDarkMode) {
    final secondaryColor = ZenTheme.secondaryFor(primaryColor);
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
                primaryColor.withValues(alpha: 0.3),
                secondaryColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDarkMode ? ZenTheme.deepSpace : Colors.white)
                    .withValues(alpha: 0.8),
                border: Border.all(color: primaryColor, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: primaryColor, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '开始',
                    style: TextStyle(
                      color: isDarkMode ? ZenTheme.starWhite : Colors.black87,
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
