import 'package:flutter/foundation.dart';

import 'asset_saver_stub.dart'
    if (dart.library.io) 'asset_saver_io.dart'
    if (dart.library.js_interop) 'asset_saver_web.dart'
    as impl;

@visibleForTesting
Future<String?> Function(String fileName, Uint8List bytes, String mimeType)?
    saveAssetOverrideForTesting;

Future<String?> saveAssetToDevice({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) {
  final override = saveAssetOverrideForTesting;
  if (override != null) {
    return override(fileName, bytes, mimeType);
  }
  return impl.saveBytesPlatform(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}
