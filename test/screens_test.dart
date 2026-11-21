@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wttr_fck/content/content.dart';
import 'package:wttr_fck/main.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/state/app_state.dart';

import 'helpers.dart';

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  Future<void> load(String family, List<String> paths) async {
    final l = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await l.load();
  }

  await load('GoogleSansFlex', ['assets/fonts/GoogleSansFlex.ttf']);
  await load('MaterialIcons',
      ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

class Case {
  final int code;
  final double temp;
  final int isDay;
  final Size size;
  final ThemeMode theme;
  final int profanity;
  final String voice;
  final List<DisplayFeature> features;
  const Case(this.code, this.temp, this.isDay, this.size, this.theme,
      this.profanity, this.voice, [this.features = const []]);
}

void main() {
  late Content content;
  setUpAll(() async {
    await loadFonts();
    content = await diskContent();
  });

  const dpr = 2.0;
  final cases = {
    'phone_rain_light': const Case(63, 9, 1, Size(412, 2400), ThemeMode.light, 2, 'pundit'),
    'phone_sunny_dark': const Case(0, 24, 1, Size(412, 2400), ThemeMode.dark, 1, 'classic'),
    'phone_night_clean': const Case(1, 14, 0, Size(360, 2400), ThemeMode.dark, 0, 'parent'),
    // Unfolded book-style foldable with a hinge down the middle.
    'foldable_open_hinge': Case(2, 17, 1, const Size(842, 1500), ThemeMode.light, 1,
        'campaign', [
      const DisplayFeature(
        bounds: Rect.fromLTWH(419 * dpr, 0, 4 * dpr, 1500 * dpr),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    ]),
    // Half-folded on a table: weather on top, details below.
    'foldable_tabletop': Case(95, 22, 1, const Size(700, 840), ThemeMode.dark, 1,
        'corporate', [
      const DisplayFeature(
        bounds: Rect.fromLTWH(0, 400 * dpr, 700 * dpr, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]),
    'desktop_snow': const Case(73, -4, 1, Size(1440, 1500), ThemeMode.light, 1, 'uncle'),
  };

  cases.forEach((name, c) {
    testWidgets(name, (tester) async {
      final raw = RawForecast(
          const Place(name: 'Portland', region: 'Oregon', country: 'United States', lat: 45.5, lon: -122.6),
          sample(code: c.code, temp: c.temp, isDay: c.isDay, cloud: c.code == 0 ? 5 : 80),
          {'current': {'us_aqi': 42, 'pm2_5': 5.0, 'pm10': 8.0}},
          DateTime(2026, 11, 21, 14, 20));
      SharedPreferences.setMockInitialValues({
        'cache': jsonEncode(raw.toJson()),
        'onboarded': true,
        'themeMode': c.theme.index,
        'profanity': c.profanity,
        'voiceId': c.voice,
        'tempUnit': 1,
        'windUnit': 1,
        'saved': [
          jsonEncode(const Place(name: 'Chicago', region: 'Illinois', country: 'United States', lat: 41.9, lon: -87.6).toJson()),
          jsonEncode(const Place(name: 'London', region: 'England', country: 'United Kingdom', lat: 51.5, lon: -0.1).toJson()),
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(prefs, content, fetchContent: false)
        ..roastSeed = 0;
      tester.view.physicalSize = c.size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.view.displayFeatures = c.features;
      await tester.pumpWidget(WttrApp(state: state));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/$name.png'));
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  });
}
