import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';

/// 星兽「眠」——失眠之海深处的长线存在（第 5 轮）。
///
/// 一头由星座连线构成的巨大而温柔的星兽，平时只在星空里隐约可辨。
/// 它的苏醒独立累计、跨会话持久化：平稳呼吸循环（+微少量）、
/// 在它附近的循环（+更多）、采集心镜碎片（+一点）。
/// 每过一档它缓缓睁开一只眼（共 5 只，每只约 4 秒渐变）；
/// 全睁后绕海缓游一阵，然后再次沉睡归零——循环而非终局。
/// 无进度条、无"还差多少"，只有星图回看页一行极淡的措辞变化。
class StarBeastState {
  StarBeastState();

  static const String _prefKey = 'jingxin.starbeast.v1';

  /// 眼睛总数（档位数）。
  static const int eyeCount = 5;

  /// 每只眼对应的累计阈值间隔（value 达到 (i+1)*tierSpan 睁开第 i 只）。
  static const double tierSpan = 0.2;

  /// 一次平稳呼吸循环的提升量（远处）。
  static const double cycleGain = 0.004;

  /// 在星兽附近完成循环的提升量（明显更多，但仍极缓）。
  static const double nearCycleGain = 0.012;

  /// 采集一片心镜碎片的提升量。
  static const double shardGain = 0.02;

  /// 全睁后游弋时长（秒）。
  static const int swimSeconds = 150;

  double _value = 0;
  int _swimUntil = 0; // epoch 毫秒
  bool _loaded = false;
  bool _dirty = false;
  double _sinceSave = 0;

  double get value => _value;

  /// 是否处于全睁后的游弋阶段（跨会话用时间戳持久化）。
  bool get swimming => DateTime.now().millisecondsSinceEpoch < _swimUntil;

  /// 游弋截止时间的原始值（第 15 轮「拾忆」导出用）。
  int get swimUntilEpoch => _swimUntil;

  /// 当前已睁开的眼睛数（游弋期视为全睁）。
  int get openedEyes =>
      swimming ? eyeCount : math.min(eyeCount, (_value / tierSpan).floor());

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _value = (prefs.getDouble('$_prefKey.value') ?? 0).clamp(0.0, 1.0);
      _swimUntil = prefs.getInt('$_prefKey.swimUntil') ?? 0;
    } catch (_) {
      _value = 0;
      _swimUntil = 0;
    }
  }

  /// 每帧推进。呼吸循环与碎片事件由游戏循环转发。
  void update(double dt, {required bool cycle, required bool near}) {
    if (swimming) return; // 游弋期不再累积，等待自然沉睡。
    if (cycle) {
      _value = (_value + (near ? nearCycleGain : cycleGain)).clamp(0.0, 1.0);
      _dirty = true;
      if (_value >= 1.0) {
        _swimUntil =
            DateTime.now().millisecondsSinceEpoch + swimSeconds * 1000;
        _value = 0;
        _dirty = true;
        save();
        return;
      }
    }
    _sinceSave += dt;
    if (_sinceSave > 5 && _dirty) {
      _dirty = false;
      _sinceSave = 0;
      save();
    }
  }

  /// 采集一片心镜碎片。
  void onShard() {
    if (swimming) return;
    _value = (_value + shardGain).clamp(0.0, 1.0);
    _dirty = true;
    if (_value >= 1.0) {
      _swimUntil = DateTime.now().millisecondsSinceEpoch + swimSeconds * 1000;
      _value = 0;
      save();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefKey.value', _value);
      await prefs.setInt('$_prefKey.swimUntil', _swimUntil);
    } catch (_) {
      // 持久化失败静默忽略。
    }
  }

  /// 星图回看页的极淡状态一行（不显示任何数字/进度）。
  static String whisper(int opened, {required bool isSwimming}) {
    if (isSwimming) return '它醒着，正绕着海缓缓游弋，星屑随行。';
    switch (opened) {
      case 0:
        return '海深处，似乎有什么在沉睡……';
      case 1:
        return '海深处，有什么正慢慢醒来……';
      case 2:
        return '深处的那位，似乎睁开了眼睛。';
      case 3:
        return '海与光之间，有谁在静静注视。';
      default:
        return '深处的它，几乎完全醒了。';
    }
  }
}

/// 星兽渲染组件：星座连线构成的巨魟轮廓。
///
/// 轮廓由约 15 个节点 + 少量连线构成（性能友好，无粒子堆砌），
/// 平时 alpha 极低（比背景星稍亮的隐约轮廓）；眼睛逐只睁开为柔和
/// 辉光点，睁眼时伴随一圈涟漪与少量星屑轻轻聚拢。全睁后绕海缓游。
class StarBeast extends Component with HasGameReference<JingjingGame> {
  StarBeast() {
    final rng = math.Random(11);
    for (int i = 0; i < 14; i++) {
      _motes.add(
        _BeastMote(
          angle: rng.nextDouble() * math.pi * 2,
          baseRadius: 150 + rng.nextDouble() * 170,
          angularSpeed: (0.08 + rng.nextDouble() * 0.12) *
              (rng.nextBool() ? 1 : -1),
          size: 0.8 + rng.nextDouble() * 1.4,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  final StarBeastState state = StarBeastState();

  /// 渲染视差（reunion.dart 的星光连线端点用，避免魔法数重复）。
  static const double parallax = 0.7;

  /// 「相会」演出（第 18 轮）注入的位移向量：由 ReunionEvent 每帧
  /// 赋值（向两兽连线中点移近/退回），本组件只读叠加，不拥有其状态。
  final Vector2 reunionNudge = Vector2.zero();

  /// 当前世界坐标（含 nudge，供相会演出读取端点）。
  Vector2 get pos => _pos;

  /// 沉睡锚点：世界深处（失眠之海下方）。
  static final Vector2 anchor = Vector2(
    JingjingGame.worldPeriod.x * 0.5,
    JingjingGame.worldPeriod.y * 0.78,
  );

  /// 躯体轮廓节点（世界单位，吻朝 +x，左右对称的巨魟形）。
  static const List<Offset> bodyNodes = [
    Offset(230, 0), // 吻
    Offset(170, -52),
    Offset(60, -96),
    Offset(-90, -118), // 左翼尖
    Offset(-190, -70),
    Offset(-230, 0),
    Offset(-190, 70),
    Offset(-90, 118), // 右翼尖
    Offset(60, 96),
    Offset(170, 52),
  ];

  /// 尾迹（从躯体后端缓缓延伸）。
  static const List<Offset> tailNodes = [
    Offset(-228, 2),
    Offset(-300, 16),
    Offset(-390, 28),
    Offset(-465, 22),
  ];

  /// 五只眼：沿吻后弧线排布。
  static const List<Offset> eyeNodes = [
    Offset(190, -18),
    Offset(160, -34),
    Offset(148, 0),
    Offset(160, 34),
    Offset(190, 18),
  ];

  final List<_BeastMote> _motes = [];

  // ---- 第 16 轮性能审计：星座连线是静态形状——缓存为相对原点的
  // Path（原每帧重建两条 Path）；节点星/星屑画笔复用；眼睛辉光
  // 着色器按量化睁开度缓存（睁眼极慢，重建率极低）。
  late final Path _bodyPath = _polylinePath(bodyNodes, close: true);
  late final Path _tailPath = _polylinePath(tailNodes);
  final Paint _linePaint = Paint();
  final Paint _nodePaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _eyeCorePaint = Paint();
  final Paint _ripplePaint = Paint();
  final Paint _motePaint = Paint();
  final List<Shader?> _eyeShaders = List.filled(eyeNodes.length, null);
  final List<int> _eyeShaderKeys = List.filled(eyeNodes.length, -1);

  static Path _polylinePath(List<Offset> nodes, {bool close = false}) {
    final path = Path();
    for (int i = 0; i < nodes.length; i++) {
      if (i == 0) {
        path.moveTo(nodes[i].dx, nodes[i].dy);
      } else {
        path.lineTo(nodes[i].dx, nodes[i].dy);
      }
    }
    if (close) path.close();
    return path;
  }

  /// 每只眼的睁开度 0..1（极慢渐变，约 4 秒/只）。
  final List<double> eyeOpen = List.filled(StarBeastState.eyeCount, 0.0);

  /// 眯眼系数 0..1（第 26 轮「晨光告别」）：晨光漫入时把睁眼目标
  /// 等比压低——星兽不是被惊醒地闭眼，而是像困倦那样缓缓眯起。
  double squint = 0.0;

  /// 满醒睁眼增益 0..1（第 28 轮「满醒」终幕）：世界完全苏醒的一刻，
  /// 把睁眼目标临时抬到全开——沿用每只眼约 4 秒的既有渐变，缓缓睁眼；
  /// 演出结束归 0，眼睛按同一渐变缓缓合回原状。绝不瞬跳。
  double wakeOverride = 0.0;

  double _time = 0;
  double _swimT = 0;
  int _lastCycleCount = 0;
  Vector2 _pos = anchor.clone();

  @override
  Future<void> onLoad() async {
    await state.load();
    _lastCycleCount = game.cycleCount;
  }

  @override
  void update(double dt) {
    _time += dt;

    // 呼吸循环事件：游戏循环计数器，这里diff检测（碎片也会消费同一事件，
    // 但星兽独立计数，不受碎片消费影响）。
    if (game.cycleCount != _lastCycleCount) {
      _lastCycleCount = game.cycleCount;
      final d = (game.spiritPos - _pos);
      game.wrapDelta(d);
      state.update(dt, cycle: true, near: d.length < 420);
    }

    // 眼睛极慢渐变开合（每只约 4 秒）。满醒终幕把目标临时抬到全开。
    final wakeTarget =
        (wakeOverride * StarBeastState.eyeCount).round().clamp(0, eyeOpen.length);
    final target = math.max(state.openedEyes, wakeTarget);
    for (int i = 0; i < eyeOpen.length; i++) {
      final want = (i < target ? 1.0 : 0.0) * (1.0 - squint.clamp(0.0, 1.0));
      final cur = eyeOpen[i];
      if (cur < want) {
        eyeOpen[i] = math.min(want, cur + dt / 4.0);
      } else if (cur > want) {
        eyeOpen[i] = math.max(want, cur - dt / 4.0);
      }
    }

    // 游弋：全睁后绕海缓慢巡游；沉睡时几乎不动，只有极缓的呼吸起伏。
    if (state.swimming) {
      _swimT += dt;
      _pos = anchor +
          Vector2(
            math.cos(_swimT * 0.09) * 430,
            math.sin(_swimT * 0.061) * 300,
          );
      game.wrap(_pos);
    } else {
      _swimT = 0;
      _pos = anchor +
          Vector2(math.sin(_time * 0.05) * 22, math.cos(_time * 0.041) * 14);
    }
    // 相会演出位移（平时为零向量，零成本）。
    _pos.add(reunionNudge);
    game.wrap(_pos);
  }

  /// 世界坐标 -> 屏幕坐标（视差 0.7，比星岛更深远）。
  Offset _toScreen(Vector2 world, double parallax) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final cam = game.camPos * parallax;
    double dx = (world.x - cam.x) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (world.y - cam.y) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Offset(size.x / 2 + dx, size.y / 2 + dy);
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final center = _toScreen(_pos, 0.7);

    // 完全在屏外则跳过（环绕世界中的省钱绘制）。
    const margin = 620.0;
    if (center.dx < -margin ||
        center.dx > size.x + margin ||
        center.dy < -margin ||
        center.dy > size.y + margin) {
      return;
    }

    final openSum = eyeOpen.fold<double>(0, (a, b) => a + b);
    final openFrac = openSum / eyeOpen.length;
    final aw = game.awakeningValue.value;

    // 轮廓亮度：平时比背景星稍亮的隐约轮廓；越醒越清晰。
    final lineAlpha = (0.07 + 0.10 * openFrac + 0.03 * aw).clamp(0.0, 1.0);
    final nodeAlpha = (lineAlpha + 0.05).clamp(0.0, 1.0);
    _linePaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = ZenTheme.nebulaCyan.withValues(alpha: lineAlpha);

    // 躯体轮廓与尾迹：静态 Path 缓存，平移到中心绘制。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawPath(_bodyPath, _linePaint);
    canvas.drawPath(_tailPath, _linePaint);

    // 轮廓节点：稍亮的星点（含极缓明灭，像星座本身在呼吸）。
    for (int i = 0; i < bodyNodes.length; i++) {
      final tw =
          0.7 + 0.3 * math.sin(_time * 0.6 + i * 1.9);
      canvas.drawCircle(
        bodyNodes[i],
        1.3,
        _nodePaint
          ..color = ZenTheme.starWhite.withValues(alpha: nodeAlpha * tw),
      );
    }
    for (int i = 0; i < tailNodes.length; i++) {
      canvas.drawCircle(
        tailNodes[i],
        1.1,
        _nodePaint
          ..color = ZenTheme.starWhite.withValues(alpha: nodeAlpha * 0.8),
      );
    }

    // 眼睛：柔和辉光点，逐只极慢睁开；睁眼中伴随涟漪。
    for (int i = 0; i < eyeNodes.length; i++) {
      final open = eyeOpen[i];
      if (open > 0.001) {
        final glowR = 5.0 + 9.0 * open;
        final openQ = (open * 50).round(); // 0.02 步进
        if (openQ != _eyeShaderKeys[i]) {
          _eyeShaderKeys[i] = openQ;
          _eyeShaders[i] = RadialGradient(
            colors: [
              ZenTheme.starWhite.withValues(alpha: 0.55 * open),
              ZenTheme.nebulaCyan.withValues(alpha: 0.30 * open),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: eyeNodes[i], radius: glowR));
        }
        canvas.drawCircle(
          eyeNodes[i],
          glowR,
          _glowPaint..shader = _eyeShaders[i],
        );
        canvas.drawCircle(
          eyeNodes[i],
          1.6,
          _eyeCorePaint
            ..color = ZenTheme.starWhite.withValues(alpha: 0.8 * open),
        );
      }
      // 涟漪：只在睁眼过渡期出现一次性的扩散环。
      if (open > 0.01 && open < 0.99) {
        final rippleR = 18.0 + 95.0 * open;
        final rippleA = 0.22 * math.sin(math.pi * open);
        canvas.drawCircle(
          eyeNodes[i],
          rippleR,
          _ripplePaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = ZenTheme.nebulaCyan.withValues(alpha: rippleA),
        );
      }
    }

    // 星屑：星兽周围少量微粒，眼睛睁开越多越轻轻聚拢，游弋时随行。
    final converge = 1.0 - 0.55 * openFrac;
    for (final mote in _motes) {
      final a = mote.angle + _time * mote.angularSpeed;
      final wob = 1.0 + 0.06 * math.sin(_time * 0.5 + mote.phase);
      final r = mote.baseRadius * converge * wob;
      final p = Offset(
        math.cos(a) * r,
        math.sin(a) * r * 0.7, // 略扁，像贴着海流
      );
      final alpha = (0.10 + 0.16 * openFrac) *
          (0.6 + 0.4 * math.sin(_time * 0.9 + mote.phase));
      canvas.drawCircle(
        p,
        mote.size,
        _motePaint..color = ZenTheme.nebulaCyan.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
    canvas.restore();
  }
}

class _BeastMote {
  _BeastMote({
    required this.angle,
    required this.baseRadius,
    required this.angularSpeed,
    required this.size,
    required this.phase,
  });

  final double angle;
  final double baseRadius;
  final double angularSpeed;
  final double size;
  final double phase;
}
