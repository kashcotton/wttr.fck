import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wttr_fck/content/content.dart';
import 'package:wttr_fck/main.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/state/app_state.dart';
import 'package:flutter/rendering.dart';

import 'helpers.dart';

int _paints = 0;

void _startCounting() {
  _paints = 0;
  debugProfilePaintsEnabled = true;
  debugOnProfilePaint = (ro) {
    _paints++;
  };
}

int _stopCounting() {
  debugProfilePaintsEnabled = false;
  debugOnProfilePaint = null;
  return _paints;
}

void main() {
  late Content content;
  setUpAll(() async => content = await diskContent());

  Future<AppState> pumpApp(WidgetTester tester, {int code = 0}) async {
    final raw = RawForecast(const Place(name: 'Testville', lat: 0, lon: 0),
        sample(code: code, temp: 22, cloud: 0), null, DateTime(2026, 11, 21, 14));
    SharedPreferences.setMockInitialValues({
      'cache': jsonEncode(raw.toJson()),
      'onboarded': true,
    });
    final state = AppState(await SharedPreferences.getInstance(), content,
        fetchContent: false);
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WttrApp(state: state));

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return state;
  }

  testWidgets('idle sunny page does not repaint the content', (tester) async {
    await pumpApp(tester, code: 0);
    _startCounting();
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final paints = _stopCounting();

    expect(paints, 0,
        reason: 'Something keeps animating while the page is idle');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('re-rolling a roast does not repaint other cards', (tester) async {
    final state = await pumpApp(tester, code: 3);
    _startCounting();
    state.reroll();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final paints = _stopCounting();

    expect(paints, lessThan(8000),
        reason: 'Re-rolling a roast repaints far more than the roast card');
    await tester.pumpWidget(const SizedBox());
  });
}
