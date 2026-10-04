import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Avatar crop screen. The complete source image is fitted inside the
/// workspace, while a fixed circular mask defines the exported avatar area.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.file});
  final XFile file;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const double _cropSize = 300;
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
    final preview = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
    setState(() {
      source = decoded;
      previewBytes = preview;
    });
  }

  double _baseScale(img.Image image) => math.min(
        _cropSize / image.width,
        _cropSize / image.height,
      );

  /// The image starts fully visible. Once zoomed, it may move only enough to
  /// keep the circular crop window completely covered.
  Offset _clampOffset({required double nextScale, required Offset nextOffset}) {
    final image = source;
    if (image == null) return Offset.zero;
    final renderedWidth = image.width * _baseScale(image) * nextScale;
    final renderedHeight = image.height * _baseScale(image) * nextScale;
    final maxX = math.max(0.0, (renderedWidth - _cropSize) / 2);
    final maxY = math.max(0.0, (renderedHeight - _cropSize) / 2);
    return Offset(
      nextOffset.dx.clamp(-maxX, maxX),
      nextOffset.dy.clamp(-maxY, maxY),
    );
  }

  Future<List<int>> _crop() async {
    final image = source!;
    final renderedScale = _baseScale(image) * scale;
    final renderedWidth = image.width * renderedScale;
    final renderedHeight = image.height * renderedScale;
    final visibleLeft = (renderedWidth - _cropSize) / 2 - offset.dx;
    final visibleTop = (renderedHeight - _cropSize) / 2 - offset.dy;
    final left = (visibleLeft / renderedScale).round();
    final top = (visibleTop / renderedScale).round();
    final cropSide = (_cropSize / renderedScale).round();
    final width = cropSide.clamp(1, image.width);
    final height = cropSide.clamp(1, image.height);
    final square = img.copyCrop(
      image,
      x: left.clamp(0, math.max(0, image.width - width)),
      y: top.clamp(0, math.max(0, image.height - height)),
      width: width,
      height: height,
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
                    child: SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The black workspace keeps the complete fitted image
                          // visible and makes the crop boundary unambiguous.
                          Container(color: Colors.black),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: (details) {
                              gestureStart = details.focalPoint;
                              startScale = scale;
                              startOffset = offset;
                            },
                            onScaleUpdate: (details) {
                              final start = gestureStart;
                              if (start == null) return;
                              final nextScale =
                                  (startScale * details.scale).clamp(1.0, 4.0);
                              final nextOffset =
                                  startOffset + details.focalPoint - start;
                              setState(() {
                                scale = nextScale;
                                offset = _clampOffset(
                                  nextScale: nextScale,
                                  nextOffset: nextOffset,
                                );
                              });
                            },
                            child: ClipOval(
                              child: Transform.translate(
                                offset: offset,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Image.memory(
                                    bytes,
                                    width: _cropSize,
                                    height: _cropSize,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.low,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropBoundaryPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('完整图片已显示在圆形区域内；拖动或双指缩放调整头像'),
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

class _CropBoundaryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
