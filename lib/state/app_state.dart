import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';
import '../roasts/engine.dart';
import '../services/location.dart';
import '../services/weather_api.dart';
import '../util/units.dart';

enum LoadState { idle, loading, ready, error }

class AppState extends ChangeNotifier {
  AppState(this._prefs, this.content, {bool fetchContent = true})
      : api = WeatherApi(),
        _rand = Random() {
    location = LocationService(api);
    _restore();
    if (fetchContent) _refreshContent();
  }

  final SharedPreferences _prefs;
  final WeatherApi api;
  late final LocationService location;
  final Random _rand;

  /// Roasts, panels and jokes. Starts as the bundled copy, upgraded to the
  /// latest community version from GitHub when available.
  Content content;

  // ---- settings -------------------------------------------------------------
  TempUnit tempUnit = TempUnit.f;
  WindUnit windUnit = WindUnit.mph;
  bool h24 = false;
  Profanity profanity = Profanity.salty;
  String voiceId = 'classic';
  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;
  bool communityUpdates = true;

  // Politics. Master switch plus individual features.
  bool politics = true;
  bool panel = true;
  bool election = true;

  bool get showPanel => politics && panel;
  bool get showElection => politics && election;

  Units get units => Units(tempUnit, windUnit);

  List<VoicePack> get voices =>
      content.voices.where((v) => politics || !v.political).toList();

  VoicePack get voice {
    final v = content.voice(voiceId);
    return (!politics && v.political) ? content.classic : v;
  }

  // ---- places ---------------------------------------------------------------
  List<Place> saved = [];

  /// null = follow the device location.
  Place? selected;
  bool get followingDevice => selected == null;

  // ---- weather --------------------------------------------------------------
  LoadState state = LoadState.idle;
  Forecast? forecast;
  String? error;
  int roastSeed = 0;

  RoastEngine? get engine => forecast == null
      ? null
      : RoastEngine(forecast!, units, profanity, content);

  bool isSaved(Place p) => saved.any((s) => s.id == p.id);

  void _restore() {
    final p = _prefs;
    tempUnit = TempUnit.values[p.getInt('tempUnit') ?? _defaultTemp().index];
    windUnit = WindUnit.values[p.getInt('windUnit') ?? _defaultWind().index];
    h24 = p.getBool('h24') ?? _default24h();
    profanity = Profanity.values[p.getInt('profanity') ?? Profanity.salty.index];
    voiceId = p.getString('voiceId') ?? 'classic';
    politics = p.getBool('politics') ?? true;
    panel = p.getBool('panel') ?? true;
    election = p.getBool('election') ?? true;
    themeMode = ThemeMode.values[p.getInt('themeMode') ?? 0];
    onboarded = p.getBool('onboarded') ?? false;
    communityUpdates = p.getBool('communityUpdates') ?? true;
    saved = (p.getStringList('saved') ?? [])
        .map((s) => Place.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    final sel = p.getString('selected');
    selected = sel == null
        ? null
        : Place.fromJson(jsonDecode(sel) as Map<String, dynamic>);

    final cached = p.getString('cache');
    if (cached != null) {
      try {
        forecast =
            RawForecast.fromJson(jsonDecode(cached) as Map<String, dynamic>)
                .parse();
        state = LoadState.ready;
      } catch (_) {/* stale cache shape; ignore */}
    }
    roastSeed = _rand.nextInt(1000);
  }

  // Fahrenheit only where people actually use it.
  static String get _country =>
      WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'US';
  static TempUnit _defaultTemp() =>
      const {'US', 'LR', 'BS', 'BZ', 'KY', 'PW', 'FM', 'MH'}.contains(_country)
          ? TempUnit.f
          : TempUnit.c;
  static WindUnit _defaultWind() =>
      const {'US', 'GB', 'LR'}.contains(_country) ? WindUnit.mph : WindUnit.kmh;
  static bool _default24h() =>
      !const {'US', 'CA', 'AU', 'PH', 'IN', 'EG', 'SA', 'PK'}.contains(_country);

  void _save() {
    final p = _prefs;
    p.setInt('tempUnit', tempUnit.index);
    p.setInt('windUnit', windUnit.index);
    p.setBool('h24', h24);
    p.setInt('profanity', profanity.index);
    p.setString('voiceId', voiceId);
    p.setBool('politics', politics);
    p.setBool('panel', panel);
    p.setBool('election', election);
    p.setInt('themeMode', themeMode.index);
    p.setBool('onboarded', onboarded);
    p.setBool('communityUpdates', communityUpdates);
    p.setStringList('saved', saved.map((s) => jsonEncode(s.toJson())).toList());
    if (selected == null) {
      p.remove('selected');
    } else {
      p.setString('selected', jsonEncode(selected!.toJson()));
    }
  }

  void update(void Function(AppState s) fn) {
    fn(this);
    _save();
    notifyListeners();
  }

  void reroll() {
    roastSeed++;
    notifyListeners();
  }

  // ---- community content ----------------------------------------------------

  Future<void> _refreshContent() async {
    if (!communityUpdates) return;
    // Use the cached community copy immediately if we have one.
    final cachedRaw = _prefs.getString('contentFiles');
    if (cachedRaw != null) {
      final files = (jsonDecode(cachedRaw) as Map).cast<String, String>();
      final c = await ContentRepo.fromCache(files);
      if (c != null && communityUpdates) {
        content = c;
        notifyListeners();
      }
    }
    final last = _prefs.getInt('contentFetched') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    if (cachedRaw != null && age < const Duration(hours: 6).inMilliseconds) {
      return;
    }
    final client = http.Client();
    try {
      final r = await ContentRepo.fetchRemote(client);
      if (r == null || !communityUpdates) return;
      _prefs.setString('contentFiles', jsonEncode(r.$1));
      _prefs.setInt('contentFetched', DateTime.now().millisecondsSinceEpoch);
      content = r.$2;
      notifyListeners();
    } finally {
      client.close();
    }
  }

  Future<void> setCommunityUpdates(bool on) async {
    communityUpdates = on;
    _save();
    if (on) {
      _prefs.remove('contentFetched');
      await _refreshContent();
    } else {
      content = await ContentRepo.bundled();
      notifyListeners();
    }
  }

  // ---- weather ----------------------------------------------------------------

  Future<void> refresh({bool silent = false}) async {
    if (state == LoadState.loading) return;
    final had = forecast != null;
    state = LoadState.loading;
    error = null;
    if (!silent || !had) notifyListeners();
    try {
      final place = selected ?? await location.locate();
      final raw = await api.fetchRaw(place);
      forecast = raw.parse();
      _prefs.setString('cache', jsonEncode(raw.toJson()));
      roastSeed = _rand.nextInt(1000);
      state = LoadState.ready;
    } catch (e) {
      error = e is WeatherException
          ? e.message
          : "Couldn't reach the weather servers. Check your internet, champ.";
      state = had ? LoadState.ready : LoadState.error;
    }
    notifyListeners();
  }

  Future<void> select(Place? place) async {
    selected = place;
    _save();
    await refresh();
  }

  void toggleSaved(Place p) {
    if (isSaved(p)) {
      saved.removeWhere((s) => s.id == p.id);
    } else {
      saved.add(p);
    }
    _save();
    notifyListeners();
  }

  void removeSaved(Place p) {
    saved.removeWhere((s) => s.id == p.id);
    _save();
    notifyListeners();
  }
}
