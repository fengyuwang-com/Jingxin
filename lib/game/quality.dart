import 'package:flutter/foundation.dart';

import 'quality_meta_stub.dart'
    if (dart.library.js_interop) 'quality_meta_web.dart' as meta;

/// 画质档位（第 16 轮）——轻量的启动时自适配，不暴露任何设置 UI，
/// 绝不在界面上显示"性能模式"之类的字样。
///
/// 判定只做一次（进入静境前），各渲染组件在**构造时**读取一次参数，
/// 运行期不再分支——低档的削减是"世界本来的样子"，不是每帧的开关。
/// 判定依据：是否移动端（Web UA / 目标平台）、devicePixelRatio、
/// 浏览器报告的设备内存（navigator.deviceMemory，可能缺失）。
/// 削减原则：宁可保守——低档只砍"数量"（星、雾层、微粒、径上尘），
/// 不砍"质量"（不降分辨率、不砍机制、不改变任何回应与长线）。
enum QualityTier { low, mid, high }

class Quality {
  Quality._(this.tier);

  static Quality? _instance;

  /// 当前档位。未显式判定时默认高档（桌面/测试环境）。
  static Quality get current => _instance ??= Quality._(QualityTier.high);

  final QualityTier tier;

  bool get isLow => tier == QualityTier.low;
  bool get isHigh => tier == QualityTier.high;

  // ---- 各组件消费的削减参数（构造时读一次）----

  /// 星空背景的星数（高档 90，低档减半 45）。
  int get skyStars => switch (tier) {
        QualityTier.high => 90,
        QualityTier.mid => 64,
        QualityTier.low => 45,
      };

  /// 雾林的雾带层数（低档减一层，远层去掉——本就最淡）。
  int get fogLayers => isLow ? 2 : 3;

  /// 光灵尾迹微粒数量。
  int get spiritTrail => switch (tier) {
        QualityTier.high => 6,
        QualityTier.mid => 5,
        QualityTier.low => 3,
      };

  /// 光灵环绕微粒数量。
  int get orbParticles => switch (tier) {
        QualityTier.high => 18,
        QualityTier.mid => 14,
        QualityTier.low => 10,
      };

  /// 静之径的径上尘数量。
  int get pathDust => switch (tier) {
        QualityTier.high => 10,
        QualityTier.mid => 8,
        QualityTier.low => 5,
      };

  /// 失眠之海的近景星屑数量。
  int get seaMotes => switch (tier) {
        QualityTier.high => 26,
        QualityTier.mid => 20,
        QualityTier.low => 14,
      };

  /// 夜雨雨丝上限。
  int get rainDrops => switch (tier) {
        QualityTier.high => 18,
        QualityTier.mid => 14,
        QualityTier.low => 10,
      };

  /// 启动时判定一次。UI 层在构造游戏前调用。
  /// [dpr] 传设备像素比（Web 用 implicitView.devicePixelRatio）。
  static void detect({double? dpr, String? userAgent}) {
    final ua = userAgent ?? meta.userAgent();
    final mem = meta.deviceMemoryGB();

    final bool mobile;
    if (ua != null) {
      mobile =
          RegExp(r'android|iphone|ipad|ipod|mobile', caseSensitive: false)
              .hasMatch(ua);
    } else {
      // 非 Web：按目标平台粗判。
      mobile = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }

    final QualityTier tier;
    if (!mobile) {
      tier = QualityTier.high;
    } else if (ua == null) {
      // 非 Web 的移动平台（Android/iOS 原生壳）：无内存线索，保守低档。
      tier = QualityTier.low;
    } else if (mem != null && mem <= 4) {
      // 低内存安卓（navigator.deviceMemory 报告 ≤4GB）。
      tier = QualityTier.low;
    } else if (mem == null && (dpr ?? 1) >= 3.2) {
      // 拿不到内存线索的高 DPR 移动端，保守降一档。
      tier = QualityTier.low;
    } else {
      tier = QualityTier.mid;
    }
    _instance = Quality._(tier);
  }

  /// 仅供测试：重置为未判定状态。
  static void resetForTest() => _instance = null;
}
