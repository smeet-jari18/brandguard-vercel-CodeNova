import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import 'app_widgets.dart';
import '../../core/network/asset_saver.dart';
import '../../core/network/brandguard_api_service.dart';

bool looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }
  // GIF
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return true;
  }
  // WEBP (RIFF....WEBP)
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  return false;
}

String formatFileBytes(int? rawBytes) {
  if (rawBytes == null || rawBytes <= 0) return 'Server file';
  if (rawBytes < 1024) return '$rawBytes B';
  if (rawBytes < 1024 * 1024) {
    return '${(rawBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(rawBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

Future<void> downloadAndSaveAsset(
  BuildContext context, {
  required String assetId,
  required String fileName,
  String? contentType,
  Uint8List? initialBytes,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    Uint8List bytes;
    String resolvedMime = contentType ?? 'application/octet-stream';
    if (initialBytes != null && initialBytes.isNotEmpty) {
      bytes = initialBytes;
    } else {
      final result = await BrandGuardApiService.downloadAssetBytes(assetId);
      bytes = result.bytes;
      if (result.contentType != null && result.contentType!.isNotEmpty) {
        resolvedMime = result.contentType!;
      }
    }
    final savedPath = await saveAssetToDevice(
      fileName: fileName,
      bytes: bytes,
      mimeType: resolvedMime,
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null || savedPath.isEmpty
              ? 'Save cancelled.'
              : 'Saved $fileName ($savedPath)',
        ),
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not download $fileName: $e')),
    );
  }
}

Future<void> showAssetViewerSheet(
  BuildContext context, {
  required String assetId,
  required String fileName,
  String? contentType,
  bool isImage = false,
  Uint8List? initialBytes,
  String? extractedText,
  List<Map<String, dynamic>> dominantColors = const [],
  int? width,
  int? height,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _AssetViewerSheet(
      assetId: assetId,
      fileName: fileName,
      contentType: contentType,
      isImage: isImage,
      initialBytes: initialBytes,
      extractedText: extractedText,
      dominantColors: dominantColors,
      width: width,
      height: height,
    ),
  );
}

class _AssetViewerSheet extends StatefulWidget {
  const _AssetViewerSheet({
    required this.assetId,
    required this.fileName,
    this.contentType,
    this.isImage = false,
    this.initialBytes,
    this.extractedText,
    this.dominantColors = const [],
    this.width,
    this.height,
  });

  final String assetId;
  final String fileName;
  final String? contentType;
  final bool isImage;
  final Uint8List? initialBytes;
  final String? extractedText;
  final List<Map<String, dynamic>> dominantColors;
  final int? width;
  final int? height;

  @override
  State<_AssetViewerSheet> createState() => _AssetViewerSheetState();
}

class _AssetViewerSheetState extends State<_AssetViewerSheet> {
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  Uint8List? _bytes;
  late String _fileName = widget.fileName;
  late String _mime = widget.contentType ?? 'application/octet-stream';
  late bool _isImage = widget.isImage;
  String _extractedText = '';
  int? _width;
  int? _height;
  int? _byteCount;
  List<Map<String, dynamic>> _colors = const [];

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    _extractedText = widget.extractedText ?? '';
    _width = widget.width;
    _height = widget.height;
    _colors = widget.dominantColors;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_extractedText.isEmpty || _mime == 'application/octet-stream') {
        try {
          final meta = await BrandGuardApiService.getAssetPreview(widget.assetId);
          if (!mounted) return;
          if ((meta['name']?.toString() ?? '').isNotEmpty) {
            _fileName = meta['name'].toString();
          }
          if ((meta['content_type']?.toString() ?? '').isNotEmpty) {
            _mime = meta['content_type'].toString();
          }
          _isImage = meta['is_image'] == true || _mime.startsWith('image/');
          _extractedText = meta['extracted_text']?.toString() ?? _extractedText;
          _width = (meta['width'] as num?)?.toInt() ?? _width;
          _height = (meta['height'] as num?)?.toInt() ?? _height;
          _byteCount = (meta['bytes'] as num?)?.toInt() ?? _byteCount;
          if (meta['dominant_colors'] is List) {
            _colors = (meta['dominant_colors'] as List)
                .whereType<Map>()
                .map((c) => Map<String, dynamic>.from(c))
                .toList();
          }
        } catch (_) {
          // Proceed to byte download if metadata call fails.
        }
      }
      if (_isImage && _bytes == null) {
        final downloaded = await BrandGuardApiService.downloadAssetBytes(
          widget.assetId,
          inline: true,
        );
        if (!mounted) return;
        _bytes = downloaded.bytes;
        if (downloaded.contentType != null &&
            downloaded.contentType!.isNotEmpty) {
          _mime = downloaded.contentType!;
        }
        _byteCount ??= _bytes?.length;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await downloadAndSaveAsset(
        context,
        assetId: widget.assetId,
        fileName: _fileName,
        contentType: _mime,
        initialBytes: _bytes,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    final hasRenderableImage =
        _isImage && _bytes != null && looksLikeImageBytes(_bytes!);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isImage
                          ? Icons.image_outlined
                          : _mime.contains('pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.description_outlined,
                      color: AppTheme.tealText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.titleMedium.copyWith(fontSize: 15),
                        ),
                        Text(
                          [
                            _mime,
                            if (_width != null && _height != null)
                              '${_width}x$_height',
                            if (_byteCount != null) formatFileBytes(_byteCount),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.monoLabel().copyWith(fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    key: const ValueKey('asset-viewer-download'),
                    onPressed: _downloading ? null : _download,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: _downloading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorBlock(message: _error!, onRetry: _load),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      children: [
                        if (_isImage) ...[
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 200,
                              maxHeight: 380,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.navyDeep,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: hasRenderableImage
                                ? InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: Image.memory(
                                        _bytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        'Image preview could not be decoded (${_bytes?.length ?? 0} bytes). Use Save to download the raw file.',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.bodySmall.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          if (_colors.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('DOMINANT PALETTE', style: AppTheme.monoLabel()),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _colors.take(6).map((c) {
                                final hex = c['hex']?.toString() ?? '';
                                final parsed = _parseHex(hex);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (parsed != null) ...[
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: parsed,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.borderStrong,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        '$hex (${c['coverage_pct'] ?? 0}%)',
                                        style: AppTheme.monoLabel().copyWith(
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            Text(
                              _isImage
                                  ? 'EXTRACTED OCR TEXT'
                                  : 'DOCUMENT CONTENT PREVIEW',
                              style: AppTheme.monoLabel(color: AppTheme.info),
                            ),
                            const Spacer(),
                            if (_extractedText.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _extractedText),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Text copied to clipboard.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 15),
                                label: const Text('Copy text'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SurfaceCard(
                          padding: const EdgeInsets.all(12),
                          radius: 14,
                          child: SelectableText(
                            _extractedText.trim().isNotEmpty
                                ? _extractedText
                                : (_isImage
                                      ? 'No readable text detected via OCR in this image.'
                                      : 'No text extracted. Tap Save above to download the original file.'),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.ink,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) return null;
    final val = int.tryParse(cleaned, radix: 16);
    if (val == null) return null;
    return Color(0xFF000000 | val);
  }
}

class AssetBundleSection extends StatelessWidget {
  const AssetBundleSection({
    super.key,
    required this.assets,
    this.assetIds = const [],
    this.title = 'ATTACHED IMAGES & DOCUMENTS',
  });

  final List<Map<String, dynamic>> assets;
  final List<String> assetIds;
  final String title;

  List<Map<String, dynamic>> get _resolvedList {
    if (assets.isNotEmpty) return assets;
    return assetIds
        .where((id) => id.trim().isNotEmpty)
        .map(
          (id) => <String, dynamic>{
            'id': id,
            'name': 'Attached file (${id.length > 8 ? id.substring(0, 8) : id})',
            'is_image': false,
            'content_type': 'application/octet-stream',
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _resolvedList;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.monoLabel()),
        const SizedBox(height: 6),
        ...list.map((asset) {
          final id = asset['id']?.toString() ?? '';
          final name = asset['name']?.toString() ?? 'Attachment';
          final mime =
              asset['content_type']?.toString() ?? 'application/octet-stream';
          final isImage = asset['is_image'] == true || mime.startsWith('image/');
          final bytesCount = (asset['bytes'] as num?)?.toInt();
          final width = (asset['width'] as num?)?.toInt();
          final height = (asset['height'] as num?)?.toInt();
          final localBytes = asset['local_bytes'] is Uint8List
              ? asset['local_bytes'] as Uint8List
              : null;
          final colors = (asset['dominant_colors'] as List? ?? [])
              .whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              padding: const EdgeInsets.all(10),
              radius: 14,
              child: Row(
                children: [
                  if (isImage &&
                      localBytes != null &&
                      looksLikeImageBytes(localBytes))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        localBytes,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isImage
                            ? Icons.image_outlined
                            : mime.contains('pdf') ||
                                  name.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_outlined
                            : Icons.description_outlined,
                        size: 20,
                        color: AppTheme.tealText,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.labelLarge.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            isImage ? 'Image' : mime.split(';').first,
                            if (width != null && height != null)
                              '${width}x$height',
                            if (bytesCount != null && bytesCount > 0)
                              formatFileBytes(bytesCount),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.monoLabel().copyWith(fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('view-asset-$id'),
                    tooltip: isImage ? 'View source image' : 'Preview document',
                    onPressed: () => showAssetViewerSheet(
                      context,
                      assetId: id,
                      fileName: name,
                      contentType: mime,
                      isImage: isImage,
                      initialBytes: localBytes,
                      extractedText: asset['extracted_text']?.toString(),
                      dominantColors: colors,
                      width: width,
                      height: height,
                    ),
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 19,
                      color: AppTheme.tealText,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('download-asset-$id'),
                    tooltip: 'Download file',
                    onPressed: () => downloadAndSaveAsset(
                      context,
                      assetId: id,
                      fileName: name,
                      contentType: mime,
                      initialBytes: localBytes,
                    ),
                    icon: Icon(
                      Icons.download_rounded,
                      size: 19,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
