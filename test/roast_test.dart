import 'package:flutter_test/flutter_test.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/roasts/engine.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/util/units.dart';

import 'helpers.dart';

const place = Place(name: 'Testville', lat: 1, lon: 2);

Forecast fc({int code = 0, double temp = 20, int isDay = 1, int cloud = 20, double gusts = 20}) =>
    RawForecast(place, sample(code: code, temp: temp, isDay: isDay, cloud: cloud, gusts: gusts),
            null, DateTime(2026))
        .parse();

void main() {
  late Content content;
  setUpAll(() async => content = await diskContent());

  group('censor', () {
    test('unhinged passes through', () {
      expect(censor("It's fucking cold", Profanity.unhinged), "It's fucking cold");
    });
    test('salty stars the big ones, keeps the mild ones', () {
      expect(censor('Fucking hell, shit.', Profanity.salty), 'F*cking hell, sh*t.');
    });
    test('clean swaps words and keeps case', () {
      expect(censor('FUCK. Damn ass. Holy shit.', Profanity.clean),
          'FUDGE. Darn butt. Holy crud.');
    });
    test('does not touch innocent words', () {
      const s = 'Hello class, pass the shell. Assume nothing. Scrap that.';
      expect(censor(s, Profanity.clean), s);
    });
  });

  test('parses forecast and starts hourly at the current hour', () {
    final f = fc();
    expect(f.hours.first.time.hour, 14);
    expect(f.hours.length, 25);
    expect(f.days.length, 10);
    expect(f.current.visibility, 10000); // null fallback
    expect(f.air, isNull);
  });

  test('moods map sensibly', () {
    Mood m(int code, double t, [int day = 1]) => moodFor(fc(code: code, temp: t, isDay: day).current);
    expect(m(95, 20), Mood.storm);
    expect(m(73, -3), Mood.snow);
    expect(m(63, 12), Mood.rain);
    expect(m(0, 38), Mood.scorching);
    expect(m(0, -5), Mood.freezing);
    expect(m(0, 22), Mood.nice);
    expect(m(0, 18, 0), Mood.clearNight);
    expect(m(3, 15), Mood.meh);
    expect(m(0, 13), Mood.nice); // clear and cool is still a nice day
  });

  test('misery is bounded', () {
    const u = Units(TempUnit.c, WindUnit.kmh);
    for (final code in [0, 3, 45, 63, 73, 95]) {
      for (final t in [-30.0, 0.0, 21.0, 45.0]) {
        final mi = RoastEngine(fc(code: code, temp: t), u, Profanity.clean, content).misery;
        expect(mi, inInclusiveRange(0, 10));
      }
    }
  });

  test('storms are never "go outside" weather', () {
    const u = Units(TempUnit.c, WindUnit.kmh);
    final e = RoastEngine(fc(code: 95, temp: 21), u, Profanity.clean, content);
    expect(e.misery, greaterThanOrEqualTo(7));
  });

  test('election shares always add to 100 and pick a sensible winner', () {
    const u = Units(TempUnit.c, WindUnit.kmh);
    for (final code in [0, 2, 3, 45, 61, 63, 73, 95]) {
      for (final cloud in [0, 50, 100]) {
        for (final gusts in [0.0, 30.0, 90.0]) {
          final e = RoastEngine(fc(code: code, cloud: cloud, gusts: gusts), u,
                  Profanity.salty, content)
              .election(3);
          expect(e.results.fold<int>(0, (s, r) => s + r.pct), 100);
          expect(e.approval, inInclusiveRange(0, 100));
          expect(e.quip, isNotEmpty);
        }
      }
    }
    final sunny = RoastEngine(fc(code: 0, cloud: 0, gusts: 5), u, Profanity.salty, content);
    expect(sunny.election(0).winner.key, 'sun');
    final rainy = RoastEngine(fc(code: 63, cloud: 100, gusts: 5), u, Profanity.salty, content);
    expect(rainy.election(0).winner.key, 'rain');
  });

  test('political voices are tagged', () {
    expect(content.voice('pundit').political, isTrue);
    expect(content.voice('campaign').political, isTrue);
    expect(content.voice('classic').political, isFalse);
  });
}
