import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/abyss_glow.dart';
import 'package:jingxin_meditation/game/firefly_gleam.dart';
import 'package:jingxin_meditation/game/night_settle.dart';

/// 长夜沉底（第 66 轮）：四环境层集体收束的纯函数单测。
///
/// 语义边界同步锁死：本层不产生任何 alpha 量化端点——各映射函数的值域、
/// 单调性、连续性在这里验证；alpha 让位仍归各层原 nightYield 公式管。
void main() {
  group('nightSettleFactor 沉底程度', () {
    test('端点：nightAmount ≤ 起点 → 0，≥ 终点 → 1', () {
      expect(nightSettleFactor(0.0), 0.0);
      expect(nightSettleFactor(kNightSettleStart), 0.0);
      expect(nightSettleFactor(kNightSettleEnd), 1.0);
      expect(nightSettleFactor(1.0), 1.0);
    });

    test('越界夹住：负值与 >1 均按 [0,1] 处理', () {
      expect(nightSettleFactor(-3.0), 0.0);
      expect(nightSettleFactor(5.0), 1.0);
      expect(nightSettleFactor(double.infinity), 1.0);
      expect(nightSettleFactor(double.negativeInfinity), 0.0);
    });

    test('NaN 防御：视为 0（黎明前世界不该因脏数据直接沉底）', () {
      expect(nightSettleFactor(double.nan), 0.0);
    });

    test('单调不减：0..1 全扫描步长 0.001', () {
      var prev = -1.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleFactor(n);
        expect(v, greaterThanOrEqualTo(prev - 1e-12), reason: 'n=$n');
        expect(v, inInclusiveRange(0.0, 1.0));
        prev = v;
      }
    });

    test('smoothstep 零导数两端：起点/终点附近差分趋 0（缓入缓出）', () {
      const eps = 1e-4;
      // 起点侧：刚进入沉底窗口时增量应远小于中段同宽增量。
      final startSlope = nightSettleFactor(kNightSettleStart + eps) / eps;
      final midSlope =
          (nightSettleFactor(0.8 + eps) - nightSettleFactor(0.8 - eps)) /
              (2 * eps);
      final endSlope = (1.0 - nightSettleFactor(kNightSettleEnd - eps)) / eps;
      expect(startSlope, lessThan(midSlope * 0.05));
      expect(endSlope, lessThan(midSlope * 0.05));
    });

    test('起点前恒 0、终点后恒 1（分段平坦）', () {
      for (final n in [0.0, 0.1, 0.3, 0.499]) {
        expect(nightSettleFactor(n), 0.0, reason: 'n=$n');
      }
      for (final n in [0.951, 0.97, 0.99, 1.0]) {
        expect(nightSettleFactor(n), 1.0, reason: 'n=$n');
      }
    });
  });

  group('各层映射函数：值域与单调', () {
    test('星潮振幅乘子：1→0.15 单调递减，越界输入夹住', () {
      expect(nightSettleSeaAmpScale(0.0), 1.0);
      expect(nightSettleSeaAmpScale(kNightSettleStart), 1.0);
      expect(nightSettleSeaAmpScale(1.0), closeTo(0.15, 1e-12));
      expect(nightSettleSeaAmpScale(-2.0), 1.0);
      expect(nightSettleSeaAmpScale(9.0), closeTo(0.15, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleSeaAmpScale(n);
        expect(v, inInclusiveRange(0.15 - 1e-12, 1.0), reason: 'n=$n');
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('渊光下沉位移：0→8px 非负单调递增，上限 ≤10px', () {
      expect(nightSettleAbyssDyPx(0.0), 0.0);
      expect(nightSettleAbyssDyPx(0.4), 0.0);
      expect(nightSettleAbyssDyPx(1.0), closeTo(8.0, 1e-12));
      expect(nightSettleAbyssDyPx(-1.0), 0.0);
      var prev = -1.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleAbyssDyPx(n);
        expect(v, inInclusiveRange(0.0, 10.0), reason: 'n=$n');
        expect(v, greaterThanOrEqualTo(prev - 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('渊光上浮速度乘子：1→0.25 单调递减（不想再浮了，不是掉下去）', () {
      expect(nightSettleAbyssRiseScale(0.0), 1.0);
      expect(nightSettleAbyssRiseScale(1.0), closeTo(0.25, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleAbyssRiseScale(n);
        expect(v, inInclusiveRange(0.25 - 1e-12, 1.0), reason: 'n=$n');
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('风痕流速乘子：1→0.08 单调递减（近乎凝滞但不为 0）', () {
      expect(nightSettleWindSpeedScale(0.0), 1.0);
      expect(nightSettleWindSpeedScale(1.0), closeTo(0.08, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleWindSpeedScale(n);
        expect(v, inInclusiveRange(0.08 - 1e-12, 1.0), reason: 'n=$n');
        expect(v, greaterThan(0.0), reason: 'n=$n 风渐止而非骤停');
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('风痕长度乘子：1→0.25 单调递减', () {
      expect(nightSettleWindLengthScale(0.0), 1.0);
      expect(nightSettleWindLengthScale(1.0), closeTo(0.25, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleWindLengthScale(n);
        expect(v, inInclusiveRange(0.25 - 1e-12, 1.0), reason: 'n=$n');
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('萤迹漂移乘子：1→0.15 单调递减', () {
      expect(nightSettleFireflyDriftScale(0.0), 1.0);
      expect(nightSettleFireflyDriftScale(1.0), closeTo(0.15, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleFireflyDriftScale(n);
        expect(v, inInclusiveRange(0.15 - 1e-12, 1.0), reason: 'n=$n');
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });

    test('萤迹包络下限：0.35→0.10 单调递减且恒 <1（眯眼不熄灭）', () {
      expect(nightSettleFireflyGlowFloor(0.0), closeTo(0.35, 1e-12));
      expect(nightSettleFireflyGlowFloor(1.0), closeTo(0.10, 1e-12));
      var prev = 2.0;
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.001) {
        final v = nightSettleFireflyGlowFloor(n);
        expect(v, inInclusiveRange(0.10 - 1e-12, 0.35 + 1e-12),
            reason: 'n=$n');
        expect(v, lessThan(1.0));
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: 'n=$n');
        prev = v;
      }
    });
  });

  group('连续性与对称', () {
    test('全部映射在 0..1 上相邻采样 |Δ| 极小（无跳变）', () {
      final fns = <double Function(double)>[
        nightSettleSeaAmpScale,
        nightSettleAbyssDyPx,
        nightSettleAbyssRiseScale,
        nightSettleWindSpeedScale,
        nightSettleWindLengthScale,
        nightSettleFireflyDriftScale,
        nightSettleFireflyGlowFloor,
      ];
      for (final fn in fns) {
        var prev = fn(0.0);
        for (double n = 0.001; n <= 1.0 + 1e-9; n += 0.001) {
          final v = fn(n);
          expect((v - prev).abs(), lessThan(0.03), reason: 'n=$n 跳变');
          prev = v;
        }
      }
    });

    test('smoothstep 中点对称：f(a)+f(1-a)=1（t 空间中心 0.5）', () {
      final center = (kNightSettleStart + kNightSettleEnd) / 2;
      expect(nightSettleFactor(center), closeTo(0.5, 1e-12));
      for (final d in [0.05, 0.1, 0.15, 0.2]) {
        expect(
          nightSettleFactor(center - d) + nightSettleFactor(center + d),
          closeTo(1.0, 1e-9),
          reason: 'd=$d',
        );
      }
    });
  });

  group('接入点行为（签名扩展向后兼容）', () {
    test('fireflyVisual 默认 glowFloor=0 与旧行为逐点一致', () {
      for (final s in [0.0, 0.4, 1.0]) {
        for (double p = -0.5; p < 1.5; p += 0.02) {
          expect(
            fireflyVisual(p, s, glowFloor: 0.0),
            fireflyVisual(p, s),
            reason: 'p=$p s=$s',
          );
        }
      }
    });

    test('fireflyVisual 包络下限抬升：谷更亮、峰不变（封顶不放大）', () {
      // 相位 0 = 包络谷底：floor 越高越亮（趋低亮度包络 ≠ 熄灭）。
      final bare = fireflyVisual(0.0, 1.0);
      final settled = fireflyVisual(0.0, 1.0, glowFloor: 0.35);
      expect(settled, greaterThanOrEqualTo(bare));
      // 峰值处 floor 不放大：仍为封顶档。
      expect(fireflyVisual(0.5, 1.0, glowFloor: 0.35),
          fireflyVisual(0.5, 1.0));
      // 全程仍在 0..封顶内且不超原峰。
      for (final f in [0.1, 0.22, 0.35]) {
        for (double p = 0.0; p < 1.0; p += 0.017) {
          final a = fireflyVisual(p, 0.7, glowFloor: f);
          expect(a, inInclusiveRange(0.0, kFireflyPeakAlpha + 1e-9),
              reason: 'p=$p f=$f');
          expect(
            a / kFireflyAlphaStep,
            closeTo((a / kFireflyAlphaStep).roundToDouble(), 1e-6),
            reason: 'p=$p f=$f 量化格',
          );
        }
      }
    });

    test('abyssGlowAt riseTimeSec 缺省 = tSec（向后兼容），只影响 y 行程', () {
      for (int i = 0; i < 6; i++) {
        final a = abyssGlowAt(123.4, i, 2400, 1800);
        final b = abyssGlowAt(123.4, i, 2400, 1800, riseTimeSec: 123.4);
        expect(a.y, b.y);
        expect(a.x, b.x);
        expect(a.phase, b.phase);
        // 减速等效时间：y 上浮行程缩短（_fract 线性缩放的确定性验证用
        // 小时间窗，避免环面 wrap 干扰）。
        final slow = abyssGlowAt(123.4, i, 2400, 1800, riseTimeSec: 0.0);
        final base = abyssGlowAt(0.0, i, 2400, 1800);
        expect(slow.y, base.y);
        // 相位与 x 摆不受 riseTimeSec 影响（本增量不动明灭推进）。
        final c = abyssGlowAt(123.4, i, 2400, 1800, riseTimeSec: 60.0);
        expect(c.x, a.x);
        expect(c.phase, a.phase);
        expect(c.vy, a.vy); // vy 为本征速度，供渲染层再乘系数。
      }
    });
  });

  group('本层不参与 alpha 量化（语义锁）', () {
    test('所有映射输出均为连续系数/像素偏移，不落 0.02 alpha 网格语义', () {
      // 沉底终点的各乘子端值刻意取非 0.02 整倍数值（0.15/0.25/0.08/…）：
      // 它们是运动系数，若被误当 alpha 用即违反设计——这里锁死其值。
      expect(nightSettleSeaAmpScale(1.0), isNot(0.0));
      expect(nightSettleWindSpeedScale(1.0), closeTo(0.08, 1e-12));
      expect(nightSettleFireflyGlowFloor(1.0), closeTo(0.10, 1e-12));
      // 且绝不返回负值或 >1 的"系数"（dy 除外，它是 px 偏移）。
      for (double n = 0.0; n <= 1.0 + 1e-9; n += 0.01) {
        expect(nightSettleSeaAmpScale(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleAbyssRiseScale(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleWindSpeedScale(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleWindLengthScale(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleFireflyDriftScale(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleFireflyGlowFloor(n), inInclusiveRange(0.0, 1.0));
        expect(nightSettleAbyssDyPx(n), inInclusiveRange(0.0, 10.0));
      }
    });
  });
}
