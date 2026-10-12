import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ImLocation {
  const ImLocation(this.latitude, this.longitude, this.title, this.address);

  final double latitude;
  final double longitude;
  final String title;
  final String address;

  static ImLocation? fromMetadata(dynamic value) {
    if (value is! Map) return null;
    final lat = double.tryParse('${value['latitude']}');
    final lon = double.tryParse('${value['longitude']}');
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    return ImLocation(lat, lon, _label(value['title'], '当前位置'),
        _label(value['address'], '地址暂不可用'));
  }

  static String _label(dynamic value, String fallback) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> toMetadata() => {
        'latitude': latitude,
        'longitude': longitude,
        'title': title,
        'address': address,
      };

  Uri get amapUrl => Uri.parse(
        'iosamap://viewMap?sourceApplication=Friend&lat=$latitude&lon=$longitude&poiname=${Uri.encodeComponent(title)}',
      );
  Uri get amapWebUrl => Uri.https('uri.amap.com', '/marker', {
        'position': '$longitude,$latitude',
        'name': title,
        'src': 'friend',
        'coordinate': 'gaode',
      });
  Uri get tencentUrl => Uri.parse(
        'qqmap://map/marker?marker=${Uri.encodeComponent('$latitude,$longitude')}&title=${Uri.encodeComponent(title)}&addr=${Uri.encodeComponent(address)}',
      );
  Uri get tencentWebUrl => Uri.https('apis.map.qq.com', '/uri/v1/marker', {
        'marker': '@$latitude,$longitude',
        'title': title,
        'addr': address,
      });
  Uri get mapsUrl => Uri.https('maps.apple.com', '/', {
        'll': '$latitude,$longitude',
        'q': title,
      });

  static Future<ImLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ImLocationException('请先开启系统定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ImLocationException('请在系统设置中允许使用位置');
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const ImLocationException('未获得定位权限，位置未发送');
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    return reverseGeocode(position.latitude, position.longitude);
  }

  static Future<ImLocation> reverseGeocode(double latitude, double longitude,
      {String fallbackTitle = '选择的位置'}) async {
    var title = fallbackTitle;
    var address = '地址暂不可用';
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(
            latitude,
            longitude,
            locale: const Locale('zh', 'CN'),
          )
          .timeout(const Duration(seconds: 8));
      if (places.isNotEmpty) {
        final place = places.first;
        title = _label(place.name, title);
        final parts = [
          place.administrativeArea,
          place.locality,
          place.subLocality,
          place.thoroughfare,
          place.subThoroughfare
        ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        address = _label(parts.join(' '), address);
      }
    } catch (_) {}
    return ImLocation(latitude, longitude, title, address);
  }
}

class ImLocationException implements Exception {
  const ImLocationException(this.message);
  final String message;
}

class ImLocationPickerPage extends StatefulWidget {
  const ImLocationPickerPage({super.key});
  @override
  State<ImLocationPickerPage> createState() => _ImLocationPickerPageState();
}

class _ImLocationPickerPageState extends State<ImLocationPickerPage> {
  final MapController _mapController = MapController();
  ImLocation? _selected;
  Timer? _reverseTimer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialLocation());
  }

  Future<void> _loadInitialLocation() async {
    try {
      final location = await ImLocation.current();
      if (!mounted) return;
      setState(() {
        _selected = location;
        _loading = false;
      });
      _mapController.move(LatLng(location.latitude, location.longitude), 16);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  void _onMapMove(MapPosition position, bool _) {
    final center = position.center;
    if (center == null) return;
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 500), () async {
      final location =
          await ImLocation.reverseGeocode(center.latitude, center.longitude);
      if (mounted) {
        setState(() => _selected = location);
      }
    });
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final center = selected == null
        ? const LatLng(31.2304, 121.4737)
        : LatLng(selected.latitude, selected.longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('选择位置')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              onPositionChanged: _onMapMove,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.outmcn.friend',
              ),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_pin, color: Colors.red, size: 48),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected?.title ?? '拖动地图选择位置',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(selected?.address ?? '正在获取位置…',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(context, selected),
                          child: const Text('发送此位置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImLocationCard extends StatelessWidget {
  const ImLocationCard({super.key, required this.metadata});
  final dynamic metadata;

  Future<void> _open(BuildContext context, ImLocation location) async {
    final provider = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              title: Text('选择地图'),
              subtitle: Text('请选择打开位置的地图应用'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.map_outlined),
              title: const Text('高德地图'),
              onTap: () => Navigator.pop(sheetContext, 'amap'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.map_outlined),
              title: const Text('腾讯地图'),
              onTap: () => Navigator.pop(sheetContext, 'tencent'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.map),
              title: const Text('Apple 地图'),
              onTap: () => Navigator.pop(sheetContext, 'apple'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || provider == null) return;
    final appUrl = provider == 'amap'
        ? location.amapUrl
        : provider == 'tencent'
            ? location.tencentUrl
            : location.mapsUrl;
    final fallbackUrl = provider == 'amap'
        ? location.amapWebUrl
        : provider == 'tencent'
            ? location.tencentWebUrl
            : location.mapsUrl;
    try {
      if (await launchUrl(appUrl, mode: LaunchMode.externalApplication)) return;
      if (provider != 'apple' &&
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法打开地图，请确认已安装对应地图应用')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ImLocation.fromMetadata(metadata);
    return Semantics(
      button: location != null,
      label: '位置',
      child: InkWell(
        onTap: location == null ? null : () => _open(context, location),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const SizedBox(
                width: 220,
                height: 100,
                child: CustomPaint(
                  painter: _MapThumbnailPainter(),
                  child: Center(
                    child: Icon(Icons.location_on, color: Colors.red, size: 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: Text(
                location?.title ?? '位置不可用',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 220,
              child: Text(
                location?.address ?? '位置信息不完整',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapThumbnailPainter extends CustomPainter {
  const _MapThumbnailPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xffe6eddf));
    canvas.drawOval(Rect.fromLTWH(size.width * .6, -20, 90, 160),
        Paint()..color = const Color(0xffc2dfeb));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9;
    for (final x in [.15, .48, .82]) {
      canvas.drawLine(Offset(size.width * x, 0),
          Offset(size.width * x - 35, size.height), road);
    }
    canvas.drawLine(Offset(0, size.height * .3),
        Offset(size.width, size.height * .6), road);
    canvas.drawLine(Offset(0, size.height * .8),
        Offset(size.width, size.height * .9), road..strokeWidth = 6);
  }

  @override
  bool shouldRepaint(_MapThumbnailPainter oldDelegate) => false;
}
