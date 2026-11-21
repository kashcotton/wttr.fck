/// Plain data models. Everything is stored metric (°C, km/h, mm, hPa, m)
/// and converted for display in `util/units.dart`.
library;

class Place {
  final String name;
  final String? region;
  final String? country;
  final double lat;
  final double lon;

  const Place({
    required this.name,
    this.region,
    this.country,
    required this.lat,
    required this.lon,
  });

  String get subtitle =>
      [region, country].where((s) => s != null && s.isNotEmpty).join(', ');

  String get id => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'region': region,
        'country': country,
        'lat': lat,
        'lon': lon,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        region: j['region'] as String?,
        country: j['country'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// Broad buckets the roast engine and theming care about.
enum Sky { clear, partly, cloudy, fog, drizzle, rain, snow, storm }

Sky skyFromCode(int code) {
  if (code == 0) return Sky.clear;
  if (code <= 2) return Sky.partly;
  if (code == 3) return Sky.cloudy;
  if (code == 45 || code == 48) return Sky.fog;
  if (code >= 51 && code <= 57) return Sky.drizzle;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return Sky.rain;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return Sky.snow;
  if (code >= 95) return Sky.storm;
  return Sky.cloudy;
}

String describeCode(int code) {
  switch (code) {
    case 0:
      return 'Clear';
    case 1:
      return 'Mostly clear';
    case 2:
      return 'Partly cloudy';
    case 3:
      return 'Overcast';
    case 45:
    case 48:
      return 'Fog';
    case 51:
    case 53:
    case 55:
      return 'Drizzle';
    case 56:
    case 57:
      return 'Freezing drizzle';
    case 61:
      return 'Light rain';
    case 63:
      return 'Rain';
    case 65:
      return 'Heavy rain';
    case 66:
    case 67:
      return 'Freezing rain';
    case 71:
      return 'Light snow';
    case 73:
      return 'Snow';
    case 75:
      return 'Heavy snow';
    case 77:
      return 'Snow grains';
    case 80:
    case 81:
      return 'Showers';
    case 82:
      return 'Violent showers';
    case 85:
    case 86:
      return 'Snow showers';
    case 95:
      return 'Thunderstorm';
    case 96:
    case 99:
      return 'Thunderstorm with hail';
    default:
      return 'Weather';
  }
}

class Current {
  final DateTime time;
  final double temp;
  final double feelsLike;
  final int humidity;
  final bool isDay;
  final double precip;
  final int code;
  final int cloudCover;
  final double pressure;
  final double wind;
  final double gusts;
  final int windDir;
  final double uv;
  final double visibility;

  const Current({
    required this.time,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.isDay,
    required this.precip,
    required this.code,
    required this.cloudCover,
    required this.pressure,
    required this.wind,
    required this.gusts,
    required this.windDir,
    required this.uv,
    required this.visibility,
  });

  Sky get sky => skyFromCode(code);
}

class Hour {
  final DateTime time;
  final double temp;
  final int precipChance;
  final int code;
  final bool isDay;
  const Hour(this.time, this.temp, this.precipChance, this.code, this.isDay);
}

class Day {
  final DateTime date;
  final int code;
  final double max;
  final double min;
  final int precipChance;
  final double precipSum;
  final double uvMax;
  final double windMax;
  final DateTime? sunrise;
  final DateTime? sunset;

  const Day({
    required this.date,
    required this.code,
    required this.max,
    required this.min,
    required this.precipChance,
    required this.precipSum,
    required this.uvMax,
    required this.windMax,
    this.sunrise,
    this.sunset,
  });
}

class AirQuality {
  final int usAqi;
  final double pm25;
  final double pm10;
  const AirQuality(this.usAqi, this.pm25, this.pm10);
}

class Forecast {
  final Place place;
  final Current current;
  final List<Hour> hours; // next 24h starting at the current hour
  final List<Day> days;
  final AirQuality? air;
  final DateTime fetchedAt;

  const Forecast({
    required this.place,
    required this.current,
    required this.hours,
    required this.days,
    required this.air,
    required this.fetchedAt,
  });

  Day get today => days.first;
}
