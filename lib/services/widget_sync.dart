import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../content/content.dart';
import '../roasts/censor.dart';
import '../state/app_state.dart';
import '../util/units.dart';

/// Keeps the Android home-screen widget in sync with the app.
///
/// The widget itself is native Android (android/.../widget/). It reads what
/// we save here, and refreshes the weather on its own in the background,
/// picking new roasts from the pack we hand it. Every value is a String so
/// Dart and Kotlin never disagree about types.
class WidgetSync {
  static const provider = 'com.wttrfck.wttr_fck.widget.WeatherWidget';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> push(AppState s) async {
    if (!supported) return;
    final f = s.forecast;
    final e = s.engine;
    if (f == null || e == null) return;
    try {
      final c = f.current;
      final roast = e.roast(s.voice, s.roastSeed);

      // Every mood, in the user's voice (falling back to Classic), already
      // filtered to their language level. Placeholders stay in so the
      // widget can fill them with fresh numbers later.
      final pack = <String, List<List<String>>>{
        for (final m in Mood.values)
          m.name: [
            for (final l in s.voice.lines[m] ?? s.content.classic.lines[m]!)
              [censor(l.head, s.profanity), censor(l.sub, s.profanity)],
          ],
      };

      final data = <String, String>{
        'w_place': f.place.name,
        'w_lat': '${f.place.lat}',
        'w_lon': '${f.place.lon}',
        'w_temp_unit': s.tempUnit == TempUnit.f ? 'f' : 'c',
        'w_wind_unit': s.windUnit.name,
        'w_head': roast.head,
        'w_sub': roast.sub,
        'w_pack': jsonEncode(pack),
        'w_updated': '${f.fetchedAt.millisecondsSinceEpoch}',
        'r_temp': '${c.temp}',
        'r_feels': '${c.feelsLike}',
        'r_high': '${f.today.max}',
        'r_low': '${f.today.min}',
        'r_wind': '${c.wind}',
        'r_gusts': '${c.gusts}',
        'r_pop': '${f.today.precipChance}',
        'r_uv': '${c.uv}',
        'r_vis': '${c.visibility}',
        'r_code': '${c.code}',
        'r_isday': c.isDay ? '1' : '0',
      };
      await Future.wait([
        for (final e in data.entries)
          HomeWidget.saveWidgetData<String>(e.key, e.value),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    } catch (_) {
      // No widget plugin (tests, unsupported launcher): nothing to do.
    }
  }

  static Future<bool> canPin() async {
    if (!supported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pin() =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: provider);
}
