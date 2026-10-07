part of 'main.dart';

class _VideoPlaybackRegistry {
  static final Set<_NetworkVideoPreviewState> _players =
      <_NetworkVideoPreviewState>{};

  static void register(_NetworkVideoPreviewState player) =>
      _players.add(player);
  static void unregister(_NetworkVideoPreviewState player) =>
      _players.remove(player);

  static void stopAll() {
    for (final player in List<_NetworkVideoPreviewState>.from(_players)) {
      player.stopPlayback();
    }
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({
    required this.url,
    this.thumbnailUrl,
    this.unlimitedHeight = false,
  });
  final String url;
  final String? thumbnailUrl;
  final bool unlimitedHeight;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? controller;
  bool loading = false;
  bool ended = false;

  void _onVideoChanged() {
    final active = controller;
    if (!mounted || active == null || !active.value.isInitialized) return;
    final duration = active.value.duration;
    final position = active.value.position;
    final isEnded = duration > Duration.zero && position >= duration;
    if (ended != isEnded) setState(() => ended = isEnded);
  }

  Future<void> _replay() async {
    final active = controller;
    if (active == null) return;
    await active.seekTo(Duration.zero);
    setState(() => ended = false);
    await active.play();
  }

  @override
  void initState() {
    super.initState();
    _VideoPlaybackRegistry.register(this);
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一媒体重新签名时保留播放器，更换媒体才释放旧实例。
    if (_PermanentImageCache.identity(oldWidget.url) !=
        _PermanentImageCache.identity(widget.url)) {
      controller?.removeListener(_onVideoChanged);
      controller?.dispose();
      controller = null;
      loading = false;
      ended = false;
    }
  }

  Future<void> _play() async {
    if (loading) return;
    setState(() => loading = true);
    final source = widget.url;
    final next = VideoPlayerController.networkUrl(Uri.parse(source));
    try {
      await next.initialize();
      if (!mounted || source != widget.url) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        loading = false;
        ended = false;
      });
      next.addListener(_onVideoChanged);
      await next.play();
    } catch (_) {
      await next.dispose();
      if (mounted) setState(() => loading = false);
    }
  }

  void stopPlayback() {
    controller?.pause();
  }

  @override
  void dispose() {
    _VideoPlaybackRegistry.unregister(this);
    controller?.removeListener(_onVideoChanged);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    if (active == null || !active.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: _play,
          child: Stack(
            alignment: Alignment.center,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: widget.thumbnailUrl?.isNotEmpty == true
                      ? ConstrainedBox(
                          constraints: widget.unlimitedHeight
                              ? const BoxConstraints()
                              : const BoxConstraints(maxHeight: 400),
                          child: _PermanentCachedImage(
                            url: widget.thumbnailUrl!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const SizedBox(height: 225),
                ),
              ),
              loading
                  ? const CircularProgressIndicator()
                  : const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = widget.unlimitedHeight
                  ? width / active.value.aspectRatio
                  : math.min(400.0, width / active.value.aspectRatio);
              return SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(active),
              );
            },
          ),
          if (ended)
            GestureDetector(
              onTap: _replay,
              child: const Icon(Icons.replay_circle_filled,
                  size: 64, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
