library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

enum Mood {
  storm,
  snow,
  rain,
  drizzle,
  fog,
  windy,
  scorching,
  hot,
  freezing,
  cold,
  nice,
  meh,
  clearNight,
}

const placeholders = {
  'temp', 'feels', 'high', 'low', 'wind', 'gusts', 'pop', 'city', 'uv', 'vis',
};

const candidates = ['sun', 'rain', 'clouds', 'wind', 'snow'];

class RoastLine {
  final String head;
  final String sub;
  final String? by;
  const RoastLine(this.head, this.sub, [this.by]);
}

class VoicePack {
  final String id;
  final String name;
  final String description;
  final bool political;
  final Map<Mood, List<RoastLine>> lines;
  const VoicePack({
    required this.id,
    required this.name,
    required this.description,
    required this.political,
    required this.lines,
  });
}

class PanelLine {
  final String left, right, weather;
  final String? by;
  const PanelLine(this.left, this.right, this.weather, [this.by]);
}

class Candidate {
  final String name, party;
  const Candidate(this.name, this.party);
}

class Content {
  final List<VoicePack> voices;
  final Map<Mood, List<PanelLine>> panels;
  final Map<String, Candidate> candidates;
  final Map<String, List<String>> winners;
  final List<({int max, String text})> approval;
  final List<String> loading;
  final bool fromNetwork;

  const Content({
    required this.voices,
    required this.panels,
    required this.candidates,
    required this.winners,
    required this.approval,
    required this.loading,
    this.fromNetwork = false,
  });

  VoicePack get classic => voices.firstWhere((v) => v.id == 'classic');

  VoicePack voice(String id) =>
      voices.firstWhere((v) => v.id == id, orElse: () => classic);

  int get lineCount =>
      voices.fold(0, (n, v) => n + v.lines.values.fold(0, (m, l) => m + l.length)) +
      panels.values.fold(0, (n, l) => n + l.length);

  Set<String> get contributors => {
        for (final v in voices)
          for (final ls in v.lines.values)
            for (final l in ls)
              if (l.by != null) l.by!,
        for (final ps in panels.values)
          for (final p in ps)
            if (p.by != null) p.by!,
      };
}

class ContentError implements Exception {
  final List<String> problems;
  ContentError(this.problems);
  @override
  String toString() => 'Content problems:\n- ${problems.join('\n- ')}';
}

final _idRe = RegExp(r'^[a-z0-9][a-z0-9_-]{0,29}$');
final _ghRe = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$');
final _phRe = RegExp(r'\{([^}]*)\}');

final _moods = {for (final m in Mood.values) m.name: m};

void _checkText(String where, Object? v, int max, List<String> errs) {
  if (v is! String || v.trim().isEmpty) {
    errs.add('$where: must be a non-empty string');
    return;
  }
  if (v.length > max) errs.add('$where: too long (${v.length} > $max chars)');
  if (v != v.trim()) errs.add('$where: has leading/trailing spaces');
  for (final m in _phRe.allMatches(v)) {
    if (!placeholders.contains(m[1])) {
      errs.add('$where: unknown placeholder {${m[1]}}. '
          'Allowed: ${placeholders.map((p) => '{$p}').join(' ')}');
    }
  }
}

String? _by(String where, Object? v, List<String> errs) {
  if (v == null) return null;
  if (v is! String || !_ghRe.hasMatch(v)) {
    errs.add('$where.by: must be a GitHub username (no @)');
    return null;
  }
  return v;
}

VoicePack? parseVoice(String file, Object? j, List<String> errs) {
  if (j is! Map<String, dynamic>) {
    errs.add('$file: must be a JSON object');
    return null;
  }
  final start = errs.length;
  final id = j['id'];
  if (id is! String || !_idRe.hasMatch(id)) {
    errs.add('$file: "id" must be lowercase letters, numbers, - or _');
  }
  _checkText('$file name', j['name'], 30, errs);
  _checkText('$file description', j['description'], 90, errs);
  if (j['political'] is! bool) errs.add('$file: "political" must be true or false');
  final rawLines = j['lines'];
  final out = <Mood, List<RoastLine>>{};
  if (rawLines is! Map<String, dynamic> || rawLines.isEmpty) {
    errs.add('$file: "lines" must be an object with at least one mood');
  } else {
    rawLines.forEach((k, v) {
      final mood = _moods[k];
      if (mood == null) {
        errs.add('$file: unknown mood "$k". Use one of: ${_moods.keys.join(', ')}');
        return;
      }
      if (v is! List || v.isEmpty) {
        errs.add('$file $k: must be a non-empty list');
        return;
      }
      final seen = <String>{};
      final list = <RoastLine>[];
      for (var i = 0; i < v.length; i++) {
        final where = '$file $k[$i]';
        final l = v[i];
        if (l is! Map<String, dynamic>) {
          errs.add('$where: must be {"head": ..., "sub": ...}');
          continue;
        }
        _checkText('$where.head', l['head'], 80, errs);
        _checkText('$where.sub', l['sub'], 180, errs);
        final extra = l.keys.toSet().difference({'head', 'sub', 'by'});
        if (extra.isNotEmpty) errs.add('$where: unexpected keys $extra');
        final by = _by(where, l['by'], errs);
        if (l['head'] is String && !seen.add((l['head'] as String).toLowerCase())) {
          errs.add('$where: duplicate headline');
        }
        if (l['head'] is String && l['sub'] is String) {
          list.add(RoastLine(l['head'] as String, l['sub'] as String, by));
        }
      }
      out[mood] = list;
    });
  }
  if (errs.length > start) return null;
  return VoicePack(
    id: id as String,
    name: j['name'] as String,
    description: j['description'] as String,
    political: j['political'] as bool,
    lines: out,
  );
}

Future<Content> parseContent(
  Future<String> Function(String path) read, {
  bool fromNetwork = false,
}) async {
  final errs = <String>[];
  Future<Object?> load(String path) async {
    try {
      return jsonDecode(await read(path));
    } on FormatException catch (e) {
      errs.add('$path: invalid JSON (${e.message})');
      return null;
    }
  }

  final index = await load('index.json');
  if (index is! Map<String, dynamic> || index['schema'] != 1) {
    throw ContentError([...errs, 'index.json: missing or wrong "schema" (expected 1)']);
  }

  final voices = <VoicePack>[];
  final ids = <String>{};
  for (final f in (index['voices'] as List? ?? const []).cast<String>()) {
    final v = parseVoice(f, await load(f), errs);
    if (v == null) continue;
    if (!ids.add(v.id)) errs.add('$f: duplicate voice id "${v.id}"');
    voices.add(v);
  }
  final classic = voices.where((v) => v.id == 'classic').firstOrNull;
  if (classic == null) {
    errs.add('index.json: the "classic" voice is required');
  } else {
    final missing = Mood.values.where((m) => !classic.lines.containsKey(m));
    if (missing.isNotEmpty) {
      errs.add('voices/classic.json: must cover every mood (it is the fallback). '
          'Missing: ${missing.map((m) => m.name).join(', ')}');
    }
  }

  final panelsJ = await load(index['panels'] as String? ?? 'panels.json');
  final panels = <Mood, List<PanelLine>>{};
  if (panelsJ is Map<String, dynamic>) {
    for (final m in Mood.values) {
      final list = panelsJ[m.name];
      if (list is! List || list.isEmpty) {
        errs.add('panels.json: needs at least one panel for "${m.name}"');
        continue;
      }
      panels[m] = [];
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        final where = 'panels.json ${m.name}[$i]';
        if (p is! Map<String, dynamic>) {
          errs.add('$where: must be an object');
          continue;
        }
        for (final k in ['left', 'right', 'weather']) {
          _checkText('$where.$k', p[k], 160, errs);
        }
        final by = _by(where, p['by'], errs);
        if (p['left'] is String && p['right'] is String && p['weather'] is String) {
          panels[m]!.add(PanelLine(
              p['left'] as String, p['right'] as String, p['weather'] as String, by));
        }
      }
    }
    for (final k in panelsJ.keys) {
      if (!_moods.containsKey(k)) errs.add('panels.json: unknown mood "$k"');
    }
  } else if (panelsJ != null) {
    errs.add('panels.json: must be an object keyed by mood');
  }

  final elJ = await load(index['election'] as String? ?? 'election.json');
  final cands = <String, Candidate>{};
  final winners = <String, List<String>>{};
  final approval = <({int max, String text})>[];
  if (elJ is Map<String, dynamic>) {
    final c = elJ['candidates'];
    final w = elJ['winner'];
    for (final k in candidates) {
      final cj = c is Map ? c[k] : null;
      if (cj is! Map || cj['name'] is! String || cj['party'] is! String) {
        errs.add('election.json: candidates.$k needs "name" and "party"');
      } else {
        cands[k] = Candidate(cj['name'] as String, cj['party'] as String);
      }
      final wl = w is Map ? w[k] : null;
      if (wl is! List || wl.isEmpty) {
        errs.add('election.json: winner.$k needs at least one line');
      } else {
        for (var i = 0; i < wl.length; i++) {
          _checkText('election.json winner.$k[$i]', wl[i], 140, errs);
        }
        winners[k] = wl.whereType<String>().toList();
      }
    }
    final a = elJ['approval'];
    if (a is! List || a.isEmpty) {
      errs.add('election.json: "approval" must be a non-empty list');
    } else {
      var last = -1;
      for (var i = 0; i < a.length; i++) {
        final e = a[i];
        if (e is! Map || e['max'] is! int || e['text'] is! String) {
          errs.add('election.json approval[$i]: needs "max" (int) and "text"');
          continue;
        }
        final max = e['max'] as int;
        if (max <= last) errs.add('election.json approval[$i]: "max" must increase');
        last = max;
        _checkText('election.json approval[$i].text', e['text'], 120, errs);
        approval.add((max: max, text: e['text'] as String));
      }
      if (last != 100) errs.add('election.json: last approval "max" must be 100');
    }
  } else if (elJ != null) {
    errs.add('election.json: must be an object');
  }

  final loadJ = await load(index['loading'] as String? ?? 'loading.json');
  final loading = <String>[];
  if (loadJ is List && loadJ.isNotEmpty) {
    for (var i = 0; i < loadJ.length; i++) {
      _checkText('loading.json[$i]', loadJ[i], 80, errs);
    }
    loading.addAll(loadJ.whereType<String>());
  } else if (loadJ != null) {
    errs.add('loading.json: must be a non-empty list of strings');
  }

  if (errs.isNotEmpty) throw ContentError(errs);
  return Content(
    voices: voices,
    panels: panels,
    candidates: cands,
    winners: winners,
    approval: approval,
    loading: loading,
    fromNetwork: fromNetwork,
  );
}

class ContentRepo {
  static const repo = 'kashcotton/wttr.fck';
  static const remoteBase =
      'https://raw.githubusercontent.com/$repo/main/content/';

  static Future<Content> bundled() =>
      parseContent((p) => rootBundle.loadString('content/$p'));

  static Future<(Map<String, String>, Content)?> fetchRemote(
      http.Client client) async {
    try {
      final files = <String, String>{};
      Future<String> read(String path) async {
        final res = await client
            .get(Uri.parse('$remoteBase$path'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
        final body = utf8.decode(res.bodyBytes);
        files[path] = body;
        return body;
      }

      final c = await parseContent(read, fromNetwork: true);
      return (files, c);
    } catch (_) {
      return null;
    }
  }

  static Future<Content?> fromCache(Map<String, String> files) async {
    try {
      return await parseContent((p) async {
        final f = files[p];
        if (f == null) throw StateError('missing $p');
        return f;
      }, fromNetwork: true);
    } catch (_) {
      return null;
    }
  }
}
