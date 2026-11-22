import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';
import '../roasts/engine.dart';
import '../services/location.dart';
import '../services/system_colors.dart';
import '../services/warnings.dart';
import '../services/weather_api.dart';
import '../services/widget_sync.dart';
import '../theme.dart';
import '../util/units.dart';

enum LoadState { idle, loading, ready, error }

enum ColorSource { wallpaper, weather, custom }

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

  Content content;

  TempUnit tempUnit = TempUnit.f;
  WindUnit windUnit = WindUnit.mph;
  bool h24 = false;
  Profanity profanity = Profanity.salty;
  String voiceId = 'classic';
  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;
  bool communityUpdates = true;

  ColorSource colorSource =
      SystemPalette.platformSupported ? ColorSource.wallpaper : ColorSource.weather;
  int customColor = colorSwatches.first.$2.toARGB32();
  SystemPalette? system;

  final warnings = WarningsService();
  List<WeatherAlert> alerts = const [];
  bool alertsCovered = false;
  String? _alertsFor;
  int panelSeed = 0;

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

  List<Place> saved = [];

  Place? selected;
  bool get followingDevice => selected == null;

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
    final cs = p.getInt('colorSource');
    if (cs != null && cs < ColorSource.values.length) {
      colorSource = ColorSource.values[cs];
    }
    customColor = p.getInt('customColor') ?? customColor;
    panelSeed = p.getInt('panelSeed') ?? _rand.nextInt(10000);
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
      } catch (_) {}
    }
    roastSeed = _rand.nextInt(1000);
  }

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
    p.setInt('colorSource', colorSource.index);
    p.setInt('customColor', customColor);
    p.setInt('panelSeed', panelSeed);
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
    _syncWidget();
  }

  void reroll() {
    roastSeed++;
    notifyListeners();
    _syncWidget();
  }

  void rerollPanel() {
    panelSeed++;
    _prefs.setInt('panelSeed', panelSeed);
    notifyListeners();
  }

  SystemPalette? get activeSystem =>
      colorSource == ColorSource.wallpaper ? system : null;

  Color get seed => switch (colorSource) {
        ColorSource.custom => Color(customColor),
        _ => seedFor(forecast),
      };

  Future<void> loadSystemColors() async {
    final p = await SystemPalette.load();
    if (p != system) {
      system = p;
      notifyListeners();
    }
  }

  Future<void> _loadAlerts(Place place) async {
    alertsCovered = WarningsService.covered(place);
    final found = await warnings.official(place);
    if (forecast?.place.id != place.id) return;
    alerts = found;
    _alertsFor = place.id;
    notifyListeners();
  }

  List<WeatherAlert> get shownAlerts {
    if (alerts.isNotEmpty || forecast == null) return alerts;
    return headsUps(forecast!, units);
  }

  void _syncWidget() => WidgetSync.push(this);

  Future<void> _refreshContent() async {
    if (!communityUpdates) return;

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
      _syncWidget();
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
      panelSeed++;
      _prefs.setInt('panelSeed', panelSeed);
      state = LoadState.ready;
      _syncWidget();
      if (_alertsFor != forecast!.place.id) alerts = const [];
      _loadAlerts(forecast!.place);
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
