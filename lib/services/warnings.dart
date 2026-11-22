import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';
import '../util/units.dart';

enum AlertLevel { info, minor, moderate, severe, extreme }

class WeatherAlert {
  final String title;
  final String? headline;
  final String description;
  final String? instruction;
  final AlertLevel level;
  final DateTime? start;
  final DateTime? end;
  final String source;
  final String? area;
  final String? url;
  final bool official;

  const WeatherAlert({
    required this.title,
    required this.description,
    required this.level,
    required this.source,
    this.headline,
    this.instruction,
    this.start,
    this.end,
    this.area,
    this.url,
    this.official = true,
  });

  String get key => '$source|$title|${start?.millisecondsSinceEpoch}';
}

class WarningsService {
  WarningsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _feedCache = <String, (DateTime, List)>{};

  static const _ua = {
    'User-Agent': 'wttr.fck (github.com/kashcotton/wttr.fck)',
  };

  Future<dynamic> _json(Uri uri, {Map<String, String>? headers}) async {
    final res = await _client
        .get(uri, headers: {if (!kIsWeb) ..._ua, ...?headers})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<WeatherAlert>> official(Place p) async {
    final cc = (p.countryCode ?? _guessCountry(p.lat, p.lon))?.toUpperCase();
    try {
      final List<WeatherAlert> found = switch (cc) {
        'US' || 'PR' || 'GU' || 'VI' || 'AS' || 'MP' => await _nws(p),
        'CA' => await _canada(p),
        'DE' => await _germany(p),
        _ when _meteoalarm.containsKey(cc) && !kIsWeb => await _europe(p, cc!),
        _ => const [],
      };
      final now = DateTime.now();
      final live = found
          .where((a) => a.end == null || a.end!.isAfter(now))
          .toList()
        ..sort((a, b) => b.level.index.compareTo(a.level.index));
      final merged = <String, WeatherAlert>{};
      for (final a in live) {
        final k = a.title.toLowerCase();
        final prev = merged[k];
        merged[k] = prev == null ? a : _merge(prev, a);
      }
      return merged.values.toList()
        ..sort((a, b) => b.level.index.compareTo(a.level.index));
    } catch (_) {
      return const [];
    }
  }

  static WeatherAlert _merge(WeatherAlert a, WeatherAlert b) {
    DateTime? min(DateTime? x, DateTime? y) =>
        x == null || y == null ? null : (x.isBefore(y) ? x : y);
    DateTime? max(DateTime? x, DateTime? y) =>
        x == null || y == null ? null : (x.isAfter(y) ? x : y);
    final top = b.level.index > a.level.index ? b : a;
    return WeatherAlert(
      title: top.title,
      headline: top.headline,
      description: top.description,
      instruction: top.instruction,
      level: top.level,
      start: min(a.start, b.start),
      end: max(a.end, b.end),
      source: top.source,
      area: top.area,
      url: top.url,
      official: top.official,
    );
  }

  static bool covered(Place p) {
    final cc = (p.countryCode ?? _guessCountry(p.lat, p.lon))?.toUpperCase();
    if (cc == null) return false;
    if (const {'US', 'PR', 'GU', 'VI', 'AS', 'MP', 'CA', 'DE'}.contains(cc)) {
      return true;
    }
    return _meteoalarm.containsKey(cc) && !kIsWeb;
  }

  static String? _guessCountry(double lat, double lon) {
    if (lat > 24 && lat < 50 && lon > -125 && lon < -66) return 'US';
    if (lat > 51 && lat < 72 && lon > -170 && lon < -129) return 'US';
    if (lat > 18.5 && lat < 22.5 && lon > -161 && lon < -154) return 'US';
    if (lat > 47.2 && lat < 55.1 && lon > 5.8 && lon < 15.1) return 'DE';
    return null;
  }

  static AlertLevel _cap(String? severity) =>
      switch (severity?.toLowerCase()) {
        'extreme' => AlertLevel.extreme,
        'severe' => AlertLevel.severe,
        'moderate' => AlertLevel.moderate,
        'minor' => AlertLevel.minor,
        _ => AlertLevel.info,
      };

  static String _title(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final lower = t == t.toUpperCase() ? t.toLowerCase() : t;
    return lower[0].toUpperCase() + lower.substring(1);
  }

  Future<List<WeatherAlert>> _nws(Place p) async {
    final j = await _json(
      Uri.https('api.weather.gov', '/alerts/active', {
        'point': '${p.lat.toStringAsFixed(4)},${p.lon.toStringAsFixed(4)}',
      }),
      headers: {'Accept': 'application/geo+json'},
    );
    final features = (j['features'] as List?) ?? const [];
    return [
      for (final f in features)
        if (f is Map && f['properties'] is Map)
          _nwsAlert(f['properties'] as Map, p),
    ];
  }

  WeatherAlert _nwsAlert(Map a, Place p) => WeatherAlert(
        title: _title('${a['event'] ?? 'Weather alert'}'),
        headline: a['headline'] as String?,
        description: _clean(a['description'] as String? ?? ''),
        instruction: _cleanOrNull(a['instruction'] as String?),
        level: _cap(a['severity'] as String?),
        start: DateTime.tryParse('${a['onset'] ?? a['effective']}')?.toLocal(),
        end: DateTime.tryParse('${a['ends'] ?? a['expires']}')?.toLocal(),
        source: a['senderName'] as String? ?? 'National Weather Service',
        area: a['areaDesc'] as String?,
        url: 'https://forecast.weather.gov/MapClick.php'
            '?lat=${p.lat.toStringAsFixed(4)}&lon=${p.lon.toStringAsFixed(4)}',
      );

  Future<List<WeatherAlert>> _canada(Place p) async {
    const d = 0.01;
    final j = await _json(Uri.https(
      'api.weather.gc.ca',
      '/collections/weather-alerts/items',
      {
        'f': 'json',
        'lang': 'en',
        'limit': '50',
        'bbox': '${p.lon - d},${p.lat - d},${p.lon + d},${p.lat + d}',
      },
    ));
    final out = <WeatherAlert>[];
    for (final f in (j['features'] as List?) ?? const []) {
      if (f is! Map) continue;
      final a = f['properties'] as Map? ?? const {};
      final status = '${a['status_en']}'.toLowerCase();
      if (status == 'ended' || status == 'cancelled') continue;
      final g = f['geometry'];
      if (g is Map && !_inGeometry(g, p.lat, p.lon)) continue;
      final colour = '${a['risk_colour_en']}'.toLowerCase();
      final type = '${a['alert_type']}'.toLowerCase();
      out.add(WeatherAlert(
        title: _title('${a['alert_name_en'] ?? a['alert_short_name_en']}'),
        description: _clean('${a['alert_text_en'] ?? ''}'),
        level: switch (colour) {
          'red' => AlertLevel.extreme,
          'orange' => AlertLevel.severe,
          'yellow' => AlertLevel.moderate,
          _ => type == 'warning'
              ? AlertLevel.severe
              : type == 'watch'
                  ? AlertLevel.moderate
                  : AlertLevel.minor,
        },
        start: DateTime.tryParse('${a['validity_datetime']}')?.toLocal(),
        end: DateTime.tryParse(
                '${a['event_end_datetime'] ?? a['expiration_datetime']}')
            ?.toLocal(),
        source: 'Environment Canada',
        area: a['feature_name_en'] as String?,
        url: 'https://weather.gc.ca/warnings/index_e.html',
      ));
    }
    return out;
  }

  Future<List<WeatherAlert>> _germany(Place p) async {
    final j = await _json(Uri.https('api.brightsky.dev', '/alerts', {
      'lat': p.lat.toStringAsFixed(4),
      'lon': p.lon.toStringAsFixed(4),
    }));
    final loc = j['location'] as Map?;
    return [
      for (final a in (j['alerts'] as List?) ?? const [])
        if (a is Map)
          WeatherAlert(
            title: _title('${a['event_en'] ?? a['event_de'] ?? 'Warning'}'),
            headline: a['headline_en'] as String? ?? a['headline_de'] as String?,
            description: _clean(
                '${a['description_en'] ?? a['description_de'] ?? ''}'),
            instruction: _cleanOrNull(
                a['instruction_en'] as String? ?? a['instruction_de'] as String?),
            level: _cap(a['severity'] as String?),
            start: DateTime.tryParse('${a['onset'] ?? a['effective']}')?.toLocal(),
            end: DateTime.tryParse('${a['expires']}')?.toLocal(),
            source: 'Deutscher Wetterdienst',
            area: loc?['name'] as String?,
            url: 'https://www.dwd.de/DE/wetter/warnungen/warnWetter_node.html',
          ),
    ];
  }

  Future<List<WeatherAlert>> _europe(Place p, String cc) async {
    final slug = _meteoalarm[cc]!;
    final cached = _feedCache[slug];
    List warnings;
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 15)) {
      warnings = cached.$2;
    } else {
      final j = await _json(Uri.https(
          'feeds.meteoalarm.org', '/api/v1/warnings/feeds-$slug'));
      warnings = (j['warnings'] as List?) ?? const [];
      _feedCache[slug] = (DateTime.now(), warnings);
    }

    final names = {
      for (final n in [p.name, p.region, ...p.areas])
        if (n != null && n.trim().isNotEmpty) _norm(n),
    };
    final out = <WeatherAlert>[];
    for (final w in warnings) {
      final alert = (w is Map ? w['alert'] : null) as Map?;
      if (alert == null) continue;
      if ('${alert['msgType']}'.toLowerCase() == 'cancel') continue;
      final infos = ((alert['info'] as List?) ?? const []).whereType<Map>().toList();
      if (infos.isEmpty) continue;
      final info = infos.firstWhere(
        (i) => '${i['language']}'.toLowerCase().startsWith('en'),
        orElse: () => infos.first,
      );
      final areas = ((info['area'] as List?) ?? const []).whereType<Map>();
      String? matched;
      for (final a in areas) {
        if (_areaMatches(a, p, names)) {
          matched = a['areaDesc'] as String?;
          break;
        }
      }
      if (matched == null) {
        for (final other in infos) {
          for (final a in ((other['area'] as List?) ?? const []).whereType<Map>()) {
            if (_areaMatches(a, p, names)) {
              matched = (areas.isNotEmpty ? areas.first['areaDesc'] : null) as String? ??
                  a['areaDesc'] as String?;
              break;
            }
          }
          if (matched != null) break;
        }
      }
      if (matched == null) continue;

      var level = _cap(info['severity'] as String?);
      for (final par in (info['parameter'] as List?) ?? const []) {
        if (par is Map && par['valueName'] == 'awareness_level') {
          final v = '${par['value']}'.toLowerCase();
          if (v.contains('red')) level = AlertLevel.extreme;
          if (v.contains('orange')) level = AlertLevel.severe;
          if (v.contains('yellow')) level = AlertLevel.moderate;
          if (v.contains('green')) level = AlertLevel.info;
        }
      }
      if (level == AlertLevel.info) continue;
      out.add(WeatherAlert(
        title: _title('${info['event'] ?? info['headline'] ?? 'Weather warning'}'),
        headline: info['headline'] as String?,
        description: _clean('${info['description'] ?? ''}'),
        instruction: _cleanOrNull(info['instruction'] as String?),
        level: level,
        start: DateTime.tryParse('${info['onset'] ?? info['effective']}')?.toLocal(),
        end: DateTime.tryParse('${info['expires']}')?.toLocal(),
        source: info['senderName'] as String? ?? 'MeteoAlarm',
        area: matched,
        url: info['web'] as String? ?? 'https://meteoalarm.org',
      ));
    }
    return out;
  }

  static bool _areaMatches(Map a, Place p, Set<String> names) {
    final polys = a['polygon'];
    if (polys is List && polys.isNotEmpty) {
      for (final poly in polys) {
        if (poly is String && _inCapPolygon(poly, p.lat, p.lon)) return true;
      }
      return false;
    }
    final desc = a['areaDesc'];
    if (desc is! String || names.isEmpty) return false;
    final d = _norm(desc);
    for (final part in d.split(RegExp(r'\s*[,|/;]\s*|\s+and\s+'))) {
      if (part.isNotEmpty && names.contains(part)) return true;
    }
    for (final n in names) {
      if (n.length >= 4 && RegExp('(^| )${RegExp.escape(n)}( |\$)').hasMatch(d)) {
        return true;
      }
    }
    return false;
  }

  static String _norm(String s) {
    const from = 'àáâãäåāăąçćčďđèéêëēėęěğìíîïīįıľłñńňòóôõöøōőŕřśšşșťţțùúûüūůűųýÿžźżß';
    const to = 'aaaaaaaaacccddeeeeeeeegiiiiiiilinnnoooooooorrsssstttuuuuuuuuyyzzzs';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b
        .toString()
        .replaceAll(RegExp(r'\b(county|province|region|district|kraj|powiat|wojewodztwo|department|departement|state)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9,|/;\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'^of '), '');
  }

  static bool _inCapPolygon(String poly, double lat, double lon) {
    final pts = <(double, double)>[];
    for (final pair in poly.trim().split(RegExp(r'\s+'))) {
      final xy = pair.split(',');
      if (xy.length != 2) continue;
      final a = double.tryParse(xy[0]);
      final b = double.tryParse(xy[1]);
      if (a != null && b != null) pts.add((a, b));
    }
    return _inRing(pts, lat, lon);
  }

  static bool _inGeometry(Map g, double lat, double lon) {
    List<List> polygons;
    if (g['type'] == 'Polygon') {
      polygons = [g['coordinates'] as List];
    } else if (g['type'] == 'MultiPolygon') {
      polygons = (g['coordinates'] as List).cast<List>();
    } else {
      return true;
    }
    for (final poly in polygons) {
      if (poly.isEmpty) continue;
      final ring = [
        for (final c in poly.first as List)
          ((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      if (_inRing(ring, lat, lon)) return true;
    }
    return false;
  }

  static bool _inRing(List<(double, double)> ring, double lat, double lon) {
    if (ring.length < 3) return false;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final (yi, xi) = ring[i];
      final (yj, xj) = ring[j];
      if ((yi > lat) != (yj > lat) &&
          lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  static String _clean(String s) => s
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static String? _cleanOrNull(String? s) {
    if (s == null) return null;
    final c = _clean(s);
    return c.isEmpty ? null : c;
  }

  static const _meteoalarm = {
    'AT': 'austria', 'BE': 'belgium', 'BA': 'bosnia-herzegovina',
    'BG': 'bulgaria', 'HR': 'croatia', 'CY': 'cyprus', 'CZ': 'czechia',
    'DK': 'denmark', 'EE': 'estonia', 'FI': 'finland', 'FR': 'france',
    'GR': 'greece', 'HU': 'hungary', 'IS': 'iceland', 'IE': 'ireland',
    'IL': 'israel', 'IT': 'italy', 'LV': 'latvia', 'LT': 'lithuania',
    'LU': 'luxembourg', 'MT': 'malta', 'MD': 'moldova', 'ME': 'montenegro',
    'NL': 'netherlands', 'MK': 'republic-of-north-macedonia', 'NO': 'norway',
    'PL': 'poland', 'PT': 'portugal', 'RO': 'romania', 'RS': 'serbia',
    'SK': 'slovakia', 'SI': 'slovenia', 'ES': 'spain', 'SE': 'sweden',
    'CH': 'switzerland', 'UA': 'ukraine', 'GB': 'united-kingdom',
  };
}

List<WeatherAlert> headsUps(Forecast f, Units u) {
  final out = <WeatherAlert>[];
  final now = f.current.time;
  final next = f.allHours
      .where((h) => h.time.isAfter(now.subtract(const Duration(hours: 1))))
      .take(36)
      .toList();
  if (next.isEmpty) return out;
  DateTime first(bool Function(Hour) test) => next.firstWhere(test).time;

  final hot = next.where((h) => (h.feels ?? h.temp) >= 38);
  if (hot.isNotEmpty) {
    final peak = hot.map((h) => h.feels ?? h.temp).reduce((a, b) => a > b ? a : b);
    out.add(WeatherAlert(
      title: 'Dangerous heat',
      description:
          'Feels-like temperatures reach ${u.degU(peak)}. Drink water, stay in the shade, check on older neighbors and pets.',
      level: peak >= 43 ? AlertLevel.severe : AlertLevel.moderate,
      start: first((h) => (h.feels ?? h.temp) >= 38),
      source: 'Forecast',
      official: false,
    ));
  }
  final cold = next.where((h) => (h.feels ?? h.temp) <= -25);
  if (cold.isNotEmpty) {
    out.add(WeatherAlert(
      title: 'Extreme cold',
      description:
          'Wind chill drops to ${u.degU(cold.map((h) => h.feels ?? h.temp).reduce((a, b) => a < b ? a : b))}. Frostbite can happen in minutes on exposed skin.',
      level: AlertLevel.severe,
      start: first((h) => (h.feels ?? h.temp) <= -25),
      source: 'Forecast',
      official: false,
    ));
  }
  final gusty = next.where((h) => h.gusts >= 75);
  if (gusty.isNotEmpty) {
    final peak = gusty.map((h) => h.gusts).reduce((a, b) => a > b ? a : b);
    out.add(WeatherAlert(
      title: 'Damaging wind gusts',
      description:
          'Gusts up to ${u.speed(peak)}. Tie down loose things outside and watch for falling branches.',
      level: peak >= 100 ? AlertLevel.severe : AlertLevel.moderate,
      start: first((h) => h.gusts >= 75),
      source: 'Forecast',
      official: false,
    ));
  }
  final rain24 = next.take(24).fold(0.0, (s, h) => s + h.precip);
  if (rain24 >= 40) {
    out.add(WeatherAlert(
      title: 'Heavy rain',
      description:
          'About ${u.precip(rain24)} of rain in the next 24 hours. Low-lying roads may flood.',
      level: rain24 >= 80 ? AlertLevel.severe : AlertLevel.moderate,
      start: first((h) => h.precip > 0),
      source: 'Forecast',
      official: false,
    ));
  }
  if (next.take(24).any((h) => h.code >= 95)) {
    final hail = next.take(24).any((h) => h.code >= 96);
    out.add(WeatherAlert(
      title: hail ? 'Thunderstorms with hail' : 'Thunderstorms',
      description:
          'Storms are in the forecast. When thunder roars, go indoors.${hail ? ' Hail is possible.' : ''}',
      level: hail ? AlertLevel.moderate : AlertLevel.minor,
      start: first((h) => h.code >= 95),
      source: 'Forecast',
      official: false,
    ));
  }
  if (next.take(24).where((h) => h.code == 75 || h.code == 86).length >= 3) {
    out.add(WeatherAlert(
      title: 'Heavy snow',
      description: 'Several hours of heavy snow. Travel could get rough.',
      level: AlertLevel.moderate,
      start: first((h) => h.code == 75 || h.code == 86),
      source: 'Forecast',
      official: false,
    ));
  }
  return out;
}
