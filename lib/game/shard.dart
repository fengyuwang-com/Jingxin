import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'jingjing_game.dart';
import 'koans.dart';
import 'regions.dart';

/// 心镜碎片收集史（第 4 轮）。
///
/// 只记录：时间 + 禅语 + 所获区域。无数量上限、无成就弹窗、
/// 无计数展示——收集史是玩家的私人星图素材，不是成绩单。
class ShardCollection {
  ShardCollection();

  static const String _prefKey = 'jingxin.shards.v1';

  final List<ShardRecord> records = [];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      records
        ..clear()
        ..addAll(
          list
              .whereType<Map<String, dynamic>>()
              .map((m) => ShardRecord.fromJson(m))
              .toList(),
        );
    } catch (_) {
      // 损坏则静默重新开始，不打扰玩家。
      records.clear();
    }
  }

  Future<void> add(ShardRecord record) async {
    records.add(record);
    await save();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // 持久化失败静默忽略。
    }
  }
}

class ShardRecord {
  ShardRecord({required this.time, required this.text, required this.region});

  final DateTime time;
  final String text;
  final String region;

  Map<String, dynamic> toJson() => {
    't': time.millisecondsSinceEpoch,
    'text': text,
    'region': region,
  };

  factory ShardRecord.fromJson(Map<String, dynamic> json) => ShardRecord(
    time: DateTime.fromMillisecondsSinceEpoch(
      (json['t'] as num?)?.toInt() ?? 0,
    ),
    text: (json['text'] as String?) ?? '',
    region: (json['region'] as String?) ?? '失眠之海',
  );
}

/// 「心镜碎片」：海面上极稀疏漂浮的微光棱片。
///
/// 光灵漂近且光灵刚完成一次平稳呼吸循环时，碎片被"轻轻吸入"
/// （柔和收拢动画），同时浮现一句禅语。不打断漫游。
class MindShard extends Component with HasGameReference<JingjingGame> {
  MindShard({
    required this.position,
    required this.phase,
    required this.tint,
    this.abyss = false,
  });

  /// 世界坐标（环绕周期内）。
  Vector2 position;
  final double phase;
  final Color tint;

  /// 是否为「焦虑之渊」碎片：用渊的偈语池与冷紫色调。
  final bool abyss;

  /// 0..1 被吸入进度；>=1 后由游戏层移除并回调禅语。
  double absorb = 0;
  bool _absorbing = false;

  /// 吸入完成后要浮现的偈语（预生成，按区域取池，避免吸入瞬间卡顿）。
  late final String koan = abyss ? Koans.nextAbyss() : Koans.next();

  bool get isAbsorbed => absorb >= 1;

  @override
  void update(double dt) {
    if (_absorbing) {
      // 轻轻吸入：先朝光灵收拢，进度先缓后快，柔和无急停。
      absorb = (absorb + dt / 1.6).clamp(0.0, 1.0);
      final t = absorb;
      final spirit = game.spiritPos;
      final period = JingjingGame.worldPeriod;
      // 用最短环绕向量向光灵收拢。
      double dx = (spirit.x - position.x) % period.x;
      if (dx > period.x / 2) dx -= period.x;
      if (dx < -period.x / 2) dx += period.x;
      double dy = (spirit.y - position.y) % period.y;
      if (dy > period.y / 2) dy -= period.y;
      if (dy < -period.y / 2) dy += period.y;
      final ease = t * t * (3 - 2 * t); // smoothstep
      position += Vector2(dx, dy) * ease * dt * 2.2;
      return;
    }

    // 靠近 + 刚完成一次平稳呼吸循环 -> 开始吸入。
    final period = JingjingGame.worldPeriod;
    final spirit = game.spiritPos;
    double dx = (position.x - spirit.x) % period.x;
    if (dx > period.x / 2) dx -= period.x;
    if (dx < -period.x / 2) dx += period.x;
    double dy = (position.y - spirit.y) % period.y;
    if (dy > period.y / 2) dy -= period.y;
    if (dy < -period.y / 2) dy += period.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    const nearRange = 190.0;
    if (dist < nearRange && game.consumeCycleEvent()) {
      _absorbing = true;
    }
  }

  /// 世界坐标 -> 屏幕坐标（与星岛同视差 0.85，含环绕镜像）。
  Offset _wrapToScreen(Vector2 world, Vector2 size) {
    final period = JingjingGame.worldPeriod;
    final parallax = 0.85;
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
    if (isAbsorbed) return;
    final size = game.size;
    final p = _wrapToScreen(position, size);
    if (p.dx < -40 || p.dx > size.x + 40 || p.dy < -40 || p.dy > size.y + 40) {
      return;
    }

    final bob = math.sin(game.time * 0.9 + phase);
    final center = Offset(p.dx, p.dy + bob * 6);
    final shrink = _absorbing ? 1.0 - absorb * 0.85 : 1.0;
    final r = 5.5 * shrink;
    final breathe = 0.55 + 0.45 * math.sin(game.time * 1.3 + phase * 2);
    final alpha = (_absorbing ? (1.0 - absorb * 0.6) : 1.0);

    // 微光晕。
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          tint.withValues(alpha: 0.30 * breathe * alpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 4));
    canvas.drawCircle(center, r * 4, glowPaint);

    // 棱片本体：细长旋转的菱形，微微自转。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(game.time * 0.4 + phase);
    final paint = Paint()
      ..color = Color.lerp(
        ZenTheme.starWhite,
        tint,
        0.4,
      )!.withValues(alpha: (0.55 + 0.4 * breathe) * alpha)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, -r * 1.8)
      ..lineTo(r * 0.75, 0)
      ..lineTo(0, r * 1.8)
      ..lineTo(-r * 0.75, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = ZenTheme.starWhite.withValues(alpha: 0.5 * alpha),
    );
    canvas.restore();
  }
}

/// 所获区域命名：按世界坐标所在的区域 + 九宫格给出诗意地名。
/// 区域是轻量抽象（regions.dart）：海是底层全域，渊在海的更深处。
String regionNameFor(Vector2 worldPos) {
  final region = GameRegion.regionAt(worldPos);
  return region.fullName(worldPos);
}
