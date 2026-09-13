import 'package:flame/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jingjing_game.dart';
import 'koans.dart';

/// 「久别重逢」（第 42 轮）：几天没来，世界不怪你——
/// 它像老朋友一样醒来，把攒下的星光先亮给你看。
///
/// 触发：距上次进入静境 ≥72 小时，且本次不是首次（无记录=新朋友，
/// 归开场引导招呼，不抢戏）。演出约 10 秒：星兽「眠」缓缓睁眼望向
/// 你（复用 wakeOverride 的 4s/只既有渐变），世界苏醒度在演出期间
/// **仅视觉**提前 10%（不改持久化数值——苏醒度是"呼吸攒出来的旅程
/// 值"，一次性 +0.05 的永久奖励会让它变成可交易的货币；回礼是情感，
/// 不是数值），随后一句久别偈淡入、10 秒后淡出，眼睛按同一渐变
/// 缓缓合回，世界回到本来的样子。
///
/// 互斥（后到者让先的既有约定）：判定发生在进入静境初期，若开场
/// 引导在场（首次进入优先引导）、满醒终幕 / 晨光告别 / 相会演出
/// 进行中，本次静境不再触发（本轮机会让过，不做排队）。
///
/// 存储：`jingxin.lastvisit.v1`（yyyyMMddHHmm 本地时刻字符串，每次
/// 进入静境更新）。判定是纯函数（[LongAbsenceJudgement]），可测。
class LongAbsenceJudgement {
  LongAbsenceJudgement._();

  /// 视为"久别"的最短间隔。
  static const Duration threshold = Duration(hours: 72);

  /// 解析 yyyyMMddHHmm 时刻串；任何不合规（长度/数字/真实日期）
  /// 一律返回 null——损坏的数据等同一个从没来过的新朋友，宁可
  /// 演出不响，也不在错误时刻打扰。
  static DateTime? parseStamp(String? raw) {
    if (raw == null) return null;
    if (raw.length != 12) return null;
    for (final c in raw.codeUnits) {
      if (c < 0x30 || c > 0x39) return null;
    }
    final y = int.parse(raw.substring(0, 4));
    final m = int.parse(raw.substring(4, 6));
    final d = int.parse(raw.substring(6, 8));
    final h = int.parse(raw.substring(8, 10));
    final min = int.parse(raw.substring(10, 12));
    final dt = DateTime(y, m, d, h, min);
    // 溢出回卷（如 13 月、32 日、61 分）说明不是真实日期。
    if (dt.year != y || dt.month != m || dt.day != d || dt.hour != h ||
        dt.minute != min) {
      return null;
    }
    return dt;
  }

  /// 时刻 -> yyyyMMddHHmm（本地时刻，与世界其它持久化口径一致）。
  static String formatStamp(DateTime t) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}'
        '${p2(t.month)}${p2(t.day)}${p2(t.hour)}${p2(t.minute)}';
  }

  /// 纯函数判定。
  /// [lastStamp] 上次进入的时刻串；[now] 当前时刻。
  /// [verdict]：triggered=是否演出；days=完整天数（文案用，未触发为 0）。
  static LongAbsenceVerdict evaluate({String? lastStamp, required DateTime now}) {
    final last = parseStamp(lastStamp);
    if (last == null) {
      return const LongAbsenceVerdict(triggered: false, days: 0);
    }
    final gap = now.difference(last);
    if (gap < threshold) {
      return const LongAbsenceVerdict(triggered: false, days: 0);
    }
    return LongAbsenceVerdict(triggered: true, days: gap.inHours ~/ 24);
  }
}

/// 判定结论（值对象，纯数据）。
class LongAbsenceVerdict {
  const LongAbsenceVerdict({required this.triggered, required this.days});

  /// 是否触发「久别重逢」演出。
  final bool triggered;

  /// 离别完整天数（≥3；文案「第 N 次呼吸」级别的旁证，不用也可）。
  final int days;
}

/// 久别记忆：`jingxin.lastvisit.v1` 的读写。
/// 每次进入静境调用 [markVisitNow] 更新；[load] 返回**上一次**的
/// 时刻串（本次写回之前读到的才算"上次"）。
class LongAbsenceMemory {
  LongAbsenceMemory();

  static const String prefKey = 'jingxin.lastvisit.v1';

  /// 上一次进入的时刻串（未 load 过 / 从未来过 = null）。
  String? lastStamp;

  bool _loaded = false;

  /// 读出上一次进入时刻（幂等；读失败视作从未记录，不抛出）。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      lastStamp = prefs.getString(prefKey);
    } catch (_) {
      lastStamp = null;
    }
  }

  /// 把本次进入写回（每次都写，供下一次判定）。
  Future<void> markVisitNow(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, LongAbsenceJudgement.formatStamp(now));
    } catch (_) {}
  }
}

/// 「久别重逢」演出组件：进入静境初期做一次判定，命中则驱动
/// 星兽睁眼 + 世界视觉提亮 + 久别偈浮现（经 notifier 交给 UI 层）。
class LongAbsenceEvent extends Component with HasGameReference<JingjingGame> {
  LongAbsenceEvent();

  // ---- 演出时间轴（秒）----
  /// 进入后先让开场苏醒（3.5s）起个头，再判定。
  static const double graceSeconds = 2.5;

  /// 偈语浮现时刻（眼睛正在缓缓睁开）。
  static const double koanAt = 1.0;

  /// 演出总时长（偈语淡入 + 停留 ≈10s）。
  static const double totalSeconds = 10.0;

  /// 演出期间世界苏醒度的临时视觉回礼（0..1 绝对值加成）。
  static const double awakeningGift = 0.10;

  bool _armed = false;
  double _t = 0;

  /// 演出是否进行中——拾忆/晨光告别等互斥判定可读。
  bool get active => _armed;

  @override
  void update(double dt) {
    if (!_armed) {
      _tryTrigger(dt);
      return;
    }
    _t += dt;
    // 演出收束：眼睛交给既有 4s/只渐变缓缓合回，偈语随 notifier
    // 置 null 由 UI 淡出，世界回到本来的苏醒度。
    if (_t >= totalSeconds) {
      game.beast.wakeOverride = 0;
      game.longAbsenceKoan.value = null;
      game.longAbsenceActive = false;
      _armed = false;
    }
  }

  void _tryTrigger(double dt) {
    _t += dt;
    if (_t < graceSeconds) return;

    // 判定只做一次：无论结果如何，本轮静境不再评估。
    _t = 0;
    final verdict = LongAbsenceJudgement.evaluate(
      lastStamp: game.longAbsence.lastStamp,
      now: DateTime.now(),
    );
    if (!verdict.triggered) return;

    // 互斥（后到者让先）：开场引导在场（首次进入优先引导）、
    // 满醒终幕 / 晨光告别 / 相会演出进行中——本轮机会让过。
    if (game.onboarding != null ||
        game.fullAwake.active ||
        game.farewellPlaying ||
        game.reunion.active) {
      return;
    }

    _armed = true;
    game.longAbsenceActive = true;
    game.beast.wakeOverride = 1; // 缓缓睁眼望向你（4s/只渐变）。
    Future.delayed(
      Duration(milliseconds: (koanAt * 1000).round()),
      () {
        if (_armed && game.longAbsenceKoan.value == null) {
          game.longAbsenceKoan.value = Koans.nextLongAbsence();
        }
      },
    );
  }
}
