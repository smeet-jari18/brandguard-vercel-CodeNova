import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

const MethodChannel _filesChannel = MethodChannel('brandguard/files');

Future<String?> saveBytesPlatform({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final cleanName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  if (Platform.isAndroid) {
    try {
      final path = await _filesChannel.invokeMethod<String>(
        'saveToDownloads',
        <String, dynamic>{
          'name': cleanName,
          'mimeType': mimeType,
          'bytes': bytes,
        },
      );
      if (path != null && path.isNotEmpty) {
        return path;
      }
    } on MissingPluginException {
      // Fall through to temp/save-location fallback in widget tests or headless hosts.
    }
  }

  try {
    final location = await getSaveLocation(suggestedName: cleanName);
    if (location != null) {
      await XFile.fromData(
        bytes,
        name: cleanName,
        mimeType: mimeType,
      ).saveTo(location.path);
      return location.path;
    }
    return null;
  } on UnimplementedError {
    final fallback = File('${Directory.systemTemp.path}/$cleanName');
    await fallback.writeAsBytes(bytes, flush: true);
    return fallback.path;
  }
}
