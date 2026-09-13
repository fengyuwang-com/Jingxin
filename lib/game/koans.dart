library;

/// 禅语池：心镜碎片被吸入时浮现的一句引导词。
///
/// 刻意保持"心静自然凉"级别的短句——不是鸡汤口号，是熄灯后
/// 轻轻放下的一句。池内约 20 句，随机取用且近几次不重复。
import 'dart:math' as math;

class Koans {
  Koans._();

  static const List<String> _pool = [
    '心若不动，风又奈何。',
    '云在青天，水在瓶中。',
    '万古长空，一朝风月。',
    '竹影扫阶尘不动，月穿潭底水无痕。',
    '疾风过岗，伏草惟存。',
    '水急不流月，心闲不记年。',
    '心静则明，水止则清。',
    '一念放下，万般自在。',
    '夜深了，海也困了。',
    '呼吸之间，即是彼岸。',
    '月不逐云，云自过月。',
    '事来如潮起，事去如潮落。',
    '不用求真，唯须息见。',
    '尘埃落在星辰上，星辰依旧发光。',
    '你不必点亮整片海，一寸微光已足够。',
    '睡意来时，不必挽留清醒。',
    '潮水从不着急，也从未迟到。',
    '心似白云常自在，意如流水任东西。',
    '裂缝之处，恰有微光。',
    '今夜星沉海底，明日窗明几净。',
  ];

  static final List<int> _recent = [];

  /// 「焦虑之渊」专属偈语池（第 7 轮）：纷乱念头随呼吸归于一致的隐喻。
  static const List<String> _abyssPool = [
    '念头如乱星，闪烁不必追逐。',
    '数息之间，繁星渐次同明。',
    '渊底无声，心跳自有其灯。',
    '一呼一吸，万念归一。',
    '念头来了，让它像星一样自己暗下去。',
    '不必点亮深渊，陪你呼吸就好。',
    '花在无光处开，也在你呼气时开。',
    '乱，只是尚未被呼吸抚平的序。',
    '深渊不催促任何人，它只等你慢下来。',
    '心跳在渊底亮着，你也在。',
  ];

  static final List<int> _abyssRecent = [];

  /// 随机取一句，保证与最近取过的几句不重复。
  static String next() => _draw(_pool, _recent);

  /// 「焦虑之渊」碎片偈语。
  static String nextAbyss() => _draw(_abyssPool, _abyssRecent);

  static String _draw(List<String> pool, List<int> recent) {
    if (recent.length >= pool.length - 3) recent.clear();
    int i;
    do {
      i = math.Random().nextInt(pool.length);
    } while (recent.contains(i) && pool.length > recent.length);
    recent.add(i);
    if (recent.length > 4) recent.removeAt(0);
    return pool[i];
  }
}
