import 'package:flutter/material.dart';

class ZenTheme {
  static const Color voidBlack = Color(0xFF0a0a0f);
  static const Color deepSpace = Color(0xFF12121a);
  static const Color surfaceDim = Color(0xFF1a1a24);
  static const Color surface = Color(0xFF22222e);
  static const Color surfaceBright = Color(0xFF2a2a38);

  static const Color nebulaCyan = Color(0xFF67e8f9);
  static const Color nebulaPurple = Color(0xFFa78bfa);
  static const Color starWhite = Color(0xFFf0f0ff);
  static const Color textMuted = Color(0xFF9ca3af);
  static const Color textHigh = Color(0xFFf3f4f6);

  static const Color neonGlow = Color(0xFF00d4ff);
  static const Color singularity = Color(0xFFff00ff);

  // Softer seed colors for better readability
  static const List<Color> seedColors = [
    Color(0xFF67e8f9),
    Color(0xFFa78bfa),
    Color(0xFF34d399),
    Color(0xFFfbbf24),
    Color(0xFFf87171),
    Color(0xFFf472b6),
    Color(0xFF60a5fa),
    Color(0xFF2dd4bf),
  ];

  // Soften a color by reducing saturation and adjusting lightness
  static Color soften(Color color, {double saturationFactor = 0.6}) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(hsl.saturation * saturationFactor).toColor();
  }

  // Get primary color with proper contrast
  static Color primaryMuted(Color seedColor, [bool isDarkMode = true]) {
    return soften(seedColor);
  }

  static ThemeData getTheme(Color seedColor, [bool isDarkMode = true]) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final softenedSeed = soften(seedColor);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: softenedSeed,
          brightness: brightness,
        ).copyWith(
          // Override with softer tones for better readability
          primary: softenedSeed,
          onPrimary: isDarkMode ? Colors.white : Colors.white,
          primaryContainer: softenedSeed.withValues(alpha: 0.15),
          onPrimaryContainer: softenedSeed,
          secondary: secondaryFor(seedColor),
          secondaryContainer: secondaryFor(seedColor).withValues(alpha: 0.15),
          surface: isDarkMode ? surface : Colors.white,
          onSurface: isDarkMode ? textHigh : Colors.black87,
          surfaceContainerHighest: isDarkMode
              ? surfaceBright
              : Colors.grey.shade100,
          onSurfaceVariant: isDarkMode ? textMuted : Colors.black54,
        );

    final bgColor = isDarkMode ? voidBlack : const Color(0xFFF5F5F5);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      primaryColor: softenedSeed,
      colorScheme: colorScheme,
      fontFamily: 'SF Pro Display',
      sliderTheme: SliderThemeData(
        activeTrackColor: softenedSeed,
        inactiveTrackColor: softenedSeed.withValues(alpha: 0.2),
        thumbColor: softenedSeed,
        overlayColor: softenedSeed.withValues(alpha: 0.1),
        trackHeight: 4,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: (isDarkMode ? surfaceDim : Colors.white).withValues(
          alpha: 0.98,
        ),
        indicatorColor: softenedSeed.withValues(alpha: 0.15),
      ),
    );
  }

  static ThemeData get darkTheme => getTheme(nebulaCyan, true);

  static Color backgroundColor(bool isDarkMode, Color seedColor) {
    return isDarkMode ? voidBlack : const Color(0xFFF5F5F5);
  }

  static Color surfaceColor(bool isDarkMode) {
    return isDarkMode ? surface : Colors.white;
  }

  static Color primaryFor(Color seedColor) => soften(seedColor);
  static Color secondaryFor(Color seedColor) {
    final hsl = HSLColor.fromColor(seedColor);
    return soften(hsl.withHue((hsl.hue + 60) % 360).toColor());
  }
}

class ZenSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
