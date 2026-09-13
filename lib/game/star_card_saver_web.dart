import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'star_card_saver.dart';

/// Web 实现（第 35 轮）：PNG 字节 → Blob → ObjectURL →
/// `<a download>` 程序化点击，触发浏览器下载。一次性、零残留。
class StarCardSaverImpl implements StarCardSaver {
  @override
  bool get isSupported => true;

  @override
  Future<bool> savePng(Uint8List bytes, String filename) async {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/png'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = filename;
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
