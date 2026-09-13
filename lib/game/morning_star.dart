import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'full_awake.dart';
import 'jingjing_game.dart';
import 'koans.dart';

/// 「晨星」（第 29 轮）——满醒之后，世界里常驻的一枚醒痕。
///
/// 演过满醒终幕后（读 `jingxin.fullawake.v1` 的"已演过"标记，
/// 不新增任何存储键），环世界某处（与既有区域/静之径不重叠的
/// 固定世界坐标，程序生成、无需持久化位置）常驻一枚小小的晨星：
/// 慢闪的暖白光点 + 微弱光晕，呼吸相位时亮度轻微回应（吸气稍亮、
/// 呼气稍敛），克制。旁边极淡地绕行一粒"尘伴"（60s 一圈，只此一枚）。
///
/// 点击晨星（命中半径放宽）浮现一句醒星短偈（新池 3 句，轮换取用），
/// 5s 淡出（复用既有禅语面板），冷却期内不重复弹；与各演出互斥
/// （演出中点击无效，互斥判定在游戏层）。
///
/// 性能：常驻元素每帧零分配——画笔与光晕着色器按量化 alpha 缓存，
/// 屏外剔除沿用既有镜像换算；不可见（未满醒过）时零渲染成本。
///
/// 触发条件、点击冷却、偈语轮换与命中判定抽成纯逻辑（[MorningStarCtl]
/// 与 [KoanRotator]），方便测试。
class MorningStarCtl {
  MorningStarCtl._();

  /// 晨星的固定世界坐标（程序生成，与既有区域/静之径不重叠）：
  /// nx 0.585 / ny 0.225——失眠之海中带偏东，不在渊（ny≥0.80）、
  /// 荒原（ny≤0.18）、雾林接缝带（|0.5-nx|≥0.36 带外即海），
  /// 也不在静之径（径全在西侧 x≤816）上。
  static Vector2 position(Vector2 period) =>
      Vector2(period.x * 0.585, period.y * 0.225);

  /// 点击命中半径（世界单位，放宽到 ~40px，触控友好）。
  static const double tapRadius = 40.0;

  /// 偈语停留时长（既有禅语面板淡出 5s，这里对齐冷却下限的一半）。
  static const double koanHoldSeconds = 5.0;

  /// 冷却：10s 内不重复弹偈。
  static const double koanCooldown = 10.0;

  /// 尘伴绕行一圈的时长（秒）。
  static const double dustOrbitSeconds = 60.0;

  /// 尘伴绕行半径（屏幕像素）。
  static const double dustOrbitRadius = 26.0;

  /// 环绕最短差：a→b 的最短向量（环面）。
  static Vector2 shortestDelta(Vector2 a, Vector2 b, Vector2 period) {
    double dx = (b.x - a.x) % period.x;
    if (dx < -period.x / 2) dx += period.x;
    if (dx > period.x / 2) dx -= period.x;
    double dy = (b.y - a.y) % period.y;
    if (dy < -period.y / 2) dy += period.y;
    if (dy > period.y / 2) dy -= period.y;
    return Vector2(dx, dy);
  }

  /// 命中判定：世界点距晨星（环绕最近距离）在 [tapRadius] 内。
  static bool hitTest(Vector2 tapWorld, Vector2 starPos, Vector2 period) {
    final d = shortestDelta(starPos, tapWorld, period);
    return d.length2 <= tapRadius * tapRadius;
  }

  /// 点击冷却：距上次弹偈不足 [koanCooldown] 秒则不重复弹。
  static bool koanAllowed(double sinceLast) => sinceLast >= koanCooldown;

  /// 可见性：演过满醒终幕才常驻（醒痕只在醒过的世界里）。
  static bool visible({required bool playedEver}) => playedEver;
}

/// 偈语轮换器：按索引轮换取用（0,1,2,0,…），一轮内绝不重复——
/// 晨星只有 3 句短偈，轮换比随机更"像它自己的话"。
class KoanRotator {
  int _index = -1;

  int get index => _index;

  String next(List<String> pool) {
    assert(pool.isNotEmpty);
    _index = (_index + 1) % pool.length;
    return pool[_index];
  }
}

/// 晨星组件：常驻渲染 + 点击响应（命中判定由游戏层完成）。
class MorningStar extends Component with HasGameReference<JingjingGame> {
  MorningStar();

  /// 是否已演过满醒终幕（醒痕的显示条件）。
  bool playedEver = false;

  /// 偈语轮换器（组件生命周期内持续轮换）。
  final KoanRotator rotator = KoanRotator();

  /// 上次弹偈的游戏时间（秒）；-999 = 从未弹过。
  double _lastKoanTime = -999;

  /// 本会话内已点亮的次数（调试/测试观察用）。
  int koanCount = 0;

  bool get visible =>
      MorningStarCtl.visible(playedEver: playedEver) && game.introEase > 0.05;

  @override
  Future<void> onLoad() async {
    // 只读既有"已演过"标记，不新增存储键——读失败按未演过处理
    //（与满醒终幕同款兜底：宁可少一枚痕，不误亮）。
    playedEver = await FullAwakeCtl.loadPlayed();
  }

  /// 游戏层的点击转发：命中且不在冷却时弹一句醒星偈。
  /// 返回 true 表示本次点击被晨星消费。
  bool onTap(Vector2 tapWorld) {
    if (!playedEver) return false;
    if (!MorningStarCtl.hitTest(
      tapWorld,
      MorningStarCtl.position(JingjingGame.worldPeriod),
      JingjingGame.worldPeriod,
    )) {
      return false;
    }
    final since = game.time - _lastKoanTime;
    if (!MorningStarCtl.koanAllowed(since)) return true; // 命中但冷却中：吞掉点击，不弹。
    _lastKoanTime = game.time;
    koanCount++;
    game.shardMessage.value = rotator.next(Koans.morningStarPool);
    return true;
  }

  // ---- 渲染：零每帧分配，着色器按量化 alpha 缓存 ----
  final Paint _glowPaint = Paint();
  final Paint _corePaint = Paint();
  final Paint _dustPaint = Paint();
  Shader? _glowShader;
  int _glowKey = -1;

  /// 世界坐标 -> 屏幕坐标（视差 1，环绕最近镜像），复用向量避免分配。
  final Vector2 _screenDelta = Vector2.zero();

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final size = game.size;
    final period = JingjingGame.worldPeriod;
    final starPos = MorningStarCtl.position(period);
    final d = MorningStarCtl.shortestDelta(game.camPos, starPos, period);
    _screenDelta.setValues(d.x, d.y);
    final cx = size.x / 2 + _screenDelta.x;
    final cy = size.y / 2 + _screenDelta.y;

    // 屏外剔除（留 60px 余量给光晕）。
    if (cx < -60 || cx > size.x + 60 || cy < -60 || cy > size.y + 60) return;

    final t = game.time;

    // 慢闪：约 7s 一次柔和的起落；呼吸相位轻微回应（吸气稍亮、呼气稍敛）。
    final blink = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 7.0);
    final breath = game.breathPhase;
    final alpha =
        (0.30 + 0.30 * blink + 0.10 * breath) * game.introEase.clamp(0.0, 1.0);

    // 光晕：暖白极淡，着色器按量化 alpha 缓存（0.01 步进）。
    final glowA = alpha * 0.28;
    final glowQ = (glowA * 100).round();
    if (glowQ != _glowKey) {
      _glowKey = glowQ;
      _glowShader = RadialGradient(
        colors: [
          const Color(0xFFf5e8c8).withValues(alpha: glowA),
          const Color(0xFFf5e8c8).withValues(alpha: glowA * 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset.zero,
        radius: _glowRadius,
      ));
    }
    canvas.save();
    canvas.translate(cx, cy);
    canvas.drawCircle(Offset.zero, _glowRadius, _glowPaint..shader = _glowShader);

    // 星本体：小小的暖白光点。
    _corePaint.color = const Color(
      0xFFfdf6e3,
    ).withValues(alpha: (0.55 + 0.35 * blink + 0.10 * breath).clamp(0.0, 1.0));
    canvas.drawCircle(Offset.zero, 2.2, _corePaint);

    // 尘伴：一粒小卫星点，60s 极淡绕行一圈，只此一枚。
    final a = t * math.pi * 2 / MorningStarCtl.dustOrbitSeconds;
    final dustA = alpha * 0.22;
    _dustPaint.color = ZenTheme.starWhite.withValues(alpha: dustA);
    canvas.drawCircle(
      Offset(
        math.cos(a) * MorningStarCtl.dustOrbitRadius,
        math.sin(a) * MorningStarCtl.dustOrbitRadius * 0.7, // 微椭圆，更像同路。
      ),
      1.1,
      _dustPaint,
    );
    canvas.restore();
  }

  static const double _glowRadius = 14.0;
}
