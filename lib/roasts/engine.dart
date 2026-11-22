import 'dart:math' as math;

import '../content/content.dart';
import '../models/weather.dart';
import '../util/units.dart';
import 'censor.dart';

export '../content/content.dart';
export 'censor.dart';

Mood moodFor(Current c) {
  final sky = c.sky;
  if (sky == Sky.storm) return Mood.storm;
  if (sky == Sky.snow) return Mood.snow;
  if (sky == Sky.rain) return Mood.rain;
  if (sky == Sky.drizzle) return Mood.drizzle;
  if (sky == Sky.fog) return Mood.fog;
  if (c.gusts >= 55 || c.wind >= 40) return Mood.windy;
  final t = c.feelsLike;
  if (t >= 35) return Mood.scorching;
  if (t >= 28) return Mood.hot;
  if (t < 0) return Mood.freezing;
  if (t < 11) return Mood.cold;
  if (!c.isDay && (sky == Sky.clear || sky == Sky.partly)) {
    return Mood.clearNight;
  }

  if (sky == Sky.clear || sky == Sky.partly) return Mood.nice;
  return Mood.meh;
}

typedef Roast = ({String head, String sub, String? by});

class PanelTake {
  final String left, right, weather;
  final String? by;
  final Pundit leftWho, rightWho, weatherWho;
  const PanelTake({
    required this.left,
    required this.right,
    required this.weather,
    required this.by,
    required this.leftWho,
    required this.rightWho,
    required this.weatherWho,
  });
}

class ElectionResult {
  final List<({String key, Candidate who, int pct})> results;
  final String quip;
  final int approval;
  final String approvalText;
  const ElectionResult(this.results, this.quip, this.approval, this.approvalText);
  ({String key, Candidate who, int pct}) get winner => results.first;
}

class RoastEngine {
  final Forecast f;
  final Units u;
  final Profanity level;
  final Content content;
  RoastEngine(this.f, this.u, this.level, this.content);

  late final Mood mood = moodFor(f.current);

  String fill(String s) {
    final c = f.current;
    final out = s
        .replaceAll('{temp}', u.deg(c.temp))
        .replaceAll('{feels}', u.deg(c.feelsLike))
        .replaceAll('{high}', u.deg(f.today.max))
        .replaceAll('{low}', u.deg(f.today.min))
        .replaceAll('{wind}', u.speed(c.wind))
        .replaceAll('{gusts}', u.speed(c.gusts))
        .replaceAll('{pop}', '${f.today.precipChance}')
        .replaceAll('{uv}', c.uv.toStringAsFixed(0))
        .replaceAll('{vis}', u.distance(c.visibility))
        .replaceAll('{city}', f.place.name);
    return censor(out, level);
  }

  Roast roast(VoicePack voice, int seed) {
    final pool = voice.lines[mood] ?? content.classic.lines[mood]!;
    final l = pool[seed.abs() % pool.length];
    return (head: fill(l.head), sub: fill(l.sub), by: l.by);
  }

  static final _perms = <(int, int), List<int>>{};

  static int pick(int seed, int n, int salt) {
    if (n <= 1) return 0;
    final perm = _perms.putIfAbsent(
        (n, salt), () => List.generate(n, (i) => i)..shuffle(math.Random(salt)));
    return perm[seed.abs() % n];
  }

  PanelTake panel(int seed) {
    final pool = content.panels[mood]!;
    final p = pool[pick(seed, pool.length, mood.index + 101)];
    final r = content.pundits;
    return PanelTake(
      left: fill(p.left),
      right: fill(p.right),
      weather: fill(p.weather),
      by: p.by,
      leftWho: r.left[pick(seed, r.left.length, 7)],
      rightWho: r.right[pick(seed, r.right.length, 13)],
      weatherWho: r.weather[pick(seed, r.weather.length, 29)],
    );
  }

  ElectionResult election(int seed) {
    final c = f.current;
    final next = f.hours.take(12);
    final pop = next.isEmpty
        ? f.today.precipChance.toDouble()
        : next.map((h) => h.precipChance).reduce(math.max).toDouble();
    final wetSky = c.sky == Sky.rain || c.sky == Sky.drizzle || c.sky == Sky.storm;
    final snowy = c.sky == Sky.snow || (c.feelsLike < 1 && pop > 20);

    var sun = (100 - c.cloudCover) * (c.isDay ? 1.0 : 0.35);
    if (wetSky || c.sky == Sky.snow) sun *= 0.25;
    var rain = pop * (wetSky ? 1.4 : 0.8);
    var snow = 0.0;
    if (snowy) {
      snow = math.max(pop, 40) * 1.4;
      rain *= 0.2;
    }
    final clouds = c.cloudCover * 0.75;
    final wind = ((c.gusts - 10).clamp(0, 90)) * 1.1;

    final raw = {
      'sun': sun,
      'rain': rain,
      'clouds': clouds,
      'wind': wind,
      'snow': snow,
    }..removeWhere((_, v) => v <= 0.5);
    if (raw.isEmpty) raw['clouds'] = 1;
    final total = raw.values.fold(0.0, (a, b) => a + b);
    final results = [
      for (final e in raw.entries)
        (key: e.key, who: content.candidates[e.key]!, pct: (e.value / total * 100).round()),
    ]..sort((a, b) => b.pct.compareTo(a.pct));

    final drift = 100 - results.fold<int>(0, (s, r) => s + r.pct);
    if (drift != 0) {
      final w = results.first;
      results[0] = (key: w.key, who: w.who, pct: w.pct + drift);
    }
    final shown = results.where((r) => r.pct > 0).toList();

    final wl = content.winners[shown.first.key]!;
    final approval = (100 - misery * 9 - 3).clamp(2, 99);
    final approvalText = content.approval
        .firstWhere((a) => approval <= a.max, orElse: () => content.approval.last)
        .text;
    return ElectionResult(
      shown,
      fill(wl[seed.abs() % wl.length]),
      approval,
      fill(approvalText),
    );
  }

  String loadingLine(int seed) =>
      censor(content.loading[seed.abs() % content.loading.length], level);

  int get misery {
    final c = f.current;
    var m = ((c.feelsLike - 21).abs() / 3.2).clamp(0, 5).toDouble();
    m += switch (c.sky) {
      Sky.storm => 4,
      Sky.snow => 3,
      Sky.rain => c.code >= 65 || c.code == 82 ? 3 : 2,
      Sky.drizzle => 1,
      Sky.fog => 1,
      Sky.cloudy => 0.5,
      _ => 0,
    };
    if (c.gusts >= 50) m += 1.5;
    if (c.uv >= 8 && c.isDay) m += 1;
    if (c.humidity >= 85 && c.temp >= 24) m += 1;
    if ((f.air?.usAqi ?? 0) > 100) m += 1;

    if (c.sky == Sky.storm) m = m < 7 ? 7 : m;
    return m.round().clamp(0, 10);
  }

  String get miseryLabel => censor(
        switch (misery) {
          <= 1 => 'Basically paradise',
          <= 3 => 'Tolerable',
          <= 5 => 'Annoying',
          <= 7 => 'Pretty shitty',
          <= 8 => 'Miserable',
          _ => 'Absolute hellscape',
        },
        level,
      );

  String get verdict => censor(
        switch (misery) {
          <= 2 => 'Go outside. Seriously.',
          <= 4 => "Yeah, go. It's fine.",
          <= 6 => 'If you really have to.',
          <= 8 => 'Hard pass.',
          _ => 'Absolutely fucking not.',
        },
        level,
      );

  ({List<String> items, String quip}) outfit() {
    final c = f.current;
    final t = c.feelsLike;
    final items = <String>[];
    if (t < -10) {
      items.addAll(['Parka', 'Thermal layers', 'Hat', 'Gloves', 'Scarf']);
    } else if (t < 0) {
      items.addAll(['Winter coat', 'Hat', 'Gloves']);
    } else if (t < 8) {
      items.addAll(['Warm jacket', 'Long sleeves']);
    } else if (t < 15) {
      items.addAll(['Light jacket', 'Jeans']);
    } else if (t < 22) {
      items.addAll(['T-shirt', 'Light layer']);
    } else if (t < 28) {
      items.addAll(['T-shirt', 'Shorts']);
    } else {
      items.add('As little as legally allowed');
    }
    final wet = c.sky == Sky.rain ||
        c.sky == Sky.storm ||
        c.sky == Sky.drizzle ||
        f.today.precipChance >= 50;
    if (wet) items.add('Umbrella');
    if (c.sky == Sky.snow) items.add('Real boots');
    if (c.gusts >= 45) items.add("Something that won't blow off");
    if (f.today.uvMax >= 6) items.add('Sunscreen');
    if (f.today.uvMax >= 4 && c.isDay && (c.sky == Sky.clear || c.sky == Sky.partly)) {
      items.add('Sunglasses');
    }

    final quip = switch (mood) {
      Mood.freezing => 'Dress like a burrito. Layers on layers.',
      Mood.cold => "You're going to say you're fine. You won't be. Jacket.",
      Mood.scorching || Mood.hot => 'Breathable stuff only. Leave the damn hoodie at home.',
      Mood.rain || Mood.storm => 'Waterproof everything. Suede shoes are a bad idea today.',
      Mood.drizzle => 'A hood will do. An umbrella is a bit dramatic.',
      Mood.snow => 'Boots with grip. Your ass will thank you.',
      Mood.windy => 'Skip the skirt. Skip the hat. Skip the umbrella.',
      Mood.fog => 'Wear something bright so people can see you.',
      Mood.nice => 'Wear whatever. The weather is doing the heavy lifting today.',
      Mood.meh => 'A light layer. Commit to nothing, like the sky.',
      Mood.clearNight => 'Pajamas. Go to bed.',
    };
    return (items: items, quip: censor(quip, level));
  }

  String feelsQuip(double temp, double feels, int humidity) {
    final d = feels - temp;
    return censor(
        d >= 3
            ? (humidity >= 60 ? 'Humidity is lying to the thermometer.' : 'The sun is cooking you extra.')
            : d <= -3
                ? 'The wind is making it worse. Of course it is.'
                : 'What it says is what you get. Rare honesty.',
        level);
  }

  String cloudQuip(int pct) => censor(
      pct >= 90
          ? 'Lid on. Nobody is getting a tan.'
          : pct >= 60
              ? 'Mostly gray. Moody as hell.'
              : pct >= 25
                  ? 'Some clouds. Decorative.'
                  : 'Wide open sky. Show-off.',
      level);

  String humidityQuip(int h) => censor(
      h >= 85
          ? 'Swampy as hell.'
          : h >= 65
              ? 'Kinda sticky.'
              : h >= 35
                  ? "Fine. Don't worry about it."
                  : 'Dry as shit. Lotion up.',
      level);

  String uvQuip(double uv) => censor(
      uv >= 8
          ? 'Sun will fuck you up.'
          : uv >= 6
              ? 'Sunscreen. Not optional.'
              : uv >= 3
                  ? 'Moderate. Maybe a hat.'
                  : "You're safe, vampire.",
      level);

  String windQuip(double kmh) => censor(
      kmh >= 50
          ? 'Small dogs at risk.'
          : kmh >= 30
              ? 'Umbrellas will suffer.'
              : kmh >= 12
                  ? 'A nice breeze.'
                  : 'Dead still. Eerie.',
      level);

  String aqiQuip(int aqi) => censor(
      aqi > 200
          ? "Don't breathe. Seriously."
          : aqi > 150
              ? 'Air is shit today.'
              : aqi > 100
                  ? 'Sensitive lungs, stay in.'
                  : aqi > 50
                      ? 'Meh. Breathable.'
                      : 'Clean as hell. Breathe deep.',
      level);

  static String aqiLabel(int aqi) => aqi > 300
      ? 'Hazardous'
      : aqi > 200
          ? 'Very unhealthy'
          : aqi > 150
              ? 'Unhealthy'
              : aqi > 100
                  ? 'Unhealthy for some'
                  : aqi > 50
                      ? 'Moderate'
                      : 'Good';

  String pressureQuip(double hpa) => censor(
      hpa < 1000
          ? 'Low. Headache weather.'
          : hpa > 1025
              ? 'High and stable. Boring.'
              : 'Normal. Nothing to see.',
      level);

  String visibilityQuip(double m) => censor(
      m < 1000
          ? "Can't see shit."
          : m < 5000
              ? 'Kinda hazy.'
              : 'Crystal clear.',
      level);

  String precipQuip(Day d) => censor(
      d.precipChance >= 70
          ? "It's gonna rain. Deal with it."
          : d.precipChance >= 40
              ? 'Coin flip. Bring a hood.'
              : d.precipChance >= 15
                  ? 'Probably dry.'
                  : 'Dry as hell.',
      level);
}
