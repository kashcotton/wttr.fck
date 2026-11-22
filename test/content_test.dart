import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wttr_fck/models/weather.dart';
import 'package:wttr_fck/roasts/engine.dart';
import 'package:wttr_fck/services/weather_api.dart';
import 'package:wttr_fck/util/units.dart';

import 'helpers.dart';

final _swears = RegExp(
  r'\b(fuck\w*|\w*fuck\w*|shit\w*|bullshit|ass|asshole\w*|jackass|dumbass|damn|goddamn|hell|bitch\w*|bastard|piss\w*|crap|dick\w*|prick|bollocks|bloody|wtf|cock|twat|wank\w*|cunt\w*|slut\w*|whore\w*)\b',
  caseSensitive: false,
);

final _banned = RegExp(r'\b(cunt\w*|slut\w*|whore\w*|retard\w*|fag\w*|tranny)\b',
    caseSensitive: false);

void main() {
  late Content content;
  setUpAll(() async => content = await diskContent());

  test('content parses and passes validation', () {
    expect(content.voices, isNotEmpty);
    expect(content.voice('classic').id, 'classic');
  });

  test('every line renders cleanly at every profanity level', () {
    const units = Units(TempUnit.f, WindUnit.mph);
    final f = RawForecast(const Place(name: 'Testville', lat: 0, lon: 0),
            sample(), null, DateTime(2026))
        .parse();
    final all = <String>[
      for (final v in content.voices)
        for (final ls in v.lines.values)
          for (final l in ls) ...[l.head, l.sub],
      for (final ps in content.panels.values)
        for (final p in ps) ...[p.left, p.right, p.weather],
      for (final side in [
        content.pundits.left,
        content.pundits.right,
        content.pundits.weather,
      ])
        for (final p in side) ...[p.name, p.role],
      for (final w in content.winners.values) ...w,
      for (final a in content.approval) a.text,
      ...content.loading,
    ];
    for (final raw in all) {
      expect(_banned.hasMatch(raw), isFalse, reason: 'Banned word in: "$raw"');
      for (final level in Profanity.values) {
        final out = RoastEngine(f, units, level, content).fill(raw);
        expect(out.contains('{'), isFalse, reason: 'Leftover placeholder: "$out"');
        if (level == Profanity.clean) {
          expect(_swears.hasMatch(out), isFalse,
              reason: 'Clean mode let a swear through: "$out". '
                  'Add the word to lib/roasts/censor.dart.');
        }
      }
    }
  });

  group('validator catches mistakes', () {
    Future<List<String>> problems(Map<String, Object?> overrides) async {
      final files = <String, String>{
        'index.json': jsonEncode({
          'schema': 1,
          'voices': ['voices/classic.json', 'voices/bad.json'],
          'panels': 'panels.json',
          'election': 'election.json',
          'loading': 'loading.json',
        }),
      };
      Future<String> read(String p) async {
        if (overrides.containsKey(p)) return jsonEncode(overrides[p]);
        return files[p] ?? await diskRead(p);
      }

      try {
        await parseContent(read);
        return [];
      } on ContentError catch (e) {
        return e.problems;
      }
    }

    Map<String, Object?> voice(Map<String, Object?> lines, {String id = 'bad'}) => {
          'id': id,
          'name': 'Bad',
          'description': 'Test voice',
          'political': false,
          'lines': lines,
        };

    test('unknown mood', () async {
      final p = await problems({
        'voices/bad.json': voice({
          'sunny': [
            {'head': 'Hi', 'sub': 'There'}
          ]
        })
      });
      expect(p.join(), contains('unknown mood "sunny"'));
    });

    test('unknown placeholder', () async {
      final p = await problems({
        'voices/bad.json': voice({
          'rain': [
            {'head': 'It is {temperature}', 'sub': 'Ok'}
          ]
        })
      });
      expect(p.join(), contains('unknown placeholder {temperature}'));
    });

    test('bad credit and long line', () async {
      final p = await problems({
        'voices/bad.json': voice({
          'rain': [
            {'head': 'x' * 81, 'sub': 'Ok', 'by': '@someone'}
          ]
        })
      });
      expect(p.join(), allOf(contains('too long'), contains('GitHub username')));
    });

    test('duplicate voice id', () async {
      final p = await problems({
        'voices/bad.json': voice({
          'rain': [
            {'head': 'Hi', 'sub': 'There'}
          ]
        }, id: 'classic')
      });
      expect(p.join(), contains('duplicate voice id'));
    });
  });
}

Future<String> diskRead(String p) => File('content/$p').readAsString();
