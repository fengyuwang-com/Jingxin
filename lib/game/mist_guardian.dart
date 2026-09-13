import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';
import 'quality.dart';
import 'shard.dart';

/// 星兽「惘」——雾林的守林者（第 17 轮，第二头星兽）。
///
/// 与眠（巨魟，靠累计值分档睁眼）相对，惘是一只瘦长的星座狐：
/// 竖耳、细长的尾，漫步在世界左接缝的雾林带（nx≈0.06，视差比林稍深）。
///
/// 苏醒机制与眠完全差异化——不累计、不分档、不持久化：
/// 「雾透则兽现」。惘的显形度跟随雾林的雾沉降度（复用 MistWood.settle），
/// 林子被平稳呼吸沉降得越透，惘越显形；雾回升它就退回雾里。
/// 显形有 60 秒的最短渐进（每秒至多升 1/60），不会一进游戏就可见。
///
/// 唯一互动「惘的礼物」：完全显形（reveal>0.85）且光灵靠近（<300）
/// 并完成一次平稳呼吸循环时，它低头轻触光灵一次（缓慢点头），
/// 送出一枚金色心镜碎片（惘语偈语池）。每次显形期至多一次，
/// 无提示无成就——雾重新漫起（reveal<0.3）后才可能再有。
///
/// 性能：轮廓 Path 缓存、画笔复用、眼睛辉光着色器量化缓存、屏外跳过。
class MistGuardian extends Component with HasGameReference<JingjingGame> {
  MistGuardian() {
    final rng = math.Random(173);
    final motes = Quality.current.isLow ? 5 : 9;
    for (int i = 0; i < motes; i++) {
      _motes.add(
        _GuardianMote(
          angle: rng.nextDouble() * math.pi * 2,
          baseRadius: 60 + rng.nextDouble() * 90,
          angularSpeed: (0.10 + rng.nextDouble() * 0.14) *
              (rng.nextBool() ? 1 : -1),
          size: 0.7 + rng.nextDouble() * 1.1,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  /// 锚点：世界左接缝的雾林带中段（与墨枝同一侧的林深处）。
  static Vector2 get anchor => Vector2(
        JingjingGame.worldPeriod.x * 0.06,
        JingjingGame.worldPeriod.y * 0.50,
      );

  /// 视差比雾林（0.88~1.0）稍深。
  static const double parallax = 0.80;

  /// 躯体轮廓节点（世界单位，吻朝 +x，瘦长优雅的狐形，闭合成星座）。
  static const List<Offset> bodyNodes = [
    Offset(150, 0), // 吻尖
    Offset(116, -20), // 额
    Offset(122, -52), // 左耳尖
    Offset(88, -30), // 耳后
    Offset(16, -26), // 背
    Offset(-64, -20), // 臀背
    Offset(-116, -14), // 尾根
    Offset(-64, 20), // 臀腹
    Offset(16, 24), // 腹
    Offset(92, 16), // 胸
    Offset(118, 8), // 颚
  ];

  /// 细长的尾：从尾根向后下方缓缓延展（渲染时随显形度轻摆）。
  static const List<Offset> tailNodes = [
    Offset(-116, -14),
    Offset(-164, -2),
    Offset(-216, -22),
    Offset(-266, -38),
    Offset(-312, -28),
  ];

  /// 一只眼：显形后才缓缓亮起的柔和辉光点。
  static const Offset eyeNode = Offset(112, -14);

  late final Path _bodyPath = _polylinePath(bodyNodes, close: true);
  late final Path _tailPath = _polylinePath(tailNodes);
  final Paint _linePaint = Paint();
  final Paint _nodePaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _motePaint = Paint();
  Shader? _eyeShader;
  int _eyeShaderKey = -1;

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

  final List<_GuardianMote> _motes = [];

  /// 显形度 0..1（跟随雾沉降，升受限速 60s、落稍快）。
  ///
  /// 配平注（第 22 轮巡检）：雾沉降到满约 45s（mist_wood settle），
  /// 显形限速 1/60s——因此完全显形需要约 60s 的持续平稳呼吸，
  /// 恶意"蹭一下就走"永远到不了 reveal>0.85 的礼物/相会门槛；
  /// 显形始终滞后于雾，是刻薄的温柔，不是 bug。
  double reveal = 0;

  /// 「相会」演出（第 18 轮）：星光亮起期间的凝望度（0..1），
  /// 让眼中柔光与轮廓微微更亮，像竖起耳朵在望。
  double gaze = 0;

  /// 「相会」演出注入的位移向量（ReunionEvent 每帧赋值，只读叠加）。
  final Vector2 reunionNudge = Vector2.zero();

  /// 当前世界坐标（含 nudge，供相会演出读取端点）。
  Vector2 get pos => _pos;

  double _time = 0;
  int _lastCycleCount = 0;
  final Vector2 _pos = anchor.clone();

  // 点头赠礼状态。
  bool _nodding = false;
  double _nodT = 0;
  bool _giftedThisRise = false;

  @override
  void onLoad() {
    _lastCycleCount = game.cycleCount;
  }

  @override
  void update(double dt) {
    _time += dt;

    // 显形度跟随雾沉降：升有 60s 最短渐进，雾回升则退回雾里（稍快）。
    final target = game.mistWood.settle;
    if (target > reveal) {
      reveal = math.min(target, reveal + dt / 60.0);
    } else {
      reveal = math.max(target, reveal - dt / 55.0);
    }

    // 雾重新漫起后，礼物资格重置（下次显形期仍可能有一次）。
    if (_giftedThisRise && reveal < 0.3) _giftedThisRise = false;

    // 平稳呼吸循环事件（独立 diff，与碎片/眠互不影响）：
    // 完全显形 + 光灵靠近 -> 低头轻触，送出金色心镜碎片。
    if (game.cycleCount != _lastCycleCount) {
      _lastCycleCount = game.cycleCount;
      if (!_nodding && !_giftedThisRise && reveal > 0.85) {
        final d = game.spiritPos - _pos;
        game.wrapDelta(d);
        if (d.length < 300) {
          _nodding = true;
          _nodT = 0;
          _giftedThisRise = true;
        }
      }
    }
    if (_nodding) {
      _nodT += dt / 2.8;
      // 低头到位的瞬间送出碎片（一次，安静无提示）。
      if (_nodT >= 0.5 && _nodT - dt / 2.8 < 0.5) _giveGift();
      if (_nodT >= 1) {
        _nodT = 0;
        _nodding = false;
      }
    }

    // 漫步：显形后从雾里向光灵方向走出几步（有上限），平时几乎不动。
    final stroll = ((reveal - 0.25) / 0.75).clamp(0.0, 1.0);
    double stepX = 0;
    double stepY = 0;
    if (stroll > 0.001) {
      final d = game.spiritPos - anchor;
      game.wrapDelta(d);
      final len = d.length;
      if (len > 1) {
        final reach = math.min(len, 140.0) * stroll;
        stepX = d.x / len * reach;
        stepY = d.y / len * reach;
      }
    }
    _pos
      ..setFrom(anchor)
      ..x += stepX + math.sin(_time * 0.11) * 24
      ..y += stepY + math.cos(_time * 0.083) * 11;
    game.wrap(_pos);
    // 相会演出位移（平时为零向量，零成本）。
    _pos.add(reunionNudge);
    game.wrap(_pos);
  }

  /// 送出金色心镜碎片：普通碎片逻辑复用，金色色调 + 惘语偈语。
  void _giveGift() {
    final nose = Offset(150 * math.cos(_pitch), 0);
    final shard = MindShard(
      position: _pos + Vector2(nose.dx, nose.dy),
      phase: _time % (math.pi * 2),
      tint: const Color(0xFFe8c96a),
      gift: true,
    );
    game.shards.add(shard);
    game.add(shard);
  }

  /// 点头时的低头俯角（缓慢的 sin 起落）。
  double get _pitch =>
      _nodding ? math.sin(math.pi * _nodT.clamp(0.0, 1.0)) * 0.14 : 0.0;

  /// 世界坐标 -> 屏幕坐标（视差 0.80，环绕最近镜像）。
  Offset _toScreen(Vector2 world) {
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    double dx = (world.x - game.camPos.x * parallax) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (world.y - game.camPos.y * parallax) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Offset(size.x / 2 + dx, size.y / 2 + dy);
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final center = _toScreen(_pos);

    const margin = 460.0;
    if (center.dx < -margin ||
        center.dx > size.x + margin ||
        center.dy < -margin ||
        center.dy > size.y + margin) {
      return;
    }

    final rv = reveal;
    if (rv <= 0.001) return;

    // 平时 alpha ≤0.06 隐约可辨；完全显形接近 0.30。与雾林色调一致的青灰。
    final lineAlpha = (0.05 + 0.25 * rv).clamp(0.0, 0.32);
    final nodeAlpha = (lineAlpha + 0.05).clamp(0.0, 0.4);
    _linePaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF9cc8b8).withValues(alpha: lineAlpha);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 点头：绕臀部缓缓低头俯身（缓慢的 sin 起落，约 2.8 秒一次轻触）。
    final pitch = _pitch;
    if (pitch != 0) {
      canvas.translate(-64, 0);
      canvas.rotate(pitch);
      canvas.translate(64, 0);
    }

    // 躯体轮廓：静态 Path 缓存。
    canvas.drawPath(_bodyPath, _linePaint);

    // 细长的尾：随显形度开始轻摆（绕尾根的小幅摆动）。
    final sway = math.sin(_time * 0.9) * 0.10 * rv;
    canvas.save();
    canvas.translate(tailNodes.first.dx, tailNodes.first.dy);
    canvas.rotate(sway);
    canvas.translate(-tailNodes.first.dx, -tailNodes.first.dy);
    canvas.drawPath(_tailPath, _linePaint);
    canvas.restore();

    // 轮廓节点：稍亮的星点，带极缓明灭。
    for (int i = 0; i < bodyNodes.length; i++) {
      final tw = 0.7 + 0.3 * math.sin(_time * 0.55 + i * 1.7);
      canvas.drawCircle(
        bodyNodes[i],
        1.2,
        _nodePaint
          ..color = ZenTheme.starWhite.withValues(alpha: nodeAlpha * tw),
      );
    }
    for (int i = 1; i < tailNodes.length; i++) {
      canvas.drawCircle(
        tailNodes[i],
        1.0,
        _nodePaint..color = ZenTheme.starWhite.withValues(alpha: nodeAlpha * 0.8),
      );
    }

    // 眼：显形越深越亮的一只柔光（着色器按量化显形度缓存）；
    // 相会凝望时微微更亮（gaze 0..1，演出期才有值）。
    final eyeA = (0.30 * rv * (1.0 + 0.5 * gaze)).clamp(0.0, 0.45);
    final eyeQ = (rv * 50).round();
    if (eyeQ != _eyeShaderKey) {
      _eyeShaderKey = eyeQ;
      _eyeShader = RadialGradient(
        colors: [
          ZenTheme.starWhite.withValues(alpha: eyeA),
          const Color(0xFF9cc8b8).withValues(alpha: eyeA * 0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: eyeNode, radius: 9));
    }
    canvas.drawCircle(eyeNode, 9, _glowPaint..shader = _eyeShader);
    canvas.drawCircle(
      eyeNode,
      1.3,
      _nodePaint..color = ZenTheme.starWhite.withValues(alpha: 0.5 * rv),
    );

    // 身边少量雾中尘点（与雾林的萤不同：更慢、更贴着狐）。
    for (final mote in _motes) {
      final a = mote.angle + _time * mote.angularSpeed;
      final r = mote.baseRadius * (1.0 + 0.05 * math.sin(_time * 0.4 + mote.phase));
      final alpha = (0.05 + 0.10 * rv) *
          (0.6 + 0.4 * math.sin(_time * 0.7 + mote.phase));
      canvas.drawCircle(
        Offset(math.cos(a) * r, math.sin(a) * r * 0.75),
        mote.size,
        _motePaint
          ..color = const Color(0xFFbfe8d0)
              .withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }

    canvas.restore();
  }
}

class _GuardianMote {
  _GuardianMote({
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
