library;

class Place {
  final String name;
  final String? region;
  final String? country;
  final String? countryCode;
  final List<String> areas;
  final double lat;
  final double lon;

  const Place({
    required this.name,
    this.region,
    this.country,
    this.countryCode,
    this.areas = const [],
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
        if (countryCode != null) 'countryCode': countryCode,
        if (areas.isNotEmpty) 'areas': areas,
        'lat': lat,
        'lon': lon,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        region: j['region'] as String?,
        country: j['country'] as String?,
        countryCode: j['countryCode'] as String?,
        areas: (j['areas'] as List?)?.whereType<String>().toList() ?? const [],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

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
  final double? dewPoint;

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
    this.dewPoint,
  });

  Sky get sky => skyFromCode(code);
}

class Hour {
  final DateTime time;
  final double temp;
  final int precipChance;
  final int code;
  final bool isDay;
  final double precip;
  final double wind;
  final double gusts;
  final int windDir;
  final double? feels;
  final int? humidity;
  final double uv;
  const Hour(
    this.time,
    this.temp,
    this.precipChance,
    this.code,
    this.isDay, {
    this.precip = 0,
    this.wind = 0,
    this.gusts = 0,
    this.windDir = 0,
    this.feels,
    this.humidity,
    this.uv = 0,
  });
}

class Nowcast {
  final DateTime time;
  final double mm;
  const Nowcast(this.time, this.mm);
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
  final List<Hour> hours;
  final List<Hour> allHours;
  final List<Day> days;
  final AirQuality? air;
  final List<Nowcast> nowcast;
  final DateTime fetchedAt;
  final Duration? utcOffset;

  const Forecast({
    required this.place,
    required this.current,
    required this.hours,
    required this.days,
    required this.air,
    required this.fetchedAt,
    this.allHours = const [],
    this.nowcast = const [],
    this.utcOffset,
  });

  Day get today => days.first;

  DateTime localTime(DateTime t) {
    final o = utcOffset;
    if (o == null) return t.toLocal();
    final u = t.toUtc().add(o);
    return DateTime(u.year, u.month, u.day, u.hour, u.minute);
  }

  List<Hour> hoursOn(DateTime day) => allHours
      .where((h) =>
          h.time.year == day.year &&
          h.time.month == day.month &&
          h.time.day == day.day)
      .toList();
}
