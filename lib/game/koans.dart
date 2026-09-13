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

  /// 「疲惫荒原」专属偈语池（第 9 轮）：休息、允许、不勉强——
  /// 灯台重燃与旷野余烬的隐喻，克制不鸡汤。
  static const List<String> _heathPool = [
    '火不必一直烧着，烬也是它的一部分。',
    '累的时候，允许自己只是一粒尘埃。',
    '荒原不要求抵达，走路本身就是休息。',
    '灯熄了，不是结束，是在攒下一次的光。',
    '不必勉强发光，暗也有暗的安稳。',
    '风从旷野上过，没有带走谁。',
    '停下来，是呼吸给你的一种允许。',
    '灰烬记得火，你也记得怎么呼吸。',
  ];

  static final List<int> _heathRecent = [];

  /// 「纷心雾林」专属偈语池（第 13 轮）：让思绪落地的意象——
  /// 雾是纷乱的心事，随呼吸沉降。克制、勿鸡汤。
  static const List<String> _mistPool = [
    '雾不是墙，是还没落下的心事。',
    '呼气的时候，雾也矮了一寸。',
    '念头落了地，就成了萤火。',
    '林中无路，呼吸自会分开雾。',
    '看得不清，就先不必看清。',
    '雾散不是赶走，是请它坐下。',
    '枝头一盏灯，照的不是路，是停。',
    '心事沉下去的地方，会微微发亮。',
  ];

  static final List<int> _mistRecent = [];

  /// 「惘语」（第 17 轮）：星兽惘赠出的金色心镜碎片专属——
  /// 主题：被看见、不孤单。克制、留白，勿鸡汤。
  static const List<String> _wangPool = [
    '雾里那位，也一直看见你。',
    '被看见的那一刻，夜就不只属于你一个人。',
    '你在夜里醒着，也有谁陪你醒着。',
  ];

  static final List<int> _wangRecent = [];

  /// 「入睡引导」极短句池（第 12 轮「闻声」）：长夜里极低频率轻声读出。
  /// 主题是睡眠接近感——描述性的、留白的，勿鸡汤勿命令式。
  static const List<String> _whisperPool = [
    '眼皮沉了。',
    '世界收灯了。',
    '不必想，只需要在。',
    '海把今天轻轻收起来了。',
    '呼吸慢下来，夜就更深一点。',
    '没有什么需要你现在做完。',
    '星星一颗一颗熄了，留给你的刚刚好。',
    '潮水退到很远的地方去了。',
    '你不用守着什么，夜替你守着。',
    '困意是来接你的，不着急。',
  ];

  static final List<int> _whisperRecent = [];

  /// 入睡引导极短句（长夜朗读用，与碎片禅语互不干扰）。
  static String nextWhisper() => _draw(_whisperPool, _whisperRecent);

  /// 随机取一句，保证与最近取过的几句不重复。
  static String next() => _draw(_pool, _recent);

  /// 「焦虑之渊」碎片偈语。
  static String nextAbyss() => _draw(_abyssPool, _abyssRecent);

  /// 「疲惫荒原」碎片偈语。
  static String nextHeath() => _draw(_heathPool, _heathRecent);

  /// 「纷心雾林」碎片偈语。
  static String nextMist() => _draw(_mistPool, _mistRecent);

  /// 「惘语」：星兽惘的金色碎片偈语。
  static String nextWang() => _draw(_wangPool, _wangRecent);

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
