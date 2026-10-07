part of 'main.dart';

class _CreatePostPageState extends State<CreatePostPage> {
  String? mediaType;
  XFile? selectedImage;
  XFile? selectedVideo;
  String visibility = '所有人可见';
  bool publishing = false;
  final TextEditingController _content = TextEditingController();
  final DDPostService _service = DDPostService();
  String? error;

  @override
  void dispose() {
    _content.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          selectedImage = image;
          mediaType = '图片';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '图片选择失败：$e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        final bytes = await video.length();
        if (bytes > 50 * 1024 * 1024) throw Exception('视频不能超过 50MB');
        setState(() {
          selectedVideo = video;
          selectedImage = null;
          mediaType = '视频';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '视频选择失败：$e');
    }
  }

  Future<void> _pickMedia() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('添加图片'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('添加视频'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (type == 'image') await _pickImage();
    if (type == 'video') await _pickVideo();
  }

  Future<String?> _imageObjectKey(String token) async {
    if (selectedImage == null) return null;
    final bytes = await selectedImage!.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) throw Exception('图片不能超过 8MB');
    final decoded = img.decodeImage(bytes);
    final resized = decoded == null
        ? null
        : (decoded.width > 1600
            ? img.copyResize(decoded, width: 1600)
            : decoded);
    final compressed =
        resized == null ? bytes : img.encodeJpg(resized, quality: 82);
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: selectedImage!.name,
      contentType: 'image/jpeg',
      kind: 'image',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('图片上传地址格式错误');
    if (!await _service.uploadAvatar(
        url: url, bytes: compressed, contentType: 'image/jpeg')) {
      throw Exception('图片上传失败');
    }
    return key;
  }

  Future<String?> _videoObjectKey(String token) async {
    if (selectedVideo == null) return null;
    final bytes = await selectedVideo!.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) throw Exception('视频不能超过 50MB');
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: selectedVideo!.name,
      contentType: 'video/mp4',
      kind: 'video',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('视频上传地址格式错误');
    if (!await _service.uploadAvatar(
        url: url, bytes: bytes, contentType: 'video/mp4')) {
      throw Exception('视频上传失败');
    }
    return key;
  }

  Future<String?> _videoThumbnailKey(String token) async {
    if (selectedVideo == null) return null;
    final bytes = await VideoThumbnail.thumbnailData(
      video: selectedVideo!.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 720,
      quality: 82,
    );
    if (bytes == null || bytes.isEmpty) throw Exception('视频预览图生成失败');
    final signed = await _service.postMediaUploadUrl(
      token: token,
      fileName: 'thumbnail.jpg',
      contentType: 'image/jpeg',
      kind: 'image',
    );
    final url = signed['url'];
    final key = signed['objectKey'];
    if (url is! String || key is! String) throw Exception('视频预览图上传地址格式错误');
    if (!await _service.uploadAvatar(
        url: url, bytes: bytes, contentType: 'image/jpeg')) {
      throw Exception('视频预览图上传失败');
    }
    return key;
  }

  Future<_PostLocation?> _locationForPost(String token) async {
    const cacheAge = Duration(hours: 1);
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('dd.location.cachedAt');
    final cachedLatitude = prefs.getDouble('dd.location.latitude');
    final cachedLongitude = prefs.getDouble('dd.location.longitude');
    final now = DateTime.now().millisecondsSinceEpoch;
    double? latitude;
    double? longitude;
    if (cachedAt != null &&
        now - cachedAt < cacheAge.inMilliseconds &&
        cachedLatitude != null &&
        cachedLongitude != null) {
      latitude = cachedLatitude;
      longitude = cachedLongitude;
    } else {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      latitude = position.latitude;
      longitude = position.longitude;
      await prefs.setDouble('dd.location.latitude', latitude);
      await prefs.setDouble('dd.location.longitude', longitude);
      await prefs.setInt('dd.location.cachedAt', now);
    }
    await _service.updateLocation(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
    return _PostLocation(latitude, longitude);
  }

  void _clearImage() => setState(() {
        selectedImage = null;
        selectedVideo = null;
        mediaType = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: const Text('发布动态'),
          actions: [
            TextButton(
              onPressed: publishing
                  ? null
                  : () async {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('friend.auth.token') ?? '';
                      if (token.isEmpty) {
                        setState(() => error = '请先登录后发布动态');
                        return;
                      }
                      if (_content.text.trim().isEmpty &&
                          selectedImage == null &&
                          selectedVideo == null) {
                        setState(() => error = '请输入动态内容或选择图片');
                        return;
                      }
                      setState(() {
                        publishing = true;
                        error = null;
                      });
                      try {
                        final location = await _locationForPost(token);
                        final videoKey = await _videoObjectKey(token);
                        final thumbnailKey = await _videoThumbnailKey(token);
                        int? imageWidth;
                        int? imageHeight;
                        if (selectedImage != null) {
                          final decoded = img
                              .decodeImage(await selectedImage!.readAsBytes());
                          imageWidth = decoded?.width;
                          imageHeight = decoded?.height;
                        }
                        await _service.createPost(
                          token: token,
                          content: _content.text.trim(),
                          imageDataUrl: await _imageObjectKey(token),
                          videoUrl: videoKey,
                          thumbnailUrl: thumbnailKey,
                          imageWidth: imageWidth,
                          imageHeight: imageHeight,
                          visibility: visibility == '仅好友可见'
                              ? 'friends'
                              : visibility == '仅自己可见'
                                  ? 'private'
                                  : 'public',
                          latitude: location?.latitude,
                          longitude: location?.longitude,
                        );
                        await DDPostService.clearProfileTabCaches();
                        if (!mounted || !context.mounted) return;
                        Navigator.pop(context, true);
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            publishing = false;
                            error =
                                e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      } finally {
                        if (mounted) setState(() => publishing = false);
                      }
                    },
              child: Text(publishing ? '发布中…' : '发布'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              controller: _content,
              autofocus: true,
              maxLines: 7,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '发一条动态吧～',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, size: 28),
                ),
              ),
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(selectedImage!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: _clearImage,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            if (selectedVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: VideoThumbnail.thumbnailData(
                        video: selectedVideo!.path,
                        imageFormat: ImageFormat.JPEG,
                        maxWidth: 720,
                        quality: 82,
                      ),
                      builder: (context, snapshot) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: snapshot.data == null
                              ? const ColoredBox(color: Colors.transparent)
                              : Image.memory(snapshot.data!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: _clearImage,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: _iconFor(Icons.public),
              title: Text(visibility),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ['所有人可见', '仅主页可见', '仅陌生人可见', '仅自己可见']
                        .map(
                          (item) => ListTile(
                            title: Text(item),
                            trailing: item == visibility
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              setState(() => visibility = item);
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
