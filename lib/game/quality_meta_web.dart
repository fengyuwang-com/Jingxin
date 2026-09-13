import 'dart:js_interop';

/// Web 平台的设备信息：读 navigator.userAgent 与 navigator.deviceMemory
/// （后者多数浏览器有、可能为 undefined——用可空 external 承接）。
@JS('navigator.userAgent')
external JSString? get _userAgent;

@JS('navigator.deviceMemory')
external JSNumber? get _deviceMemory;

String? userAgent() => _userAgent?.toDart;

double? deviceMemoryGB() => _deviceMemory?.toDartDouble;
