import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

enum BreathPattern { fourSevenEight, fiveFiveFive, custom }

class BreathSettings {
  final int inhale;
  final int hold;
  final int exhale;

  const BreathSettings(this.inhale, this.hold, this.exhale);

  int get totalCycle => inhale + hold + exhale;

  static const fourSevenEight = BreathSettings(4, 7, 8);
  static const fiveFiveFive = BreathSettings(5, 5, 5);

  BreathSettings copyWith({int? inhale, int? hold, int? exhale}) {
    return BreathSettings(
      inhale ?? this.inhale,
      hold ?? this.hold,
      exhale ?? this.exhale,
    );
  }

  Map<String, dynamic> toJson() => {
    'inhale': inhale,
    'hold': hold,
    'exhale': exhale,
  };

  factory BreathSettings.fromJson(Map<String, dynamic> json) => BreathSettings(
    json['inhale'] as int,
    json['hold'] as int,
    json['exhale'] as int,
  );
}

class MeditationProvider extends ChangeNotifier {
  int _durationMinutes = 5;
  BreathPattern _pattern = BreathPattern.fourSevenEight;
  BreathSettings _customSettings = BreathSettings.fourSevenEight;
  Color _seedColor = ZenTheme.nebulaCyan;
  bool _isDarkMode = true;
  bool _isLoading = true;

  int get durationMinutes => _durationMinutes;
  BreathPattern get pattern => _pattern;
  Color get seedColor => _seedColor;
  bool get isDarkMode => _isDarkMode;
  ThemeData get theme => ZenTheme.getTheme(_seedColor, _isDarkMode);
  BreathSettings get settings => _pattern == BreathPattern.custom
      ? _customSettings
      : (_pattern == BreathPattern.fourSevenEight
            ? BreathSettings.fourSevenEight
            : BreathSettings.fiveFiveFive);

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _durationMinutes = prefs.getInt('duration_minutes') ?? 5;
      final patternIndex = prefs.getInt('pattern') ?? 0;
      _pattern = BreathPattern.values[patternIndex];
      final customJson = prefs.getString('custom_settings');
      if (customJson != null) {
        _customSettings = BreathSettings.fromJson(json.decode(customJson));
      }
      final seedColorValue = prefs.getInt('seed_color');
      if (seedColorValue != null) {
        _seedColor = Color(seedColorValue);
      }
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setDuration(int minutes) async {
    _durationMinutes = minutes.clamp(1, 60);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duration_minutes', _durationMinutes);
  }

  Future<void> setPattern(BreathPattern pattern) async {
    _pattern = pattern;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pattern', pattern.index);
  }

  Future<void> setCustomSettings(BreathSettings settings) async {
    _customSettings = settings;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_settings', json.encode(settings.toJson()));
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color.toARGB32());
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
  }
}
