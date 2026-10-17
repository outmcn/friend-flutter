part of 'main.dart';

class _DiscoverMetrics {
  static Future<void> record(String key, [int? durationMs]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countKey = 'discover.metric.$key.count';
      await prefs.setInt(countKey, (prefs.getInt(countKey) ?? 0) + 1);
      if (durationMs != null) {
        final totalKey = 'discover.metric.$key.totalMs';
        await prefs.setInt(totalKey, (prefs.getInt(totalKey) ?? 0) + durationMs);
      }
    } catch (_) {}
  }
}

class _PermanentImageCache {
  static const int _maxMemoryProviders = 80;
  static const int _maxDiskFiles = 300;
  static final Map<String, String> _localPaths = <String, String>{};
  static final Map<String, Future<String?>> _pending =
      <String, Future<String?>>{};
  static final Map<String, ImageProvider<Object>> _providers =
      <String, ImageProvider<Object>>{};
  static final Map<String, DateTime> _providerUsedAt = <String, DateTime>{};

  static String identity(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return '';
    try {
      final uri = Uri.parse(normalized);
      final identityUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );
      return identityUri.toString();
    } catch (_) {}
    return normalized.split('?').first;
  }

  static Future<String?> _diskPath(String url) async {
    final key = identity(url);
    if (key.isEmpty) return null;
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/friend_media_cache');
    final fileName = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    final file = File('${cacheDirectory.path}/$fileName');
    return await file.exists() && await file.length() > 0 ? file.path : null;
  }

  static ImageProvider<Object>? provider(String url) {
    final key = identity(url);
    final provider = _providers[key];
    if (provider != null) _providerUsedAt[key] = DateTime.now();
    return provider;
  }

  static Future<String?> localPath(String url) async {
    final cached = _localPaths[identity(url)];
    if (cached != null && await File(cached).exists()) return cached;
    return _diskPath(url);
  }

  static void rememberProvider(String url, ImageProvider<Object> provider) {
    final key = identity(url);
    if (key.isEmpty) return;
    _providers[key] = provider;
    _providerUsedAt[key] = DateTime.now();
    while (_providers.length > _maxMemoryProviders) {
      final oldest = _providerUsedAt.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _providers.remove(oldest);
      _providerUsedAt.remove(oldest);
    }
  }

  static Future<void> _trimDiskCache(Directory cacheDirectory) async {
    try {
      final files = await cacheDirectory
          .list()
          .where((entity) => entity is File && !entity.path.endsWith('.part'))
          .cast<File>()
          .toList();
      final entries = <MapEntry<File, DateTime>>[];
      for (final file in files) {
        try {
          entries.add(MapEntry(file, (await file.stat()).modified));
        } catch (_) {}
      }
      if (entries.length < _maxDiskFiles) return;
      entries.sort((a, b) => a.value.compareTo(b.value));
      final removeCount = entries.length - _maxDiskFiles + 1;
      for (final entry in entries.take(removeCount)) {
        try {
          await entry.key.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> prefetch(String url) async {
    final path = await get(url);
    if (path == null) return;
    final provider = FileImage(File(path));
    rememberProvider(url, provider);
  }

  static String? peek(String url) => _localPaths[identity(url)];

  static Future<String?> get(String url) async {
    final normalized = url.trim();
    final key = identity(normalized);
    if (normalized.isEmpty || key.isEmpty) return null;
    final existing = _localPaths[key];
    if (existing != null && await File(existing).exists()) return existing;
    return _pending.putIfAbsent(key, () async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final cacheDirectory =
            Directory('${directory.path}/friend_media_cache');
        await cacheDirectory.create(recursive: true);
        await _trimDiskCache(cacheDirectory);
        final fileName = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
        final file = File('${cacheDirectory.path}/$fileName');
        if (await file.exists() && await file.length() > 0) {
          _localPaths[key] = file.path;
          return file.path;
        }
        if (await file.exists()) await file.delete();
        final response = await http
            .get(Uri.parse(normalized))
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (await file.exists()) await file.delete();
          return null;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        if (response.bodyBytes.isEmpty) return null;
        final temporary = File('${file.path}.part');
        await temporary.writeAsBytes(response.bodyBytes, flush: true);
        await temporary.rename(file.path);
        _localPaths[key] = file.path;
        return file.path;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(key);
      }
    });
  }
}

class _PermanentCachedImage extends StatefulWidget {
  const _PermanentCachedImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  @override
  State<_PermanentCachedImage> createState() => _PermanentCachedImageState();
}

class _PermanentCachedImageState extends State<_PermanentCachedImage> {
  String? localPath;
  bool failed = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final provider = _PermanentImageCache.provider(widget.url);
    if (provider is FileImage) localPath = provider.file.path;
    _load();
  }

  @override
  void didUpdateWidget(covariant _PermanentCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final cached = _PermanentImageCache.peek(widget.url);
      if (_PermanentImageCache.identity(oldWidget.url) !=
          _PermanentImageCache.identity(widget.url)) {
        localPath = cached;
      }
      failed = false;
      loading = true;
      if (mounted) setState(() {});
      _load();
    }
  }

  Future<void> _load() async {
    final requestedUrl = widget.url;
    final cachedProvider = _PermanentImageCache.provider(requestedUrl);
    if (cachedProvider is FileImage) {
      localPath = cachedProvider.file.path;
      if (mounted) setState(() => loading = false);
      return;
    }
    final memoryPath = _PermanentImageCache.peek(widget.url);
    if (memoryPath != null) {
      if (mounted) setState(() {
        localPath = memoryPath;
        loading = false;
      });
      return;
    }
    final diskPath = await _PermanentImageCache._diskPath(widget.url);
    if (diskPath != null && mounted && requestedUrl == widget.url) {
      setState(() {
        localPath = diskPath;
        loading = false;
      });
      return;
    }
    final path = await _PermanentImageCache.get(requestedUrl);
    if (!mounted || requestedUrl != widget.url) return;
    if (path != null) {
      setState(() {
        localPath = path;
        loading = false;
      });
    } else {
      setState(() {
        failed = localPath == null;
        loading = false;
      });
    }
  }

  Future<void> _reloadMedia() async {
    if (loading) return;
    setState(() {
      failed = false;
      loading = true;
    });
    await _load();
  }
  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (path != null) {
      final provider = FileImage(File(path));
      _PermanentImageCache.rememberProvider(widget.url, provider);
      return Image(
        image: provider,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null || wasSynchronouslyLoaded) {
            }
          return child;
        },
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: loading
          ? (widget.placeholder ??
              const Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : failed
              ? GestureDetector(
                  onTap: _reloadMedia,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined),
                        SizedBox(height: 4),
                        Text('点击重试'),
                      ],
                    ),
                  ),
                )
              : widget.placeholder ?? const SizedBox.shrink(),
    );
  }
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String formatDDTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toUtc().add(const Duration(hours: 8));
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final difference = now.difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inMinutes < 60) return '${difference.inMinutes}分钟前';
  if (difference.inHours < 24) return '${difference.inHours}小时前';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  return '${value.year}年${value.month}月${value.day}日';
}

Future<String> syncCachedLocation(DDPostService service, String token) async {
  const cacheAge = Duration(hours: 1);
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedAt = prefs.getInt('dd.location.cachedAt');
    var latitude = prefs.getDouble('dd.location.latitude');
    var longitude = prefs.getDouble('dd.location.longitude');
    final cacheValid = cachedAt != null &&
        now - cachedAt < cacheAge.inMilliseconds &&
        latitude != null &&
        longitude != null;
    if (!cacheValid) {
      if (!await Geolocator.isLocationServiceEnabled()) return '';
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return '';
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      latitude = position.latitude;
      longitude = position.longitude;
      await prefs.setDouble('dd.location.latitude', latitude);
      await prefs.setDouble('dd.location.longitude', longitude);
      await prefs.setInt('dd.location.cachedAt', now);
    }
    await service.updateLocation(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      final geocoder = Geocoding();
      final marks =
          await geocoder.placemarkFromCoordinates(latitude, longitude);
      final mark = marks.isNotEmpty ? marks.first : null;
      final resolvedCity = (mark?.locality ?? mark?.subAdministrativeArea ?? '')
          .replaceAll('市', '')
          .trim();
      if (resolvedCity.isNotEmpty) {
        await prefs.setString('dd.location.city', resolvedCity);
        return resolvedCity;
      }
    } catch (_) {
      // Reverse geocoding is optional; coordinates remain usable if unavailable.
    }
    return prefs.getString('dd.location.city')?.trim() ?? '';
  } catch (_) {
    // Location is optional; feeds remain available without it.
    return '';
  }
}

Future<String> cachedCityLabel(DDPostService service, String token) async {
  final prefs = await SharedPreferences.getInstance();
  final cachedCity = (prefs.getString('dd.location.city') ?? '').trim();
  // Always read the server city after coordinate synchronization so stale cached
  // city names cannot override the current device location.
  try {
    final profile = await service.fetchMe(token);
    final city = '${profile['city'] ?? ''}'.trim();
    if (city.isNotEmpty) await prefs.setString('dd.location.city', city);
    return city.isEmpty ? '城市' : city;
  } catch (_) {
    return cachedCity.isEmpty ? '城市' : cachedCity;
  }
}
