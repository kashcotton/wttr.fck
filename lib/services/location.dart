import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/weather.dart';
import 'weather_api.dart';

/// Tries real device location first (Android, Windows, browsers), then falls
/// back to IP geolocation (Linux, or when permission is denied).
class LocationService {
  LocationService(this.api);
  final WeatherApi api;

  bool get _hasGps =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  Future<Place> locate() async {
    if (_hasGps) {
      try {
        final pos = await _gps();
        if (pos != null) return await api.reverse(pos.latitude, pos.longitude);
      } catch (_) {
        // fall through to IP
      }
    }
    return api.ipLocation();
  }

  Future<Position?> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    // City-level accuracy is plenty for weather and is kinder to batteries
    // and privacy.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }
}
