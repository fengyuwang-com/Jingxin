import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/firefly_gleam.dart';

void main() {
  const w = kFireflyWorldW;
  const h = kFireflyWorldH;

  group('fireflyGleamAt 确定性与轨迹', () {
    test('同输入同输出（确定性）', () {
      for (int i = 0; i < 8; i++) {
        final a = fireflyGleamAt(123.4, i, w, h);
        final b = fireflyGleamAt(123.4, i, w, h);
        expect(a.x, b.x);
        expect(a.y, b.y);
        expect(a.phase, b.phase);
      }
    });

    test('不同萤火参数互异（散列分布）', () {
      final a = fireflyGleamAt(10.0, 0, w, h);
      final b = fireflyGleamAt(10.0, 1, w, h);
      final c = fireflyGleamAt(10.0, 2, w, h);
      expect(a.glowPeriodSec, isNot(b.glowPeriodSec));
      expect(b.glowPeriodSec, isNot(c.glowPeriodSec));
      expect(a.x == b.x && a.y == b.y, isFalse);
    });

    test('位置始终界内（0..worldW/H，含长时间与负时间）', () {
      for (int i = 0; i < 8; i++) {
        for (final t in [-1000.0, -0.5, 0.0, 1.0, 3600.0, 86400.0]) {
          final f = fireflyGleamAt(t, i, w, h);
          expect(f.x, inInclusiveRange(0, w), reason: 'i=$i t=$t');
          expect(f.y, inInclusiveRange(0, h), reason: 'i=$i t=$t');
        }
      }
    });

    test('明灭周期落在 6~9s 区间', () {
      for (int i = 0; i < 16; i++) {
        final p = fireflyGleamAt(0, i, w, h).glowPeriodSec;
        expect(p, inInclusiveRange(6.0, 9.0));
      }
    });

    test('漂移极慢（0.8~2.4 px/s）——肉眼近凝滞', () {
      for (int i = 0; i < 16; i++) {
        final f = fireflyGleamAt(0, i, w, h);
        final speed = (f.vx * f.vx + f.vy * f.vy);
        expect(speed, lessThanOrEqualTo(2.4 * 2.4 + 1e-9));
        expect(speed, greaterThanOrEqualTo(0.8 * 0.8 - 1e-9));
      }
    });

    test('时间连续性：相邻 100ms 位移极小', () {
      for (int i = 0; i < 8; i++) {
        final a = fireflyGleamAt(500.0, i, w, h);
        final b = fireflyGleamAt(500.1, i, w, h);
        // 环面最短差。
        var dx = (b.x - a.x).abs();
        var dy = (b.y - a.y).abs();
        if (dx > w / 2) dx = w - dx;
        if (dy > h / 2) dy = h - dy;
        expect(dx * dx + dy * dy, lessThan(0.5 * 0.5));
      }
    });

    test('环面接缝连续：t 前后跨 wrap 位置只差一个周期', () {
      // 同一只萤火，位置在 wrap 边界两侧应为同一点（mod 意义下）。
      for (int i = 0; i < 8; i++) {
        final a = fireflyGleamAt(1e6, i, w, h);
        // 前进整整一秒不产生跳变大于漂移上界（不含 wrap 跳变）。
        final b = fireflyGleamAt(1e6 + 0.1, i, w, h);
        var dx = (b.x - a.x).abs();
        var dy = (b.y - a.y).abs();
        if (dx > w / 2) dx = w - dx;
        if (dy > h / 2) dy = h - dy;
        expect(dx, lessThan(0.5));
        expect(dy, lessThan(0.5));
      }
    });
  });

  group('fireflyVisual 亮度映射', () {
    test('峰值封顶 0.09', () {
      for (final s in [0.0, 0.5, 1.0]) {
        final a = fireflyVisual(0.5, s);
        expect(a, lessThanOrEqualTo(kFireflyPeakAlpha + 1e-9));
      }
    });

    test('全程 0.02 量化', () {
      for (final s in [0.0, 0.3, 1.0]) {
        for (double p = -0.5; p < 1.5; p += 0.013) {
          final a = fireflyVisual(p, s);
          expect(a / kFireflyAlphaStep, closeTo((a / kFireflyAlphaStep).roundToDouble(), 1e-6),
              reason: 'p=$p s=$s');
          expect(a, greaterThanOrEqualTo(0));
        }
      }
    });

    test('峰值量化后有效上限 0.08（0.09 落回 0.08 档）', () {
      expect(fireflyVisual(0.5, 1.0), 0.08);
    });

    test('相位 wrap：-0.5 与 0.5 同亮', () {
      for (final s in [0.0, 1.0]) {
        expect(fireflyVisual(-0.5, s), fireflyVisual(0.5, s));
        expect(fireflyVisual(1.5, s), fireflyVisual(0.5, s));
      }
    });

    test('同步趋同端点：平稳时（s=1）错开相位被拉向共同峰值，比紊乱时更亮',
        () {
      // 一只相位偏离 0.5 的萤火：平稳时被拉得更近峰值 -> 更亮。
      final scattered = fireflyVisual(0.1, 0.0);
      final synced = fireflyVisual(0.1, 1.0);
      expect(synced, greaterThan(scattered));
      // 反向：恰在峰值处的萤火，拉向 0.5 不衰减（0.5 是不动点）。
      expect(fireflyVisual(0.5, 0.0), fireflyVisual(0.5, 1.0));
      // 端点单调：同一相位，平稳度越高亮度越接近峰值亮度。
      for (double p = 0.0; p < 1.0; p += 0.05) {
        final lo = fireflyVisual(p, 0.0);
        final hi = fireflyVisual(p, 1.0);
        final peak = fireflyVisual(0.5, 0.0);
        expect((peak - hi).abs(), lessThanOrEqualTo((peak - lo).abs() + 1e-9));
      }
    });
  });

  group('fireflyApproach 若即若离', () {
    test('steady=0 原地不动', () {
      const cur = (x: 100.0, y: 100.0);
      final r = fireflyApproach(cur, (x: 300.0, y: 100.0), 0.0, 1000);
      expect(r.x, 100.0);
      expect(r.y, 100.0);
    });

    test('dtMs=0 原地不动', () {
      const cur = (x: 100.0, y: 100.0);
      final r = fireflyApproach(cur, (x: 300.0, y: 100.0), 1.0, 0);
      expect(r.x, 100.0);
      expect(r.y, 100.0);
    });

    test('向目标移动且每秒 ≤3px（速度封顶）', () {
      const cur = (x: 0.0, y: 0.0);
      final r = fireflyApproach(cur, (x: 500.0, y: 0.0), 1.0, 1000);
      final d = (r.x - cur.x).abs();
      expect(d, greaterThan(0));
      expect(d, lessThanOrEqualTo(kFireflyApproachMaxSpeed + 1e-9));
      expect(r.y, 0.0);
    });

    test('平稳度越低漂近越慢（2~3px/s 区间内）', () {
      const cur = (x: 0.0, y: 0.0);
      final slow = fireflyApproach(cur, (x: 500.0, y: 0.0), 0.05, 1000);
      final fast = fireflyApproach(cur, (x: 500.0, y: 0.0), 1.0, 1000);
      expect(slow.x, lessThan(fast.x));
      expect(fast.x, lessThanOrEqualTo(3.0 + 1e-9));
      expect(slow.x, greaterThan(2.0 - 1e-9));
    });

    test('距离 <60px 即停（若即若离，不贴脸）', () {
      const cur = (x: 0.0, y: 0.0);
      final r = fireflyApproach(cur, (x: 50.0, y: 0.0), 1.0, 1000);
      expect(r.x, 0.0);
      expect(r.y, 0.0);
      // 恰在 60px 也停（不进入停驻圈内）。
      final r2 = fireflyApproach(cur, (x: 60.0, y: 0.0), 1.0, 1000);
      expect(r2.x, 0.0);
    });

    test('一步不会越过停驻圈（恰好停在 60px）', () {
      const cur = (x: 0.0, y: 0.0);
      // 距离 61px，一步 3px 会越过——应恰好停在距目标 60px（x=1）。
      final r = fireflyApproach(cur, (x: 61.0, y: 0.0), 1.0, 1000);
      expect(r.x, closeTo(1.0, 1e-9));
      expect(61.0 - r.x, closeTo(kFireflyStopDistance, 1e-9));
    });

    test('纯函数：不改输入语义（记录类型不可变，连续调用结果一致）', () {
      const cur = (x: 10.0, y: 20.0);
      const tgt = (x: 400.0, y: 300.0);
      final a = fireflyApproach(cur, tgt, 1.0, 500);
      final b = fireflyApproach(cur, tgt, 1.0, 500);
      expect(a.x, b.x);
      expect(a.y, b.y);
    });
  });

  group('fireflyQuantize', () {
    test('0 与负数为 0', () {
      expect(fireflyQuantize(0), 0);
      expect(fireflyQuantize(-0.1), 0);
    });

    test('落在 0.02 步进上且不放大', () {
      for (double v = 0.001; v < 0.2; v += 0.0037) {
        final q = fireflyQuantize(v);
        final steps = q / kFireflyAlphaStep;
        expect(steps, closeTo(steps.roundToDouble(), 1e-6), reason: 'v=$v');
        expect(q, lessThanOrEqualTo(v + 1e-9), reason: 'v=$v');
      }
      expect(fireflyQuantize(0.09), 0.08); // 峰值 0.09 落回 0.08 档。
    });
  });
}
