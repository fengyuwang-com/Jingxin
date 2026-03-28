import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation_session.dart';

class MeditationProvider extends ChangeNotifier {
  int _selectedDuration = 10;
  MeditationMode _selectedMode = MeditationMode.breathing;
  List<MeditationSession> _sessions = [];
  bool _isLoading = true;

  int get selectedDuration => _selectedDuration;
  MeditationMode get selectedMode => _selectedMode;
  List<MeditationSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  int get totalMinutes =>
      _sessions.fold(0, (sum, s) => sum + (s.durationSeconds ~/ 60));

  int get streakDays {
    if (_sessions.isEmpty) return 0;
    final sortedSessions = List<MeditationSession>.from(_sessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    int streak = 0;
    DateTime? lastDate;

    for (final session in sortedSessions) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (lastDate == null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        if (sessionDate == todayDate ||
            sessionDate == todayDate.subtract(const Duration(days: 1))) {
          streak = 1;
          lastDate = sessionDate;
        } else {
          break;
        }
      } else {
        if (lastDate.difference(sessionDate).inDays == 1) {
          streak++;
          lastDate = sessionDate;
        } else if (lastDate != sessionDate) {
          break;
        }
      }
    }
    return streak;
  }

  void setDuration(int minutes) {
    _selectedDuration = minutes;
    notifyListeners();
  }

  void setMode(MeditationMode mode) {
    _selectedMode = mode;
    notifyListeners();
  }

  Future<void> addSession(MeditationSession session) async {
    _sessions.add(session);
    await _saveSessions();
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString('meditation_sessions');
      if (sessionsJson != null) {
        final List<dynamic> decoded = json.decode(sessionsJson);
        _sessions = decoded
            .map((e) => MeditationSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = json.encode(
        _sessions.map((s) => s.toJson()).toList(),
      );
      await prefs.setString('meditation_sessions', sessionsJson);
    } catch (e) {
      debugPrint('Error saving sessions: $e');
    }
  }
}
