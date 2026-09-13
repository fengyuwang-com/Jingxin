import 'package:shared_preferences/shared_preferences.dart';

/// 长夜记忆：是否进入过长夜（供后续"睡前章节"统计，本轮只存不用）。
class LongNightMemory {
  LongNightMemory();

  static const String _visitedKey = 'jingxin.longnight.visited.v1';
  static const String _firstKey = 'jingxin.longnight.first.v1';

  bool _visited = false;
  bool _loaded = false;

  bool get visited => _visited;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _visited = prefs.getBool(_visitedKey) ?? false;
    } catch (_) {
      _visited = false;
    }
  }

  /// 记下"曾进入过长夜"。幂等：首次才写时间戳。
  Future<void> markVisited() async {
    if (_visited) return;
    _visited = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_visitedKey, true);
      await prefs.setString(
        _firstKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }
}
