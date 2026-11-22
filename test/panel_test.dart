import 'package:flutter_test/flutter_test.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/roasts/engine.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/util/units.dart';

import 'helpers.dart';

void main() {
  late Content content;
  setUpAll(() async => content = await diskContent());

  RoastEngine engine(int code) => RoastEngine(
        RawForecast(const Place(name: 'Testville', lat: 0, lon: 0),
                sample(code: code), null, DateTime(2026))
            .parse(),
        const Units(TempUnit.c, WindUnit.kmh),
        Profanity.salty,
        content,
      );

  test('the roster has plenty of made-up pundits on both sides', () {
    expect(content.pundits.left.length, greaterThanOrEqualTo(20));
    expect(content.pundits.right.length, greaterThanOrEqualTo(20));
    expect(content.pundits.weather.length, greaterThanOrEqualTo(5));
  });

  test('every mood has at least ten panel takes', () {
    for (final m in Mood.values) {
      expect(content.panels[m]!.length, greaterThanOrEqualTo(10), reason: m.name);
    }
  });

  test('consecutive takes never repeat a line until the pool runs out', () {
    for (final code in [0, 3, 63, 73, 95]) {
      final e = engine(code);
      final n = content.panels[e.mood]!.length;
      final seen = <String>{};
      for (var seed = 500; seed < 500 + n; seed++) {
        expect(seen.add(e.panel(seed).left), isTrue,
            reason: '${e.mood.name}: repeated a take before showing them all');
      }
    }
  });

  test('pundit names change from one take to the next', () {
    final e = engine(0);
    for (var seed = 0; seed < 200; seed++) {
      final a = e.panel(seed), b = e.panel(seed + 1);
      expect(a.leftWho.name, isNot(b.leftWho.name));
      expect(a.rightWho.name, isNot(b.rightWho.name));
    }
  });
}
