import 'dart:io';

import 'package:wttr_fck/content/content.dart';

Future<Content> diskContent() =>
    parseContent((p) => File('content/$p').readAsString());

Map<String, dynamic> sample({
  int code = 0,
  double temp = 20,
  int isDay = 1,
  int cloud = 20,
  double gusts = 20,
  int pop = 30,
}) {
  final hours = List.generate(48, (i) {
    final h = DateTime(2026, 11, 21, 0).add(Duration(hours: i));
    return '${h.toIso8601String().substring(0, 13)}:00';
  });
  final days =
      List.generate(10, (i) => '2026-11-${(21 + i).toString().padLeft(2, '0')}');

  final temps = List.generate(48, (i) => temp + 4 * (1 - ((i % 24) - 15).abs() / 12));
  return {
    'current': {
      'time': '2026-11-21T14:15',
      'temperature_2m': temp,
      'relative_humidity_2m': 60,
      'apparent_temperature': temp,
      'is_day': isDay,
      'precipitation': 0,
      'weather_code': code,
      'cloud_cover': cloud,
      'pressure_msl': 1013,
      'wind_speed_10m': 10,
      'wind_direction_10m': 200,
      'wind_gusts_10m': gusts,
    },
    'hourly': {
      'time': hours,
      'temperature_2m': temps,
      'precipitation_probability': List.generate(48, (i) => (pop + (i % 5) * 8).clamp(0, 100)),
      'weather_code': List.filled(48, code),
      'is_day': List.filled(48, isDay),
      'uv_index': List.filled(48, 3.0),
      'visibility': List.filled(48, null),
    },
    'daily': {
      'time': days,
      'weather_code': List.generate(10, (i) => [code, 3, 61, 0, 2, 73, 95, 1, 63, 0][i]),
      'temperature_2m_max': List.generate(10, (i) => temp + 3 + (i % 4)),
      'temperature_2m_min': List.generate(10, (i) => temp - 5 - (i % 3)),
      'sunrise': List.filled(10, '2026-11-21T06:55'),
      'sunset': List.filled(10, '2026-11-21T16:40'),
      'uv_index_max': List.filled(10, 4.0),
      'precipitation_probability_max': List.generate(10, (i) => (pop + i * 7) % 100),
      'precipitation_sum': List.filled(10, 0.0),
      'wind_speed_10m_max': List.filled(10, 15.0),
    },
  };
}
