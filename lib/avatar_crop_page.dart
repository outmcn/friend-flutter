/// Square avatar crop screen. The drag handle and preview stay local; only
/// the confirmed JPEG bytes leave the device for the OSS upload.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.file});
  final XFile file;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  img.Image? source;
  double scale = 1;
  Offset offset = Offset.zero;
  Offset? dragStart;
  double startScale = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (mounted) setState(() => source = decoded);
  }

  Future<List<int>> _crop() async {
    final image = source!;
    final side = math.min(image.width, image.height);
    final left = ((image.width - side) / 2).round();
    final top = ((image.height - side) / 2).round();
    final square = img.copyCrop(image, x: left, y: top, width: side, height: side);
    final resized = img.copyResize(square, width: 512, height: 512);
    return img.encodeJpg(resized, quality: 88);
  }

  @override
  Widget build(BuildContext context) {
    final image = source;
    return Scaffold(
      appBar: AppBar(title: const Text('裁剪头像')),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onScaleStart: (details) {
                        dragStart = details.focalPoint;
                        startScale = scale;
                      },
                      onScaleUpdate: (details) {
                        setState(() {
                          scale = (startScale * details.scale).clamp(.8, 4.0);
                          if (dragStart != null) {
                            offset += details.focalPoint - dragStart!;
                            dragStart = details.focalPoint;
                          }
                        });
                      },
                      child: ClipOval(
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: Transform.translate(
                            offset: offset,
                            child: Transform.scale(
                              scale: scale,
                              child: Image.memory(
                                Uint8List.fromList(img.encodeJpg(image)),
                                fit: BoxFit.cover,
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
                      onPressed: () async => Navigator.pop(context, await _crop()),
                      child: const Text('使用此头像'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

