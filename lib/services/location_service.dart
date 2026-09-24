import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const cacheHours = 6;

  Future<LocationPermission> requestPermissionAtStartup() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermission.denied;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<Position?> currentPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('friend.location.cachedAt') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lat = prefs.getDouble('friend.location.latitude');
    final lon = prefs.getDouble('friend.location.longitude');
    if (lat != null && lon != null && now - cachedAt < cacheHours * 3600000) {
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.fromMillisecondsSinceEpoch(cachedAt),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    final permission = await requestPermissionAtStartup();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition().timeout(
      const Duration(seconds: 15),
    );
    await prefs.setDouble('friend.location.latitude', position.latitude);
    await prefs.setDouble('friend.location.longitude', position.longitude);
    await prefs.setInt('friend.location.cachedAt', now);
    return position;
  }

  Future<String?> city() async {
    final position = await currentPosition();
    if (position == null) return null;
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    ).timeout(const Duration(seconds: 15));
    if (places.isEmpty) return null;
    final value =
        (places.first.locality ?? places.first.administrativeArea ?? '')
            .replaceAll('市', '');
    return value.isEmpty ? null : value;
  }
}
