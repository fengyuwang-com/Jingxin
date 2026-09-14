import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/abyss_glow.dart';

void main() {
  group('渊光纯函数（第 63 轮）', () {
    test('确定性：同输入同输出（多簇/多时刻扫描）', () {
      for (int i = 0; i < 8; i++) {
        for (double t = 0; t <= 3600; t += 97.0) {
          final a = abyssGlowAt(t, i, 2400, 1800);
          final b = abyssGlowAt(t, i, 2400, 1800);
          expect(a.x, b.x);
          expect(a.y, b.y);
          expect(a.phase, b.phase);
        }
      }
    });

    test('上浮速度 3~6px/s（vy 为负向上）、横向轻摆 |vx| ≤ 4px/s（多簇扫描）', () {
      for (int i = 0; i < 24; i++) {
        final s = abyssGlowAt(0, i, 2400, 1800);
        expect(
          s.vy,
          inInclusiveRange(-kAbyssGlowRiseMax, -kAbyssGlowRiseMin),
          reason: 'index=$i vy=${s.vy}',
        );
        expect(
          s.vx.abs(),
          lessThanOrEqualTo(kAbyssGlowSwaySpeedMax + 1e-9),
          reason: 'index=$i vx=${s.vx}',
        );
      }
    });

    test('簇心落在环面内（含负时间/超长时间），相位 0..1', () {
      for (int i = 0; i < 6; i++) {
        for (final t in [-500.0, -0.5, 0.0, 60.0, 86400.0]) {
          final s = abyssGlowAt(t, i, 2400, 1800);
          expect(s.x, inInclusiveRange(0.0, 2400.0), reason: 'i=$i t=$t');
          expect(s.y, inInclusiveRange(0.0, 1800.0), reason: 'i=$i t=$t');
          expect(s.phase, inInclusiveRange(0.0, 1.0), reason: 'i=$i t=$t');
        }
      }
    });

    test('时间连续性：相邻 100ms 簇心位移 < 1.1px（含跨 wrap）、相位圆差 < 0.02', () {
      for (int i = 0; i < 5; i++) {
        // 扫到 650s：最慢一簇（3px/s）也会跨一次 y 接缝，wrap 必须连续。
        var prev = abyssGlowAt(0, i, 2400, 1800);
        for (double t = 0.1; t <= 650; t += 0.1) {
          final s = abyssGlowAt(t, i, 2400, 1800);
          double d(double a, double b, double p) {
            var dd = (a - b) % p;
            if (dd > p / 2) dd -= p;
            if (dd < -p / 2) dd += p;
            return dd.abs();
          }

          double dp(double a, double b) => d(a, b, 1.0);

          expect(d(s.x, prev.x, 2400), lessThan(1.1), reason: 'i=$i t=$t');
          expect(d(s.y, prev.y, 1800), lessThan(1.1), reason: 'i=$i t=$t');
          expect(dp(s.phase, prev.phase), lessThan(0.02), reason: 'i=$i t=$t');
          prev = s;
        }
      }
    });

    test('明灭周期 8~12s；各簇相位/上浮速度/周期互异（错相）', () {
      final states = [
        for (int i = 0; i < 6; i++) abyssGlowAt(0, i, 2400, 1800),
      ];
      for (final s in states) {
        expect(
          s.phasePeriodSec,
          inInclusiveRange(kAbyssGlowPhaseMinSec, kAbyssGlowPhaseMaxSec),
        );
      }
      for (int a = 0; a < states.length; a++) {
        for (int b = a + 1; b < states.length; b++) {
          expect(
            (states[a].phase - states[b].phase).abs(),
            greaterThan(1e-9),
            reason: 'phase 错开 a=$a b=$b',
          );
          expect(
            (states[a].vy - states[b].vy).abs(),
            greaterThan(1e-9),
            reason: '上浮速度互异 a=$a b=$b',
          );
          expect(
            (states[a].phasePeriodSec - states[b].phasePeriodSec).abs(),
            greaterThan(1e-9),
            reason: '明灭周期互异 a=$a b=$b',
          );
        }
      }
    });

    test('visual 端点：平稳 0.08/1.0、紊乱 0.04/0.85，两端恰在量化网格上', () {
      final calm = abyssGlowVisual(1.0);
      // visual 自身峰值仍 0.08（第 63 轮语义不变）；总封顶 0.10 是叠加
      // 同化抬升（最多一档 0.02）后的硬上限。
      expect(calm.alpha, 0.08);
      expect(kAbyssGlowPeakAlpha, 0.10);
      expect(calm.radiusScale, 1.0);
      final rough = abyssGlowVisual(0.0);
      expect(rough.alpha, 0.04); // 0.04 恰在 0.02 网格。
      expect(rough.radiusScale, 0.85);
    });

    test('visual 全程封顶 + 0.02 量化网格 + 随平稳度单调（alpha/舒展度）', () {
      double pa = -1, pr = -1;
      for (double s = 0; s <= 1.0001; s += 0.01) {
        final v = abyssGlowVisual(s);
        expect(v.alpha, lessThanOrEqualTo(kAbyssGlowPeakAlpha + 1e-12));
        final q = v.alpha / kAbyssGlowAlphaStep;
        expect((q - q.round()).abs(), lessThan(1e-9), reason: 's=$s 不在网格');
        expect(v.alpha, greaterThanOrEqualTo(pa), reason: 'alpha 单调 s=$s');
        expect(v.radiusScale, greaterThanOrEqualTo(pr), reason: '舒展单调 s=$s');
        expect(v.radiusScale, inInclusiveRange(0.85, 1.0));
        pa = v.alpha;
        pr = v.radiusScale;
      }
    });

    test('visual 越界平稳度被夹住（负值同紊乱、>1 同平稳）', () {
      expect(abyssGlowVisual(-1).alpha, abyssGlowVisual(0).alpha);
      expect(abyssGlowVisual(2).alpha, abyssGlowVisual(1).alpha);
      expect(abyssGlowVisual(2).radiusScale, 1.0);
    });

    test('pointOffset 确定性、方向为单位向量×基础半径、界内 8~22px', () {
      for (int c = 0; c < 8; c++) {
        for (int p = 0; p < 4; p++) {
          final a = abyssGlowPointOffset(c, p);
          final b = abyssGlowPointOffset(c, p);
          expect(a.dx, b.dx);
          expect(a.dy, b.dy);
          expect(
            a.radius,
            inInclusiveRange(kAbyssGlowPointRadMin, kAbyssGlowPointRadMax),
          );
          expect(a.dx.abs(), lessThanOrEqualTo(a.radius + 1e-9));
          final norm = math.sqrt(a.dx * a.dx + a.dy * a.dy);
          expect((norm - a.radius).abs(), lessThan(1e-9));
        }
      }
      // 不同簇/点的排布方向互异（至少不全重合）。
      final s0 = abyssGlowPointOffset(0, 0);
      final s1 = abyssGlowPointOffset(1, 0);
      expect(s0.dx == s1.dx && s0.dy == s1.dy, isFalse);
    });

    test('dwell：渊内平稳累积封顶 30s、dt=0 不变', () {
      var d = 0.0;
      for (int i = 0; i < 40; i++) {
        final before = d;
        d = abyssGlowDwellNext(
          dwellSeconds: d,
          dt: 1.0,
          inAbyss: true,
          breathSteady: true,
        );
        expect(d, greaterThanOrEqualTo(before));
        expect(d, lessThanOrEqualTo(kAbyssGlowSighDwellSec + 1e-12));
      }
      expect(d, kAbyssGlowSighDwellSec);
      expect(
        abyssGlowDwellNext(
          dwellSeconds: d,
          dt: 0,
          inAbyss: true,
          breathSteady: true,
        ),
        d,
      );
    });

    test('dwell：出渊或紊乱退回、夹在 0 不为负', () {
      var d = 20.0;
      for (int i = 0; i < 60; i++) {
        d = abyssGlowDwellNext(
          dwellSeconds: d,
          dt: 1.0,
          inAbyss: i.isEven, // 交替：紊乱的那拍退回。
          breathSteady: i.isOdd,
        );
      }
      expect(d, 0.0);
      expect(
        abyssGlowDwellNext(
          dwellSeconds: 0,
          dt: 5,
          inAbyss: false,
          breathSteady: false,
        ),
        0.0,
      );
    });

    test('sigh：未触发且未开始时原样不动（闸门未耗）', () {
      const s = (progress: 0.0, done: false);
      final n = abyssGlowSighNext(state: s, trigger: false, dtSec: 10);
      expect(n.progress, 0.0);
      expect(n.done, isFalse);
    });

    test('sigh：触发后单调缓成、60s 左右到 1 停住且 done（不回退不超界）', () {
      var s = (progress: 0.0, done: false);
      s = abyssGlowSighNext(state: s, trigger: true, dtSec: 1.0);
      expect(s.progress, greaterThan(0.0));
      var prevP = s.progress;
      for (int i = 0; i < 70; i++) {
        s = abyssGlowSighNext(state: s, trigger: false, dtSec: 1.0);
        expect(s.progress, greaterThanOrEqualTo(prevP)); // 单调
        expect(s.progress, lessThanOrEqualTo(1.0)); // 封顶
        prevP = s.progress;
      }
      expect(s.done, isTrue);
      expect(s.progress, 1.0);
      expect(abyssGlowSighOffsetPx(s.progress), -kAbyssGlowSighRisePx);
    });

    test('sigh：done 后永久一次性闸门（再触发也不再动）', () {
      var s = (progress: 1.0, done: true);
      s = abyssGlowSighNext(state: s, trigger: true, dtSec: 600);
      expect(s.progress, 1.0);
      expect(s.done, isTrue);
    });

    test('sigh 偏移：0→0、1→-12 封顶、扫描单调不增（只向上不越 12px）', () {
      expect(abyssGlowSighOffsetPx(0.0), 0.0);
      expect(abyssGlowSighOffsetPx(1.0), -kAbyssGlowSighRisePx);
      expect(abyssGlowSighOffsetPx(-1), 0.0); // 越界夹住
      expect(abyssGlowSighOffsetPx(2), -kAbyssGlowSighRisePx);
      double prev = 1;
      for (double p = 0; p <= 1.0001; p += 0.01) {
        final off = abyssGlowSighOffsetPx(p);
        expect(off.abs(), lessThanOrEqualTo(kAbyssGlowSighRisePx + 1e-12));
        expect(off, lessThanOrEqualTo(prev + 1e-12)); // 单调向上（更负）
        prev = off;
      }
    });

    test('quantize：0.02 步进、向下取整不放大、负值归零', () {
      expect(abyssGlowQuantize(0.08), 0.08);
      expect(abyssGlowQuantize(0.0799), 0.06);
      expect(abyssGlowQuantize(0.021), 0.02);
      expect(abyssGlowQuantize(0.0), 0.0);
      expect(abyssGlowQuantize(-0.5), 0.0);
      expect(abyssGlowQuantize(0.123), lessThanOrEqualTo(0.123));
    });

    test('世界周期常量与游戏环面对齐', () {
      expect(kAbyssGlowWorldW, 2400.0);
      expect(kAbyssGlowWorldH, 1800.0);
    });
  });

  group('渊底心跳——同化度抬升（第 64 轮）', () {
    test('lift 端点：0→0、1→0.02（恰一档量化步进），越界夹住', () {
      expect(abyssGlowAssimilationLift(0.0), 0.0);
      expect(abyssGlowAssimilationLift(1.0), kAbyssGlowAssimLiftMax);
      expect(kAbyssGlowAssimLiftMax, 0.02);
      expect(abyssGlowAssimilationLift(-0.5), 0.0);
      expect(abyssGlowAssimilationLift(3.0), kAbyssGlowAssimLiftMax);
    });

    test('lift 单调不减、恒在 0..0.02 界内（全扫描）', () {
      double prev = -1;
      for (double a = 0; a <= 1.0001; a += 0.01) {
        final lift = abyssGlowAssimilationLift(a);
        expect(lift, inInclusiveRange(0.0, kAbyssGlowAssimLiftMax));
        expect(lift, greaterThanOrEqualTo(prev));
        prev = lift;
      }
    });

    test('lift smoothstep：中点取半峰值附近、两端导数趋 0（对称缓入缓出）', () {
      expect(abyssGlowAssimilationLift(0.5), closeTo(0.01, 1e-12));
      // smoothstep 对称：v(a)+v(1-a)=v(1)
      for (double a = 0; a <= 1.0; a += 0.07) {
        expect(
          abyssGlowAssimilationLift(a) + abyssGlowAssimilationLift(1 - a),
          closeTo(kAbyssGlowAssimLiftMax, 1e-9),
        );
      }
    });

    test('叠进 visual 后总 alpha 封顶 0.10、全程落 0.02 量化网格', () {
      expect(kAbyssGlowPeakAlpha, 0.10);
      for (double s = 0; s <= 1.0001; s += 0.05) {
        final vis = abyssGlowVisual(s);
        for (double a = 0; a <= 1.0001; a += 0.05) {
          final total = abyssGlowQuantize(vis.alpha + abyssGlowAssimilationLift(a));
          expect(total, lessThanOrEqualTo(kAbyssGlowPeakAlpha + 1e-12));
          // 恰在 0.02 网格上
          expect((total / kAbyssGlowAlphaStep).roundToDouble() * kAbyssGlowAlphaStep,
              closeTo(total, 1e-12));
          // 同化只加不减：任何平稳度下 lift 后的量化值 ≥ 未加时
          expect(total, greaterThanOrEqualTo(vis.alpha));
        }
      }
    });

    test('完全同化阈值常量 0.95；resetGate 边沿判据', () {
      expect(kAbyssGlowFullAssimilation, 0.95);
      // 首次跨到 ≥0.95 → true（触发重置）
      expect(
          abyssGlowSighResetGate(wasFullyAssimilated: false, assimilation: 0.95),
          isTrue);
      // 持续停留（上一拍已 fully）→ 保持 true，由调用方"全未叹则跳过"兜底
      expect(
          abyssGlowSighResetGate(wasFullyAssimilated: true, assimilation: 1.0),
          isTrue);
      // 退去后的第一拍 → true（收尾一次），此后重新武装
      expect(
          abyssGlowSighResetGate(wasFullyAssimilated: true, assimilation: 0.5),
          isTrue);
      expect(
          abyssGlowSighResetGate(wasFullyAssimilated: false, assimilation: 0.5),
          isFalse);
      // 未到阈值不误触
      expect(
          abyssGlowSighResetGate(wasFullyAssimilated: false, assimilation: 0.94),
          isFalse);
    });

    test('resetGate 管线模拟：calm 升到顶再退去，触发窗口有界且中断后可重武装', () {
      var was = false;
      var fired = 0;
      var windowOpen = false;
      // 上升段：0→1（每步 +0.01）
      for (double c = 0; c <= 1.0001; c += 0.01) {
        final fire = abyssGlowSighResetGate(wasFullyAssimilated: was, assimilation: c);
        if (fire && !windowOpen) {
          fired++;
          windowOpen = true;
        }
        if (!fire) windowOpen = false;
        was = c >= kAbyssGlowFullAssimilation;
      }
      // 高原段：持续 fully，窗口打开但不计新触发
      for (int i = 0; i < 50; i++) {
        final fire = abyssGlowSighResetGate(wasFullyAssimilated: was, assimilation: 1.0);
        expect(fire, isTrue); // 由调用方幂等兜底
        was = true;
      }
      // 退去段：1→0，收尾一拍关窗
      for (double c = 1.0; c >= -0.0001; c -= 0.01) {
        final fire = abyssGlowSighResetGate(wasFullyAssimilated: was, assimilation: c);
        if (fire && !windowOpen) {
          fired++;
          windowOpen = true;
        }
        if (!fire) windowOpen = false;
        was = c >= kAbyssGlowFullAssimilation;
      }
      expect(fired, 1); // 一升一落整段只算一次事件（收尾拍并入同一窗口）
      // 再次升满可重新触发
      was = false;
      var refire = false;
      for (double c = 0; c <= 1.0001; c += 0.01) {
        if (abyssGlowSighResetGate(wasFullyAssimilated: was, assimilation: c)) {
          refire = true;
          break;
        }
        was = c >= kAbyssGlowFullAssimilation;
      }
      expect(refire, isTrue);
    });
  });

  group('渊息——完全同化的一次集体呼气（第 65 轮）', () {
    test('envelope 端点：0 与 2500ms 落 0、界外归零、峰值段在 0.02 档', () {
      expect(abyssPulseEnvelope(0), 0.0);
      expect(abyssPulseEnvelope(kAbyssPulseDurationMs), 0.0);
      expect(abyssPulseEnvelope(-1), 0.0);
      expect(abyssPulseEnvelope(99999), 0.0);
      // 中点原始 sin 包络 = 峰值 0.03，量化后恰一档 0.02
      expect(abyssPulseEnvelope(kAbyssPulseDurationMs / 2), kAbyssGlowAlphaStep);
    });

    test('envelope 全程落在 0.02 量化网格上、恒 ≤ 峰值档、不放大原值', () {
      for (double t = 0; t <= kAbyssPulseDurationMs + 1; t += 7.3) {
        final e = abyssPulseEnvelope(t);
        expect(
          (e / kAbyssGlowAlphaStep).roundToDouble() * kAbyssGlowAlphaStep,
          closeTo(e, 1e-12),
          reason: 't=$t',
        );
        expect(e, lessThanOrEqualTo(kAbyssPulsePeakAlpha + 1e-12));
        // 量化是 floor：raw = 0.03·sin ≥ e（floor 不放大）
        if (t > 0 && t < kAbyssPulseDurationMs) {
          final raw = kAbyssPulsePeakAlpha *
              math.sin(math.pi * t / kAbyssPulseDurationMs);
          expect(e, lessThanOrEqualTo(raw + 1e-12));
        }
      }
    });

    test('envelope 单峰形状：先不减后不增（一个起落的呼吸形）', () {
      double prev = 0;
      var falling = false;
      for (double t = 0; t <= kAbyssPulseDurationMs; t += 5) {
        final e = abyssPulseEnvelope(t);
        if (falling) {
          expect(e, lessThanOrEqualTo(prev + 1e-12), reason: 't=$t');
        } else {
          if (e < prev - 1e-12) falling = true;
        }
        prev = e;
      }
      expect(falling, isTrue); // 确实有回落段
    });

    test('triggered 边沿：从 <0.90 跨到 ≥0.95 才 true', () {
      expect(abyssPulseTriggered(0.89, 0.95), isTrue);
      expect(abyssPulseTriggered(0.0, 1.0), isTrue);
      expect(abyssPulseTriggered(0.94, 0.96), isFalse); // calmPrev ∈ [0.90,0.95) 未武装
      expect(abyssPulseTriggered(0.95, 1.0), isFalse); // 持续高位不重复触发
      expect(abyssPulseTriggered(0.90, 1.0), isFalse); // 滞回下限含等号：须严格 <0.90
      expect(abyssPulseTriggered(0.5, 0.94), isFalse); // 未到阈值不误触
      expect(abyssPulseTriggered(0.5, 0.5), isFalse);
    });

    test('triggered 滞回防抖：缓动爬升只触发一次，回落 <0.90 后重新武装可再脉', () {
      // 模拟每秒节拍的 calm 序列（精确分数值）：0→1 →高原→退到
      // 0.84（低于重武装线 0.90）→再升满。连续慢爬时，唯一满足
      // "calmPrev <0.90 且 calmNow ≥0.95"的拍是 0.75→0.95；此后高位/
      // 退去均不再触发，直到回落到 <0.90 重新武装后再次满同化才可再脉。
      var calmPrev = 0.0;
      var fires = 0;
      void feed(double c) {
        if (abyssPulseTriggered(calmPrev, c)) fires++;
        calmPrev = c;
      }
      for (int i = 0; i <= 4; i++) {
        feed(i / 4); // 0, 0.25, 0.5, 0.75, 1.0
      }
      expect(fires, 1); // 0.75→1.0 那拍唯一触发
      for (int i = 0; i < 50; i++) {
        feed(1.0); // 高原期不再触发
      }
      expect(fires, 1);
      for (int i = 4; i >= 0; i--) {
        feed(i / 4); // 退到 0 <0.90 重新武装
      }
      expect(fires, 1); // 退去本身不触发
      for (int i = 0; i <= 4; i++) {
        feed(i / 4);
      }
      expect(fires, 2); // 再次满同化可以再脉一次（不限次）
    });

    test('triggered 跳变边沿：从低位直接跨到 ≥0.95 立即触发', () {
      // calm 快速上升（或台阶式变化）时，只要 calmPrev 仍 <0.90、calmNow
      // 已达完全同化，当拍即触发；高位持续不再触发，退到 <0.90 重新武装
      // 后可再脉。
      var calmPrev = 0.0;
      var fires = 0;
      void feed(double c) {
        if (abyssPulseTriggered(calmPrev, c)) fires++;
        calmPrev = c;
      }
      feed(0.5);
      feed(0.96); // 0.5→0.96 跳变：触发
      expect(fires, 1);
      feed(0.97);
      feed(1.0); // 高位持续不再触发
      expect(fires, 1);
      feed(0.8); // 退到 <0.90 重新武装（本身不触发）
      feed(0.95); // 再次满同化 → 再脉
      expect(fires, 2);
    });

    test('phasePull：包络 0→趋同 0、峰值→上限 0.85、单调、越界夹住', () {
      expect(abyssPulsePhasePull(0.0), 0.0);
      expect(abyssPulsePhasePull(-1), 0.0);
      expect(abyssPulsePhasePull(kAbyssPulsePeakAlpha), kAbyssPulsePhasePullMax);
      expect(abyssPulsePhasePull(99), lessThanOrEqualTo(kAbyssPulsePhasePullMax));
      double prev = -1;
      for (double e = 0; e <= kAbyssPulsePeakAlpha + 1e-9; e += 0.001) {
        final p = abyssPulsePhasePull(e);
        expect(p, inInclusiveRange(0.0, kAbyssPulsePhasePullMax));
        expect(p, greaterThanOrEqualTo(prev));
        prev = p;
      }
    });

    test('阈值常量与第 64 轮 resetGate 判据同源', () {
      expect(kAbyssPulseTriggerCalm, kAbyssGlowFullAssimilation);
      expect(kAbyssPulseRearmCalm, lessThan(kAbyssPulseTriggerCalm));
      expect(kAbyssPulseDurationMs, 2500.0);
      expect(kAbyssPulsePeakAlpha, 0.03);
    });

    test('叠进 visual+lift+脉动后总 alpha 封顶 0.12、落 0.02 网格（脉动只加档）', () {
      for (double s = 0; s <= 1.0001; s += 0.1) {
        final vis = abyssGlowVisual(s);
        for (double a = 0; a <= 1.0001; a += 0.1) {
          for (double t = 0; t <= kAbyssPulseDurationMs; t += 100) {
            final total = abyssGlowQuantize(
                vis.alpha + abyssGlowAssimilationLift(a) + abyssPulseEnvelope(t));
            // 常态封顶仍是第 64 轮的 0.10；只有渊息进行中的极短窗口
            // （量化包络 0.02 档）允许临时到 0.12，结束后自然回落。
            expect(total, lessThanOrEqualTo(kAbyssGlowPeakAlpha + kAbyssGlowAlphaStep + 1e-12));
            if (abyssPulseEnvelope(t) <= 0) {
              expect(total, lessThanOrEqualTo(kAbyssGlowPeakAlpha + 1e-12));
            }
            expect((total / kAbyssGlowAlphaStep).roundToDouble() * kAbyssGlowAlphaStep,
                closeTo(total, 1e-12));
            expect(total, greaterThanOrEqualTo(vis.alpha)); // 脉动只抬不压
          }
        }
      }
    });
  });
}
