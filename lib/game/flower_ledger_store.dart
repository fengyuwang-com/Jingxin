/// 花境图鉴的持久化（第 58 轮）：`jingxin.flowerledger.v1`。
///
/// 只增不减的花之账——每次花开对应区域 +1，节流写盘（默认每 30s
/// 至多一次，避免频繁 IO）。**账本是独立的温和回顾，不参与任何
/// 经济/进度系统**（星花不给碎片不给分数是既定设计）。花谢不扣账。
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'breath_flower.dart';

/// 花境账本存取：初始化时读一次，花开时记一笔，节流落盘。
class FlowerLedgerStore {
  FlowerLedgerStore({this.saveIntervalSeconds = 30.0});

  /// 写盘节流间隔（秒）。
  final double saveIntervalSeconds;

  static const String prefKey = 'jingxin.flowerledger.v1';

  FlowerLedger _ledger = flowerLedgerNew();
  bool _loaded = false;
  bool _dirty = false;
  double _sinceSave = 0;

  /// 当前账本（只读视图；bump 会整体替换，外部不会看到中途态）。
  FlowerLedger get ledger => _ledger;

  bool get loaded => _loaded;

  /// 初始化：读一次盘（脏数据容错全 0，见 [flowerLedgerDecode]）。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ledger = flowerLedgerDecode(prefs.getString(prefKey) ?? '');
    _loaded = true;
  }

  /// 记一笔花开（对应心境区域 +1）。只增不减，花谢不扣账。
  void bump(int region) {
    _ledger = flowerLedgerBump(_ledger, region);
    _dirty = true;
  }

  /// 帧节拍（游戏层每帧调用）：距上次落盘超过节流间隔且账本有变，
  /// 才写一次盘——花开不频繁，平时几乎零 IO。
  Future<void> tick(double dt) async {
    if (!_dirty || !_loaded) return;
    _sinceSave += dt;
    if (_sinceSave >= saveIntervalSeconds) {
      await save();
    }
  }

  /// 立即落盘（节流间隔到达时由 [tick] 调用；也可主动调用）。
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, flowerLedgerEncode(_ledger));
    _dirty = false;
    _sinceSave = 0;
  }
}
