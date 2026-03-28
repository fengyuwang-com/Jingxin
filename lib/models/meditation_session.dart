enum MeditationMode { breathing, mindfulness, guided, relaxation }

extension MeditationModeExtension on MeditationMode {
  String get displayName {
    switch (this) {
      case MeditationMode.breathing:
        return '呼吸冥想';
      case MeditationMode.mindfulness:
        return '正念冥想';
      case MeditationMode.guided:
        return '引导冥想';
      case MeditationMode.relaxation:
        return '放松冥想';
    }
  }

  String get description {
    switch (this) {
      case MeditationMode.breathing:
        return '跟随呼吸节奏，放松身心';
      case MeditationMode.mindfulness:
        return '扫描身体，感受当下';
      case MeditationMode.guided:
        return '导师引导，深度放松';
      case MeditationMode.relaxation:
        return '可视化场景，宁静致远';
    }
  }

  String get icon {
    switch (this) {
      case MeditationMode.breathing:
        return '🌬️';
      case MeditationMode.mindfulness:
        return '🧘';
      case MeditationMode.guided:
        return '🎯';
      case MeditationMode.relaxation:
        return '🌊';
    }
  }
}

class MeditationSession {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final MeditationMode mode;
  final bool completed;

  MeditationSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.mode,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'durationSeconds': durationSeconds,
    'mode': mode.index,
    'completed': completed,
  };

  factory MeditationSession.fromJson(Map<String, dynamic> json) =>
      MeditationSession(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        durationSeconds: json['durationSeconds'] as int,
        mode: MeditationMode.values[json['mode'] as int],
        completed: json['completed'] as bool,
      );
}
