import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/quality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Quality.resetForTest);

  group('画质档位判定（第 16 轮）', () {
    test('桌面 UA → 高档全量', () {
      Quality.detect(dpr: 1.0, userAgent: 'Mozilla/5.0 (Windows NT 10.0)');
      expect(Quality.current.tier, QualityTier.high);
      expect(Quality.current.skyStars, 90);
      expect(Quality.current.fogLayers, 3);
      expect(Quality.current.spiritTrail, 6);
      expect(Quality.current.pathDust, 10);
    });

    test('低内存安卓 → 低档：星空减半、雾层/微粒削减', () {
      Quality.detect(dpr: 3.5, userAgent: 'Android 13; Pixel', );
      // 无 deviceMemory 线索时按高 DPR 保守降档。
      expect(Quality.current.tier, QualityTier.low);
      expect(Quality.current.skyStars, 45); // 减半
      expect(Quality.current.fogLayers, 2); // 减一层
      expect(Quality.current.spiritTrail, lessThan(6));
      expect(Quality.current.pathDust, lessThan(10));
      expect(Quality.current.orbParticles, lessThan(18));
    });

    test('普通移动端 → 中档（保守削减）', () {
      // Web UA + 无法判定内存但 dpr 不极端 → mid。
      Quality.detect(dpr: 2.0, userAgent: 'iPhone');
      expect(Quality.current.tier, QualityTier.mid);
      expect(Quality.current.skyStars, 64);
      expect(Quality.current.fogLayers, 3); // 中档不减雾层
    });

    test('未判定时默认高档（桌面/测试环境安全）', () {
      expect(Quality.current.tier, QualityTier.high);
    });

    test('非 Web 移动平台（Android/iOS 目标）→ 削减档', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      Quality.detect(dpr: 2.75);
      expect(Quality.current.tier, QualityTier.low);
    });
  });
}
