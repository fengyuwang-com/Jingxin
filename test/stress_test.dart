// 「拾忆规模压力测试」（第 38 轮）：星图在极端数量下依然优雅。
//
// 玩家可能玩一年、碎片几百上千枚。这里用 300 / 1000 / 3000 枚碎片
// 压测三件纯逻辑事：
//   1) mergeShards 去重合并（幂等 + 耗时数量级，非 web 平台 Stopwatch）；
//   2) groupNightsByDate / countNights 分组与计数；
//   3) star_card 黄金角螺旋 3000 点全部画布内、最小星心间距不塌陷。
// 计时断言放宽到数量级（CI 上稳定，不做 flaky 的毫秒级卡尺）。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:jingxin_meditation/game/memento.dart';
import 'package:jingxin_meditation/game/memo_stats.dart';
import 'package:jingxin_meditation/game/shard.dart';
import 'package:jingxin_meditation/game/star_card.dart';

/// 构造 n 枚确定性碎片：从 2026-01-01 起，每 8 小时一枚
/// （约每夜 3 枚），禅语与区域随序号轮换。
List<ShardRecord> buildShards(int n) {
  final regions = ['失眠之海', '焦虑之渊', '疲惫荒原', '纷心雾林'];
  return List.generate(n, (i) {
    return ShardRecord(
      time: DateTime(2026, 1, 1).add(Duration(hours: 8 * i)),
      text: '偈语-$i',
      region: regions[i % regions.length],
    );
  });
}

/// 任意两枚星心的最小间距（暴力 O(n²)，3000 点 ≈ 900 万次，可承受）。
double minPairDistance(List<Offset> points) {
  var min = double.infinity;
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final dx = points[i].dx - points[j].dx;
      final dy = points[i].dy - points[j].dy;
      final d = dx * dx + dy * dy;
      if (d < min) min = d;
    }
  }
  return min <= 0 ? 0 : min;
}

void main() {
  group('mergeShards 压测（3000 × 3000）', () {
    test('3000 枚存量 + 3000 枚全新来件：全收、升序、耗时在百 ms 量级内', () {
      final existing = buildShards(3000);
      final incoming = List.generate(3000, (i) {
        return ShardRecord(
          time: DateTime(2027, 1, 1).add(Duration(hours: 8 * i)),
          text: '新篇-$i',
          region: '失眠之海',
        );
      });

      final sw = Stopwatch()..start();
      final (merged, added) = mergeShards(existing, incoming);
      sw.stop();

      expect(added, 3000);
      expect(merged.length, 6000);
      // 时间升序。
      for (var i = 1; i < merged.length; i++) {
        expect(
          merged[i].time.isBefore(merged[i - 1].time),
          isFalse,
          reason: '第 $i 枚的时间序被打乱',
        );
      }
      // 数量级断言（放宽到 2s，实测 O(n+m) 应在个位/几十 ms）。
      expect(
        sw.elapsedMilliseconds,
        lessThan(2000),
        reason: 'mergeShards 3000×3000 耗时 ${sw.elapsedMilliseconds}ms，疑似退化',
      );
    });

    test('幂等：merge(merged, merged) 一枚都不新增', () {
      final records = buildShards(3000);
      final (merged1, added1) = mergeShards(const [], records);
      expect(added1, 3000);
      final (merged2, added2) = mergeShards(merged1, merged1);
      expect(added2, 0);
      expect(merged2.length, 3000);
      // 再交叉压一遍：存量与来件同源，也不应新增。
      final (_, added3) = mergeShards(records, records);
      expect(added3, 0);
    });

    test('部分重复：3000 存量 + 1500 旧 + 1500 新 = 只收 1500', () {
      final existing = buildShards(3000);
      final mixed = [
        ...buildShards(1500), // 旧片，应全部去重。
        ...List.generate(1500, (i) {
          return ShardRecord(
            time: DateTime(2027, 6, 1).add(Duration(minutes: i)),
            text: '后来-$i',
            region: '纷心雾林',
          );
        }),
      ];
      final (merged, added) = mergeShards(existing, mixed);
      expect(added, 1500);
      expect(merged.length, 4500);
    });
  });

  group('groupNightsByDate / countNights 压测（3000 枚）', () {
    final records = buildShards(3000); // 每 8 小时一枚 → 约 1000 夜。

    test('3000 枚 → 1000 夜，组序与组内序都正确', () {
      expect(countNights(records), 1000);
      final groups = groupNightsByDate(records);
      expect(groups.length, 1000);
      // 最近的夜在最前（8h 一枚、3000 枚 = 1000 夜，末枚落在 2028-09-26）。
      expect(groups.first.dateKey, '2028-09-26');
      expect(groups.last.dateKey, '2026-01-01');
      // 组内新→旧：后一枚不得比前一枚更新。
      for (final g in groups) {
        for (var i = 1; i < g.records.length; i++) {
          expect(
            g.records[i].time.isAfter(g.records[i - 1].time),
            isFalse,
          );
        }
      }
      // 每夜恰好 3 枚（24h / 8h，首尾夜边界稳定）。
      expect(
        groups.every((g) => g.records.length == 3),
        isTrue,
        reason: '每夜应为 3 枚',
      );
    });

    test('busiestNight / nightArcSweep 在 3000 枚下正常', () {
      expect(busiestNight(records), 3);
      expect(nightArcSweep(3, 3), 6.283185307179586);
      expect(nightArcSweep(1, 3), closeTo(2 * 3.141592653589793 / 3, 1e-9));
    });
  });

  group('star_card 黄金角螺旋压测', () {
    // 星核半径 3.2（直径 6.4）；3000 枚时的向日葵盘面系数 c ≈ 4.14，
    // 理论最小星心间距约 c，留余量断言 ≥ 3.0px（星核互不吞没）。
    for (final n in [300, 1000, 3000]) {
      test('$n 枚：全部画布内，最小星心间距 ≥ 3.0px', () {
        final size = starCardSize;
        final points = List.generate(
          n,
          (i) => starCardStarOffset(i, size, total: n),
        );
        for (final p in points) {
          expect(p.dx, inInclusiveRange(0, size.width));
          expect(p.dy, inInclusiveRange(0, size.height));
        }
        final minDist = minPairDistance(points);
        expect(minDist, greaterThanOrEqualTo(3.0),
            reason: '$n 枚时最小星心间距 $minDist px，出现真重叠');
      });
    }

    test('小图不回归：≤57 枚时排布与旧版（系数 30）完全一致', () {
      final size = starCardSize;
      for (var i = 0; i < 57; i++) {
        final p = starCardStarOffset(i, size, total: 57);
        final angle = i * starCardGoldenAngle;
        // 旧版：半径 = 30·√(i+1)，57 枚以内不会触及封顶。
        final legacyRadius = 30.0 * math.sqrt(i + 1);
        expect(
          p.dx,
          closeTo(size.width / 2 + math.cos(angle) * legacyRadius, 1e-6),
        );
        expect(
          p.dy,
          closeTo(
            size.height * 0.46 + math.sin(angle) * legacyRadius * 0.82,
            1e-6,
          ),
        );
      }
    });

    test('确定性：同 (index, total) 永远同坐标', () {
      final size = starCardSize;
      for (var i = 0; i < 100; i++) {
        expect(starCardStarOffset(i, size, total: 1000),
            starCardStarOffset(i, size, total: 1000));
      }
    });
  });

  group('拾忆统计文案极端数（千位不破版）', () {
    test('N = 0：空态文案', () {
      expect(memorySummary(const []), '星图还空着，去呼吸吧');
    });

    test('N = 1：单枚单夜', () {
      final one = [
        ShardRecord(
          time: DateTime(2026, 9, 12, 23),
          text: '初光',
          region: '失眠之海',
        ),
      ];
      expect(memorySummary(one), '已拾 1 枚碎片 · 静了 1 个夜晚');
    });

    test('N = 999 / 3000：纯数字直排，无千位分隔符破版', () {
      final r999 = buildShards(999);
      final s999 = memorySummary(r999);
      expect(s999, contains('已拾 999 枚碎片'));
      expect(s999.contains(','), isFalse, reason: '不应出现千位逗号');

      final r3000 = buildShards(3000);
      final s3000 = memorySummary(r3000);
      expect(s3000, contains('已拾 3000 枚碎片'));
      expect(s3000.contains(','), isFalse);
      expect(s3000, contains('静了 1000 个夜晚'));

      // 分享卡统计行同款口径。
      expect(starCardStatsLine(r3000), s3000);
    });
  });
}
