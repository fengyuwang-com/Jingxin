import 'package:flutter/material.dart';

class ZenTheme {
  static const Color voidBlack = Color(0xFF0a0a0f);
  static const Color deepSpace = Color(0xFF12121a);
  static const Color nebulaCyan = Color(0xFF00f5ff);
  static const Color nebulaPurple = Color(0xFF8b5cf6);
  static const Color starWhite = Color(0xFFf0f0ff);
  static const Color textMuted = Color(0xFF6b7280);

  static const Color neonGlow = Color(0xFF00d4ff);
  static const Color singularity = Color(0xFFff00ff);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: voidBlack,
    primaryColor: nebulaCyan,
    colorScheme: const ColorScheme.dark(
      primary: nebulaCyan,
      secondary: nebulaPurple,
      surface: deepSpace,
    ),
    fontFamily: 'SF Pro Display',
  );
}

class ZenSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
