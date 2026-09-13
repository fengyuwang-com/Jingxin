// 星花映境（第 56 轮）：regionAtPoint 纯函数 + 六心境调色 + 同区微差。
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/game/breath_flower.dart';
import 'package:jingxin_meditation/game/regions.dart';

void main() {
  group('regionAtPoint（点在哪个区域，wrap 环面）', () {
    const w = 2400.0;
    const h = 1800.0;

    test('四个深度带的基本归属', () {
      expect(GameRegion.regionAtPoint(w / 2, h * 0.9).name, '焦虑之渊');
      expect(GameRegion.regionAtPoint(w / 2, h * 0.5).name, '失眠之海');
      expect(GameRegion.regionAtPoint(w / 2, h * 0.1).name, '疲惫荒原');
      // 雾林：x 接缝两侧、纵向门带内。
      expect(GameRegion.regionAtPoint(30, h * 0.5).name, '纷心雾林');
      expect(GameRegion.regionAtPoint(w - 30, h * 0.5).name, '纷心雾林');
    });

    test('负坐标 / 超界坐标环绕落回（环面 wrap）', () {
      expect(GameRegion.regionAtPoint(-30, h * 0.5).name, '纷心雾林');
      expect(GameRegion.regionAtPoint(w + 30, h * 0.5).name, '纷心雾林');
      // 负 y wrap 后落回上方（-0.95 → 0.05 → 荒原带）。
      expect(GameRegion.regionAtPoint(w / 2, -0.95 * h).name, '疲惫荒原');
      expect(GameRegion.regionAtPoint(w / 2, h + 0.9 * h).name, '焦虑之渊');
      expect(GameRegion.regionAtPoint(3 * w + 1200, 2 * h + 900).name,
          '失眠之海');
    });

    test('深度带边界点（恰在 depthStart/depthFull 上）', () {
      expect(GameRegion.regionAtPoint(w / 2, 0.80 * h).name, '焦虑之渊');
      expect(GameRegion.regionAtPoint(w / 2, 0.79 * h).name, '失眠之海');
      expect(GameRegion.regionAtPoint(w / 2, 0.18 * h).name, '疲惫荒原');
      expect(GameRegion.regionAtPoint(w / 2, 0.19 * h).name, '失眠之海');
    });

    test('雾林纵向门带边界（带外回落海）', () {
      expect(GameRegion.regionAtPoint(30, 0.28 * h).name, '纷心雾林');
      expect(GameRegion.regionAtPoint(30, 0.72 * h).name, '纷心雾林');
      expect(GameRegion.regionAtPoint(30, 0.27 * h).name, '失眠之海');
      expect(GameRegion.regionAtPoint(30, 0.75 * h).name, '失眠之海');
    });

    test('regionAt 与 regionAtPoint 一致', () {
      final p = GameRegion.regionAtPoint(123.0, 1555.0);
      expect(GameRegion.regionAt(Vector2(123, 1555)).name, p.name);
    });
  });

  group('六心境花调色 flowerPaletteFor', () {
    test('六心境花瓣色互不相同且确定性', () {
      final moods = FlowerMood.values;
      expect(moods.length, 6);
      for (final m in moods) {
        final a = flowerPaletteFor(m);
        final b = flowerPaletteFor(m);
        expect(a.petal, b.petal);
        expect(a.core, b.core);
        expect(a.petalAdjust, b.petalAdjust);
      }
      final petals = moods.map((m) => flowerPaletteFor(m).petal).toSet();
      expect(petals.length, 6, reason: '六区域花瓣色应互不相同');
    });

    test('瓣形微调在 -1..1（克制，不颠覆基础瓣数）', () {
      for (final m in FlowerMood.values) {
        final adj = flowerPaletteFor(m).petalAdjust;
        expect(adj >= -1 && adj <= 1, isTrue);
      }
    });

    test('全部低饱和 CYBER-ZEN：花瓣色饱和度有上限、非纯白纯黑', () {
      for (final m in FlowerMood.values) {
        final c = flowerPaletteFor(m).petal;
        final hsl = HSLColor.fromColor(c);
        expect(hsl.saturation, lessThan(0.75), reason: '$m 不应刺眼');
        expect(hsl.lightness, inInclusiveRange(0.3, 0.85));
      }
    });
  });

  group('同区微差 flowerKinVariance', () {
    test('确定性：同 seed 同结果', () {
      final a = flowerKinVariance(12345);
      final b = flowerKinVariance(12345);
      expect(a, b);
    });

    test('亮度在 0.84..1.0、相位在 0..2π', () {
      for (int s = 0; s < 500; s++) {
        final (brighten, phase) = flowerKinVariance(s);
        expect(brighten, inInclusiveRange(0.84, 1.0));
        expect(phase, inInclusiveRange(0, 3.141592653589793 * 2));
      }
    });

    test('不同 seed 有足够分散（避免整齐划一）', () {
      final brights = <double>{};
      for (int s = 0; s < 200; s++) {
        brights.add(flowerKinVariance(s).$1);
      }
      expect(brights.length, greaterThan(50));
    });
  });
}
