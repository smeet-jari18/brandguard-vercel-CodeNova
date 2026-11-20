import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<String?> saveBytesPlatform({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final cleanName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  await XFile.fromData(
    bytes,
    name: cleanName,
    mimeType: mimeType,
  ).saveTo(cleanName);
  return 'Downloads/$cleanName';
}
