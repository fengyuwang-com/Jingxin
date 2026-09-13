import 'dart:typed_data';

import 'star_card_saver.dart';

/// 非 Web 平台 stub（第 35 轮）：移动端保存不在本轮范围内，
/// 仅记录日志；UI 层据 [isSupported] 给出温柔提示，绝不报错。
class StarCardSaverImpl implements StarCardSaver {
  @override
  bool get isSupported => false;

  @override
  Future<bool> savePng(Uint8List bytes, String filename) async {
    // ignore: avoid_print
    print('[star_card] 本平台暂不支持保存分享卡（$filename, ${bytes.length}B）');
    return false;
  }
}
