import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/companion.dart';
import 'package:jingxin_meditation/game/still_path.dart';

void main() {
  group('CompanionGuide 同频引路状态机', () {
    test('长按不足 1.2 秒不触发接近', () {
      final g = CompanionGuide();
      for (int i = 0; i < 11; i++) {
        g.update(holding: true, withinStopDistance: false, blocked: false, dt: 0.1);
      }
      // 1.1 秒：仍在 idle。
      expect(g.state, CompanionState.idle);
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 0.1);
      // 累计满 1.2 秒：进入接近。
      expect(g.state, CompanionState.approaching);
      expect(g.moving, isTrue);
    });

    test('进入停驻距离后停住（moving=false），松手后停驻 2 秒再回归', () {
      final g = CompanionGuide();
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 1.3);
      expect(g.state, CompanionState.approaching);

      // 已到指尖 30px 内：不再移动。
      g.update(holding: true, withinStopDistance: true, blocked: false, dt: 0.1);
      expect(g.moving, isFalse);

      // 松手 → 停驻；不足 2 秒不回归。
      g.update(holding: false, withinStopDistance: true, blocked: false, dt: 0.5);
      expect(g.state, CompanionState.resting);
      g.update(holding: false, withinStopDistance: true, blocked: false, dt: 1.5);
      expect(g.state, CompanionState.resting);
      g.update(holding: false, withinStopDistance: true, blocked: false, dt: 0.6);
      expect(g.state, CompanionState.idle);
    });

    test('演出互斥：开场引导 / 相会进行中不触发', () {
      final g = CompanionGuide();
      // 长按全程 blocked：永远停在 idle。
      for (int i = 0; i < 30; i++) {
        g.update(holding: true, withinStopDistance: false, blocked: true, dt: 0.1);
      }
      expect(g.state, CompanionState.idle);

      // 已在接近中，演出开始 → 立即退场。
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 1.3);
      expect(g.state, CompanionState.approaching);
      g.update(holding: true, withinStopDistance: false, blocked: true, dt: 0.1);
      expect(g.state, CompanionState.idle);
    });

    test('停驻期再次按住不瞬切：回到 idle 重新起算长按', () {
      final g = CompanionGuide();
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 1.3);
      g.update(holding: false, withinStopDistance: true, blocked: false, dt: 0.5);
      expect(g.state, CompanionState.resting);

      // 再次按住：须重新等满阈值。
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 0.5);
      expect(g.state, CompanionState.idle);
      g.update(holding: true, withinStopDistance: false, blocked: false, dt: 0.8);
      expect(g.state, CompanionState.approaching);
    });
  });

  group('StillPath 续余温接口（同频引路）', () {
    test('长按点在径上 → 附近采样点获余温，远处不受影响', () {
      final path = StillPath();
      // 第一个采样点在荒原顶部锚点（816,150）附近。
      path.warmNearPoint(Vector2(816, 150), 1.8);
      // 径上附近的采样点被续温（1.8 秒 → 满温，封顶 1）。
      expect(path.warmthAt(0), greaterThan(0.5));
      expect(path.warmthAt(0), lessThanOrEqualTo(1.0));

      // 远处的点（世界另一侧）不落温。
      final path2 = StillPath();
      path2.warmNearPoint(Vector2(2000, 300), 5.0);
      var anyWarm = false;
      for (int i = 0; i < path2.sampleCount; i++) {
        if (path2.warmthAt(i) > 0) anyWarm = true;
      }
      expect(anyWarm, isFalse);
    });

    test('续温沿用既有速率：dt/1.8 累积', () {
      final path = StillPath();
      path.warmNearPoint(Vector2(816, 150), 0.18); // 0.18s → 0.1
      expect(path.warmthAt(0), closeTo(0.1, 0.02));
    });
  });
}
