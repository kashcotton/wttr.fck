import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/services/warnings.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/util/units.dart';
import 'package:wttr_fck/widgets/cards.dart';

import 'helpers.dart';

String _iso(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

void main() {
  test('US points get National Weather Service alerts, newest severity first', () async {
    late Uri asked;
    final client = MockClient((req) async {
      asked = req.url;
      return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'event': 'Wind Advisory',
                  'severity': 'Moderate',
                  'description': 'Gusts to 50 mph.',
                  'expires': _iso(const Duration(hours: 5)),
                  'senderName': 'NWS Chicago IL',
                },
              },
              {
                'properties': {
                  'event': 'Tornado Warning',
                  'severity': 'Extreme',
                  'description': 'Take shelter now.',
                  'instruction': 'Go to a basement.',
                  'expires': _iso(const Duration(hours: 1)),
                  'senderName': 'NWS Chicago IL',
                },
              },
              {
                'properties': {
                  'event': 'Old Advisory',
                  'severity': 'Minor',
                  'description': 'Over.',
                  'expires': _iso(const Duration(hours: -1)),
                },
              },
            ],
          }),
          200);
    });
    final alerts = await WarningsService(client: client).official(const Place(
        name: 'Chicago', countryCode: 'US', lat: 41.88, lon: -87.63));
    expect(asked.host, 'api.weather.gov');
    expect(asked.queryParameters['point'], '41.8800,-87.6300');
    expect(alerts.map((a) => a.title), ['Tornado Warning', 'Wind Advisory']);
    expect(alerts.first.level, AlertLevel.extreme);
    expect(alerts.first.instruction, 'Go to a basement.');
  });

  test('MeteoAlarm matches by polygon when there is one, by region name when not', () async {
    Map<String, dynamic> warning(String event, Map<String, dynamic> area) => {
          'alert': {
            'msgType': 'Alert',
            'info': [
              {
                'language': 'en-GB',
                'event': event,
                'severity': 'Moderate',
                'description': 'Watch out.',
                'expires': _iso(const Duration(hours: 6)),
                'senderName': 'Met Office',
                'parameter': [
                  {'valueName': 'awareness_level', 'value': '2; yellow; Moderate'},
                ],
                'area': [area],
              },
            ],
          },
        };
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'warnings': [
            warning('Rain warning', {
              'areaDesc': 'London & South East England',
              'polygon': ['51.0,-1.0 52.0,-1.0 52.0,1.0 51.0,1.0 51.0,-1.0'],
            }),
            warning('Snow warning', {
              'areaDesc': 'Highlands',
              'polygon': ['57.0,-6.0 58.0,-6.0 58.0,-4.0 57.0,-4.0 57.0,-6.0'],
            }),
            warning('Wind warning', {'areaDesc': 'Greater London'}),
          ],
        }),
        200));
    final alerts = await WarningsService(client: client).official(const Place(
      name: 'London',
      countryCode: 'GB',
      areas: ['England', 'Greater London'],
      lat: 51.5,
      lon: -0.12,
    ));
    expect(alerts.map((a) => a.title).toSet(), {'Rain warning', 'Wind warning'});
  });

  test('Canada keeps only alerts whose polygon covers the place', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'features': [
            {
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [[-80.0, 43.0], [-79.0, 43.0], [-79.0, 44.0], [-80.0, 44.0], [-80.0, 43.0]],
                ],
              },
              'properties': {
                'alert_name_en': 'snowfall warning',
                'alert_type': 'warning',
                'risk_colour_en': 'orange',
                'alert_text_en': 'Lots of snow.',
                'status_en': 'issued',
                'event_end_datetime': _iso(const Duration(hours: 8)),
              },
            },
            {
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [[-70.0, 45.0], [-69.0, 45.0], [-69.0, 46.0], [-70.0, 46.0], [-70.0, 45.0]],
                ],
              },
              'properties': {
                'alert_name_en': 'fog advisory',
                'alert_type': 'advisory',
                'alert_text_en': 'Fog.',
                'status_en': 'issued',
              },
            },
          ],
        }),
        200));
    final alerts = await WarningsService(client: client).official(const Place(
        name: 'Toronto', countryCode: 'CA', lat: 43.65, lon: -79.38));
    expect(alerts.single.title, 'Snowfall warning');
    expect(alerts.single.level, AlertLevel.severe);
  });

  test('a failing warning service never breaks the app', () async {
    final client = MockClient((_) async => http.Response('nope', 500));
    final alerts = await WarningsService(client: client).official(
        const Place(name: 'Chicago', countryCode: 'US', lat: 41.88, lon: -87.63));
    expect(alerts, isEmpty);
  });

  test('forecast heads-ups flag dangerous heat and storms, in your units', () {
    final raw = sample(temp: 40, code: 95);
    final f = RawForecast(const Place(name: 'Phoenix', lat: 33, lon: -112),
            raw, null, DateTime(2026, 11, 21, 14))
        .parse();
    final h = headsUps(f, const Units(TempUnit.f, WindUnit.mph));
    expect(h.map((a) => a.title), containsAll(['Dangerous heat', 'Thunderstorms']));
    expect(h.every((a) => !a.official), isTrue);
    expect(h.first.description, contains('°F'));
  });

  test('nowcast says when rain starts', () {
    final raw = sample();
    raw['minutely_15'] = {
      'time': [
        for (var i = 0; i < 8; i++)
          DateTime(2026, 11, 21, 14, 15)
              .add(Duration(minutes: 15 * i))
              .toIso8601String()
              .substring(0, 16),
      ],
      'precipitation': [0, 0, 0.4, 0.8, 0.5, 0, 0, 0],
    };
    final f = RawForecast(const Place(name: 'X', lat: 0, lon: 0), raw, null,
            DateTime(2026, 11, 21, 14))
        .parse();
    expect(nowcastLine(f), 'Rain starting in about 30 minutes.');
  });
}
