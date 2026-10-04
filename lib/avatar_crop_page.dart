import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Local square avatar cropper. The source is decoded once; JPEG encoding is
/// deferred until confirmation so drag and pinch updates stay lightweight.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.file});
  final XFile file;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const double _viewportSize = 300;
  img.Image? source;
  Uint8List? previewBytes;
  double scale = 1;
  Offset offset = Offset.zero;
  Offset? gestureStart;
  double startScale = 1;
  Offset startOffset = Offset.zero;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (!mounted || decoded == null) return;
    // Encode only once for the preview. Gesture frames reuse these bytes.
    final preview = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
    setState(() {
      source = decoded;
      previewBytes = preview;
    });
  }

  Future<List<int>> _crop() async {
    final image = source!;
    final baseScale = math.max(
      _viewportSize / image.width,
      _viewportSize / image.height,
    );
    final renderedScale = baseScale * scale;
    final renderedWidth = image.width * renderedScale;
    final renderedHeight = image.height * renderedScale;
    final visibleLeft = (renderedWidth - _viewportSize) / 2 - offset.dx;
    final visibleTop = (renderedHeight - _viewportSize) / 2 - offset.dy;
    final left = (visibleLeft / renderedScale).round();
    final top = (visibleTop / renderedScale).round();
    final cropSide = (_viewportSize / renderedScale).round();
    final maxLeft = math.max(0, image.width - cropSide);
    final maxTop = math.max(0, image.height - cropSide);
    final square = img.copyCrop(
      image,
      x: left.clamp(0, maxLeft),
      y: top.clamp(0, maxTop),
      width: cropSide.clamp(1, image.width),
      height: cropSide.clamp(1, image.height),
    );
    final resized = img.copyResize(square, width: 512, height: 512);
    return img.encodeJpg(resized, quality: 88);
  }

  Future<void> _confirm() async {
    if (source == null || exporting) return;
    setState(() => exporting = true);
    final result = await _crop();
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = previewBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('裁剪头像')),
      body: bytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        gestureStart = details.focalPoint;
                        startScale = scale;
                        startOffset = offset;
                      },
                      onScaleUpdate: (details) {
                        final start = gestureStart;
                        if (start == null) return;
                        // Only transform values change during the gesture;
                        // Image.memory and JPEG encoding are not recreated.
                        setState(() {
                          scale = (startScale * details.scale).clamp(.8, 4.0);
                          offset = startOffset + details.focalPoint - start;
                        });
                      },
                      child: ClipOval(
                        child: SizedBox(
                          width: _viewportSize,
                          height: _viewportSize,
                          child: Transform.translate(
                            offset: offset,
                            child: Transform.scale(
                              scale: scale,
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('拖动或双指缩放，调整头像区域'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: exporting ? null : _confirm,
                      child: Text(exporting ? '处理中…' : '使用此头像'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
