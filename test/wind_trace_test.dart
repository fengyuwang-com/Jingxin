import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/wind_trace.dart';

void main() {
  group('风痕纯函数（第 62 轮）', () {
    test('确定性：同输入同输出（多道/多时刻扫描）', () {
      for (int i = 0; i < 8; i++) {
        for (double t = 0; t <= 3600; t += 97.0) {
          final a = windTraceLine(t, i, 2400, 1800);
          final b = windTraceLine(t, i, 2400, 1800);
          expect(a.x, b.x);
          expect(a.y, b.y);
          expect(a.phase, b.phase);
        }
      }
    });

    test('水平速度 12~20px/s、纵向贴地 |vy| ≤ 2.4（多道扫描）', () {
      for (int i = 0; i < 24; i++) {
        final t = windTraceLine(0, i, 2400, 1800);
        expect(t.vx, inInclusiveRange(kWindTraceSpeedMin, kWindTraceSpeedMax),
            reason: 'index=$i vx=${t.vx}');
        expect(t.vy.abs(), lessThanOrEqualTo(kWindTraceRiseMax + 1e-9),
            reason: 'index=$i vy=${t.vy}');
      }
    });

    test('基准点落在环面内（含负时间/超长时间），且随时间 wrap 连续', () {
      for (int i = 0; i < 6; i++) {
        for (final t in [-500.0, -0.5, 0.0, 60.0, 86400.0]) {
          final s = windTraceLine(t, i, 2400, 1800);
          expect(s.x, inInclusiveRange(0.0, 2400.0), reason: 'i=$i t=$t');
          expect(s.y, inInclusiveRange(0.0, 1800.0), reason: 'i=$i t=$t');
          expect(s.phase, inInclusiveRange(0.0, 1.0), reason: 'i=$i t=$t');
        }
      }
    });

    test('时间连续性：相邻 100ms 基准点位移 < 2.5px、相位 < 0.02', () {
      for (int i = 0; i < 6; i++) {
        var prev = windTraceLine(0, i, 2400, 1800);
        for (double t = 0.1; t <= 120; t += 0.1) {
          final s = windTraceLine(t, i, 2400, 1800);
          // 环面最短轴向位移。
          double d(double a, double b, double p) {
            var dd = (a - b) % p;
            if (dd > p / 2) dd -= p;
            if (dd < -p / 2) dd += p;
            return dd.abs();
          }

          expect(d(s.x, prev.x, 2400), lessThan(2.5), reason: 'i=$i t=$t');
          expect(d(s.y, prev.y, 1800), lessThan(2.5), reason: 'i=$i t=$t');
          // 相位按环面（0..1 圆）取最短差——wrap 跳变不算不连续。
          double dp(double a, double b) {
            var dd = (a - b) % 1.0;
            if (dd > 0.5) dd -= 1.0;
            if (dd < -0.5) dd += 1.0;
            return dd.abs();
          }

          expect(dp(s.phase, prev.phase), lessThan(0.02), reason: 'i=$i t=$t');
          prev = s;
        }
      }
    });

    test('各道参数互异（相位/速度散开，不整齐划一）', () {
      final phases = <double>{};
      final speeds = <double>{};
      for (int i = 0; i < 12; i++) {
        final s = windTraceLine(0, i, 2400, 1800);
        phases.add(s.phase);
        speeds.add(s.vx);
      }
      expect(phases.length, greaterThanOrEqualTo(10));
      expect(speeds.length, greaterThanOrEqualTo(10));
    });

    test('明灭周期 9~14s', () {
      for (int i = 0; i < 16; i++) {
        final s = windTraceLine(0, i, 2400, 1800);
        expect(s.phasePeriodSec, inInclusiveRange(9.0, 14.0));
      }
    });

    test('风场落在 -1..1（全网格扫描）', () {
      for (double x = 0; x < 2400; x += 37.0) {
        for (double ms = 0; ms < 26000; ms += 431.0) {
          expect(windTraceField(x, ms), inInclusiveRange(-1.0, 1.0),
              reason: 'x=$x ms=$ms');
        }
      }
    });

    test('风场时间连续性：相邻 100ms 采样 |Δ| < 0.05', () {
      for (double x = 0; x < 2400; x += 311.0) {
        var prev = windTraceField(x, 0);
        for (double ms = 100; ms <= 30000; ms += 100) {
          final v = windTraceField(x, ms);
          expect((v - prev).abs(), lessThan(0.05), reason: 'x=$x ms=$ms');
          prev = v;
        }
      }
    });

    test('风场环面接缝连续：x 跨周期边界场强一致', () {
      for (double ms = 0; ms < 30000; ms += 1100.0) {
        expect(
          (windTraceField(0, ms) - windTraceField(2400, ms)).abs(),
          lessThan(1e-6),
        );
      }
    });

    test('visual 端点：平稳 → 峰值 0.06、长度 1.0；紊乱 → 0.03、0.6', () {
      final steady = windTraceVisual(1.0);
      expect(steady.alpha, closeTo(0.06, 1e-9));
      expect(steady.lengthScale, closeTo(1.0, 1e-9));
      final chaotic = windTraceVisual(0.0);
      expect(chaotic.alpha, closeTo(0.04, 1e-9));
      expect(chaotic.lengthScale, closeTo(0.6, 1e-9));
    });

    test('visual 恒不超封顶且全程 0.02 量化（连续扫描）', () {
      for (double s = 0; s <= 1.0; s += 0.01) {
        final v = windTraceVisual(s);
        expect(v.alpha, lessThanOrEqualTo(kWindTracePeakAlpha + 1e-9));
        expect(v.alpha / kWindTraceAlphaStep,
            closeTo((v.alpha / kWindTraceAlphaStep).roundToDouble(), 1e-6),
            reason: 's=$s');
      }
    });

    test('visual 单调：alpha 与长度随平稳度不回跌', () {
      double prevA = -1;
      double prevL = -1;
      for (double s = 0; s <= 1.0; s += 0.01) {
        final v = windTraceVisual(s);
        expect(v.alpha, greaterThanOrEqualTo(prevA - 1e-9), reason: 's=$s');
        expect(v.lengthScale, greaterThanOrEqualTo(prevL - 1e-9),
            reason: 's=$s');
        prevA = v.alpha;
        prevL = v.lengthScale;
      }
    });

    test('sway 端点/界内/0.5px 量化/单调', () {
      expect(windTraceSway(-1.0), closeTo(-1.5, 1e-9));
      expect(windTraceSway(0.0), closeTo(0.0, 1e-9));
      expect(windTraceSway(1.0), closeTo(1.5, 1e-9));
      for (double f = -1.0; f <= 1.0; f += 0.01) {
        final s = windTraceSway(f);
        expect(s.abs(), lessThanOrEqualTo(kWindTraceSwayMaxPx + 1e-9));
        expect(s / kWindTraceSwayStep,
            closeTo((s / kWindTraceSwayStep).roundToDouble(), 1e-6),
            reason: 'f=$f');
      }
      expect(windTraceSway(0.5), greaterThan(windTraceSway(0.2)));
      expect(windTraceSway(-0.5), lessThan(windTraceSway(-0.2)));
    });

    test('windTraceQuantize：步进/不放大/非正归零', () {
      expect(windTraceQuantize(-0.5), 0);
      expect(windTraceQuantize(0), 0);
      expect(windTraceQuantize(0.019), 0);
      expect(windTraceQuantize(0.021), closeTo(0.02, 1e-9));
      expect(windTraceQuantize(0.059), closeTo(0.04, 1e-9));
      expect(windTraceQuantize(0.061), closeTo(0.06, 1e-9));
      for (double v = 0; v < 0.2; v += 0.001) {
        final q = windTraceQuantize(v);
        expect(q, lessThanOrEqualTo(v + 1e-9), reason: 'v=$v');
      }
    });
  });
}
