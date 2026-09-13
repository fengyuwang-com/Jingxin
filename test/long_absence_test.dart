import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/long_absence.dart';

void main() {
  DateTime dt(String s) => LongAbsenceJudgement.parseStamp(s)!;

  group('LongAbsenceJudgement.parseStamp（损坏字符串兜底）', () {
    test('null 与空串安全返回 null', () {
      expect(LongAbsenceJudgement.parseStamp(null), isNull);
      expect(LongAbsenceJudgement.parseStamp(''), isNull);
    });

    test('长度不对 / 含非数字一律 null', () {
      expect(LongAbsenceJudgement.parseStamp('20260914'), isNull);
      expect(LongAbsenceJudgement.parseStamp('2026091412000'), isNull);
      expect(LongAbsenceJudgement.parseStamp('2026-09-14 12:00'), isNull);
      expect(LongAbsenceJudgement.parseStamp('20260914ab00'), isNull);
      expect(LongAbsenceJudgement.parseStamp('二零二六年九月'), isNull);
    });

    test('不存在的日期（溢出回卷）判 null', () {
      expect(LongAbsenceJudgement.parseStamp('202613011200'), isNull); // 13 月
      expect(LongAbsenceJudgement.parseStamp('202609321200'), isNull); // 32 日
      expect(LongAbsenceJudgement.parseStamp('202602301200'), isNull); // 2/30
      expect(LongAbsenceJudgement.parseStamp('202609141260'), isNull); // 61 分
    });

    test('合法时刻解析正确（含月末/年末）', () {
      expect(
        LongAbsenceJudgement.parseStamp('202609141235'),
        DateTime(2026, 9, 14, 12, 35),
      );
      expect(
        LongAbsenceJudgement.parseStamp('202612312359'),
        DateTime(2026, 12, 31, 23, 59),
      );
    });

    test('formatStamp 与 parseStamp 往返一致（补零）', () {
      const stamp = '202601050803';
      expect(
        LongAbsenceJudgement.formatStamp(LongAbsenceJudgement.parseStamp(stamp)!),
        stamp,
      );
      expect(
        LongAbsenceJudgement.formatStamp(DateTime(2026, 9, 14, 7, 5)),
        '202609140705',
      );
    });
  });

  group('LongAbsenceJudgement.evaluate', () {
    test('无键首次：不触发（首次归开场引导招呼）', () {
      final v = LongAbsenceJudgement.evaluate(lastStamp: null, now: dt('202609141200'));
      expect(v.triggered, isFalse);
      expect(v.days, 0);
    });

    test('不足 72 小时：不触发', () {
      final v = LongAbsenceJudgement.evaluate(
        lastStamp: '202609120000',
        now: dt('202609141159'),
      );
      expect(v.triggered, isFalse);
      expect(v.days, 0);
    });

    test('=72 小时整点边界：触发，days=3', () {
      final v = LongAbsenceJudgement.evaluate(
        lastStamp: '202609111200',
        now: dt('202609141200'),
      );
      expect(v.triggered, isTrue);
      expect(v.days, 3);
    });

    test('超过 72 小时：触发，days 按 24h 完整天数取整', () {
      final v = LongAbsenceJudgement.evaluate(
        lastStamp: '202609100000',
        now: dt('202609140901'),
      );
      expect(v.triggered, isTrue);
      expect(v.days, 4); // 4 天 9 小时 -> 完整 4 天
    });

    test('跨月（且跨 31 天长短月）判定正确', () {
      // 1 月 29 日 12:00 -> 2 月 1 日 12:00 恰好 72 小时（31 天月）。
      final jan = LongAbsenceJudgement.evaluate(
        lastStamp: '202601291200',
        now: dt('202602011200'),
      );
      expect(jan.triggered, isTrue);
      expect(jan.days, 3);

      // 2 月 27 日 -> 3 月 1 日（2026 非闰年，2 月 28 天）：57 小时，不触发。
      final feb = LongAbsenceJudgement.evaluate(
        lastStamp: '202602270300',
        now: dt('202603011200'),
      );
      expect(feb.triggered, isFalse);
    });

    test('跨年边界判定正确', () {
      final v = LongAbsenceJudgement.evaluate(
        lastStamp: '202512311200',
        now: dt('202601031200'),
      );
      expect(v.triggered, isTrue);
      expect(v.days, 3);
    });

    test('损坏时刻串兜底：视作从未记录，不触发', () {
      for (final bad in ['abc', '', '999999999999', '2026-09-14', '20260914 12:0']) {
        final v = LongAbsenceJudgement.evaluate(lastStamp: bad, now: dt('202609141200'));
        expect(v.triggered, isFalse, reason: '损坏串 "$bad" 不应触发');
      }
    });

    test('未来时刻（时钟回拨）：间隔为负，不触发', () {
      final v = LongAbsenceJudgement.evaluate(
        lastStamp: '202609201200',
        now: dt('202609141200'),
      );
      expect(v.triggered, isFalse);
    });
  });
}
