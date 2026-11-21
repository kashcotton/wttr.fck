import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// All data comes from Open-Meteo (CC BY 4.0, free, no API key).
/// Reverse geocoding: BigDataCloud's free client endpoint.
/// IP fallback location: GeoJS.
class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);
  static const _ua = {'User-Agent': 'wttr.fck/1.0'};

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final res = await _client.get(uri, headers: kIsWeb ? null : _ua).timeout(_timeout);
    if (res.statusCode != 200) {
      throw WeatherException('Server said ${res.statusCode}. Not our fault. Probably.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetches forecast + air quality. Returns the raw payloads so they can be
  /// cached and re-parsed offline.
  Future<RawForecast> fetchRaw(Place place) async {
    final lat = place.lat.toStringAsFixed(4);
    final lon = place.lon.toStringAsFixed(4);
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat,
      'longitude': lon,
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'is_day,precipitation,weather_code,cloud_cover,pressure_msl,'
          'wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code,is_day,'
          'uv_index,visibility',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,'
          'sunset,uv_index_max,precipitation_probability_max,'
          'precipitation_sum,wind_speed_10m_max',
      'timezone': 'auto',
      'forecast_days': '10',
    });
    final airUri =
        Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': lat,
      'longitude': lon,
      'current': 'us_aqi,pm2_5,pm10',
      'timezone': 'auto',
    });

    final forecastF = _get(forecastUri);
    // Air quality is a nice-to-have. Don't let it sink the whole ship.
    final airF = _get(airUri).then<Map<String, dynamic>?>((v) => v,
        onError: (_) => null);
    final f = await forecastF;
    final a = await airF;
    return RawForecast(place, f, a, DateTime.now());
  }

  Future<List<Place>> search(String query) async {
    if (query.trim().length < 2) return const [];
    final j = await _get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query.trim(),
      'count': '10',
      'language': 'en',
      'format': 'json',
    }));
    final results = (j['results'] as List?) ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map((r) => Place(
              name: r['name'] as String,
              region: r['admin1'] as String?,
              country: r['country'] as String?,
              lat: (r['latitude'] as num).toDouble(),
              lon: (r['longitude'] as num).toDouble(),
            ))
        .toList();
  }

  Future<Place> reverse(double lat, double lon) async {
    try {
      final j = await _get(Uri.https(
          'api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': '$lat',
        'longitude': '$lon',
        'localityLanguage': 'en',
      }));
      final city = (j['city'] as String?)?.trim();
      final locality = (j['locality'] as String?)?.trim();
      return Place(
        name: (city?.isNotEmpty ?? false)
            ? city!
            : (locality?.isNotEmpty ?? false)
                ? locality!
                : 'Your location',
        region: j['principalSubdivision'] as String?,
        country: j['countryName'] as String?,
        lat: lat,
        lon: lon,
      );
    } catch (_) {
      return Place(name: 'Your location', lat: lat, lon: lon);
    }
  }

  /// Rough location from the IP address. Used on desktop or when GPS is
  /// unavailable/denied.
  Future<Place> ipLocation() async {
    final j = await _get(Uri.https('get.geojs.io', '/v1/ip/geo.json'));
    final lat = double.tryParse('${j['latitude']}');
    final lon = double.tryParse('${j['longitude']}');
    if (lat == null || lon == null) {
      throw WeatherException("Couldn't figure out where you are. Search for a city.");
    }
    return Place(
      name: (j['city'] as String?) ?? 'Somewhere',
      region: j['region'] as String?,
      country: j['country'] as String?,
      lat: lat,
      lon: lon,
    );
  }
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
  @override
  String toString() => message;
}

class RawForecast {
  final Place place;
  final Map<String, dynamic> forecast;
  final Map<String, dynamic>? air;
  final DateTime fetchedAt;
  RawForecast(this.place, this.forecast, this.air, this.fetchedAt);

  Map<String, dynamic> toJson() => {
        'place': place.toJson(),
        'forecast': forecast,
        'air': air,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory RawForecast.fromJson(Map<String, dynamic> j) => RawForecast(
        Place.fromJson(j['place'] as Map<String, dynamic>),
        j['forecast'] as Map<String, dynamic>,
        j['air'] as Map<String, dynamic>?,
        DateTime.parse(j['fetchedAt'] as String),
      );

  Forecast parse() {
    double d(dynamic v, [double fallback = 0]) =>
        v is num ? v.toDouble() : fallback;
    int i(dynamic v, [int fallback = 0]) => v is num ? v.round() : fallback;

    final c = forecast['current'] as Map<String, dynamic>;
    final h = forecast['hourly'] as Map<String, dynamic>;
    final dl = forecast['daily'] as Map<String, dynamic>;

    final hTimes = (h['time'] as List).cast<String>().map(DateTime.parse).toList();
    final now = DateTime.parse(c['time'] as String);
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    var startIdx = hTimes.indexWhere((t) => !t.isBefore(hourStart));
    if (startIdx < 0) startIdx = 0;

    final hTemp = h['temperature_2m'] as List;
    final hPop = h['precipitation_probability'] as List;
    final hCode = h['weather_code'] as List;
    final hDay = h['is_day'] as List;
    final hUv = h['uv_index'] as List;
    final hVis = h['visibility'] as List;

    final hours = <Hour>[];
    for (var k = startIdx; k < hTimes.length && hours.length < 25; k++) {
      hours.add(Hour(hTimes[k], d(hTemp[k]), i(hPop[k]), i(hCode[k]),
          i(hDay[k], 1) == 1));
    }

    final current = Current(
      time: now,
      temp: d(c['temperature_2m']),
      feelsLike: d(c['apparent_temperature']),
      humidity: i(c['relative_humidity_2m']),
      isDay: i(c['is_day'], 1) == 1,
      precip: d(c['precipitation']),
      code: i(c['weather_code']),
      cloudCover: i(c['cloud_cover']),
      pressure: d(c['pressure_msl']),
      wind: d(c['wind_speed_10m']),
      gusts: d(c['wind_gusts_10m']),
      windDir: i(c['wind_direction_10m']),
      uv: d(hUv[startIdx]),
      visibility: d(hVis[startIdx], 10000),
    );

    final dTimes = (dl['time'] as List).cast<String>();
    final days = <Day>[
      for (var k = 0; k < dTimes.length; k++)
        Day(
          date: DateTime.parse(dTimes[k]),
          code: i((dl['weather_code'] as List)[k]),
          max: d((dl['temperature_2m_max'] as List)[k]),
          min: d((dl['temperature_2m_min'] as List)[k]),
          precipChance: i((dl['precipitation_probability_max'] as List)[k]),
          precipSum: d((dl['precipitation_sum'] as List)[k]),
          uvMax: d((dl['uv_index_max'] as List)[k]),
          windMax: d((dl['wind_speed_10m_max'] as List)[k]),
          sunrise: DateTime.tryParse('${(dl['sunrise'] as List)[k]}'),
          sunset: DateTime.tryParse('${(dl['sunset'] as List)[k]}'),
        ),
    ];

    AirQuality? aq;
    final ac = air?['current'] as Map<String, dynamic>?;
    if (ac != null && ac['us_aqi'] is num) {
      aq = AirQuality(i(ac['us_aqi']), d(ac['pm2_5']), d(ac['pm10']));
    }

    return Forecast(
      place: place,
      current: current,
      hours: hours,
      days: days,
      air: aq,
      fetchedAt: fetchedAt,
    );
  }
}
