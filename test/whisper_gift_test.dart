// 兽语签（第 33 轮）纯逻辑测试：听完的低语成为拾忆。
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/long_night_whisper.dart';
import 'package:jingxin_meditation/game/memento.dart';
import 'package:jingxin_meditation/game/shard.dart';

void main() {
  group('WhisperGift', () {
    test('成签判定：长夜仍在、未被打断、未进演出才成签', () {
      // 安静听完 8s：成签。
      expect(
        WhisperGift.shouldGift(
          touchedSince: false,
          nightActive: true,
          blocked: false,
        ),
        isTrue,
      );
      // 任何触摸打断（梦话没被听完）。
      expect(
        WhisperGift.shouldGift(
          touchedSince: true,
          nightActive: true,
          blocked: false,
        ),
        isFalse,
      );
      // 演出互斥（晨光告别 / 满醒终幕 / 开场引导）。
      expect(
        WhisperGift.shouldGift(
          touchedSince: false,
          nightActive: true,
          blocked: true,
        ),
        isFalse,
      );
      // 天亮了（长夜已结束）。
      expect(
        WhisperGift.shouldGift(
          touchedSince: false,
          nightActive: false,
          blocked: false,
        ),
        isFalse,
      );
    });
  });

  group('兽语碎片的导出与合并', () {
    ShardRecord giftRecord() => ShardRecord(
      time: DateTime.fromMillisecondsSinceEpoch(1726200000000),
      text: '困意是来接你的，不着急。',
      region: WhisperGift.region,
    );

    test('兽语碎片走 jx-memo-v1 编码/解码往返，region 原样保留', () {
      final code = MementoCodec.encode(
        shards: [giftRecord()],
        awakening: 0.42,
        beastValue: 0.3,
        beastSwimUntil: 0,
      );
      expect(code.startsWith(MementoCodec.prefix), isTrue);
      final data = MementoCodec.tryDecode(code);
      expect(data, isNotNull);
      expect(data!.shards.length, 1);
      expect(data.shards.first.text, '困意是来接你的，不着急。');
      expect(data.shards.first.region, '兽语');
      expect(data.shards.first.time.millisecondsSinceEpoch, 1726200000000);
    });

    test('解码对未知来源容错：兽语区名不炸，缺区名落兜底', () {
      // 新来源值在老格式里本就是普通字符串——可解析。
      final data = MementoCodec.tryDecode(
        MementoCodec.encode(
          shards: [giftRecord()],
          awakening: 0.1,
          beastValue: 0,
          beastSwimUntil: 0,
        ),
      );
      expect(data!.shards.first.region, '兽语');
      // 缺 region 字段：落兜底分组，不抛异常（老串可解析）。
      final bareShard = MementoCodec.tryDecode(
        MementoCodec.encode(
          shards: [
            ShardRecord(
              time: DateTime.fromMillisecondsSinceEpoch(1726200000000),
              text: '眼皮沉了。',
              region: '失眠之海',
            ),
          ],
          awakening: 0.1,
          beastValue: 0,
          beastSwimUntil: 0,
        ),
      );
      expect(bareShard!.shards.first.region, '失眠之海');
      // 坏串解析失败返回 null（容错路径本身也在测）。
      expect(MementoCodec.tryDecode('${MementoCodec.prefix}not-base64!'), isNull);
    });

    test('合并幂等：同时间戳+同偈语的兽语碎片只记一枚', () {
      final existing = <ShardRecord>[giftRecord()];
      // 重复带入同一枚（导出→导入来回多次）。
      final (m1, a1) = mergeShards(existing, [giftRecord()]);
      expect(a1, 0);
      expect(m1.length, 1);
      final (m2, a2) = mergeShards(m1, [giftRecord()]);
      expect(a2, 0);
      expect(m2.length, 1);
      // 新的一枚（不同时间戳）正常计入，added=1。
      final newer = ShardRecord(
        time: DateTime.fromMillisecondsSinceEpoch(1726200000001),
        text: '眼皮沉了。',
        region: WhisperGift.region,
      );
      final (m3, a3) = mergeShards(m2, [newer]);
      expect(a3, 1);
      expect(m3.length, 2); // 兽语签照常计入「已拾 N 枚」统计口径。
    });
  });
}
