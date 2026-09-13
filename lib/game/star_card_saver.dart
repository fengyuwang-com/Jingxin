/// 星图分享卡出口门面（第 35 轮）：按平台条件导出实现。
///
/// Web 平台：`star_card_saver_web.dart` 用 dart:js_interop +
/// package:web 构造 Blob → ObjectURL → `<a download>` 触发 PNG 下载。
/// 非 Web 平台：`star_card_saver_stub.dart` 仅记录日志——移动端保存
/// 不在本轮范围内（后续可接 image_gallery_saver 等）。
library;

import 'dart:typed_data';

export 'star_card_saver_stub.dart' if (dart.library.js_interop) 'star_card_saver_web.dart';

/// 分享卡出口接口：把渲染好的 PNG 字节带走。
abstract class StarCardSaver {
  /// 当前平台是否真的能保存（web = true；stub = false）。
  bool get isSupported;

  /// 保存一张 PNG。Web 上触发浏览器下载；返回是否成功发起。
  Future<bool> savePng(Uint8List bytes, String filename);
}
