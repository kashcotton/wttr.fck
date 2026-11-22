import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'models/weather.dart';

const fontFamily = 'GoogleSansFlex';

Color seedFor(Forecast? f) {
  if (f == null) return const Color(0xFF3B6EA8);
  final c = f.current;
  if (c.feelsLike >= 32 && c.isDay) return const Color(0xFFD9622B);
  switch (c.sky) {
    case Sky.clear:
    case Sky.partly:
      return c.isDay ? const Color(0xFFE8A33D) : const Color(0xFF29466E);
    case Sky.cloudy:
      return const Color(0xFF6B7B8C);
    case Sky.fog:
      return const Color(0xFF7D857A);
    case Sky.drizzle:
    case Sky.rain:
      return const Color(0xFF3C6E9A);
    case Sky.snow:
      return const Color(0xFF6FA3C0);
    case Sky.storm:
      return const Color(0xFF3F5560);
  }
}

TextStyle flex(TextStyle? s, {double? weight, double round = 0}) {
  final base = s ?? const TextStyle();
  final w = weight ?? ((base.fontWeight ?? FontWeight.w400).value.toDouble());
  return base.copyWith(
    fontFamily: fontFamily,
    fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
    fontVariations: [
      FontVariation('wght', w),
      FontVariation('ROND', round),
    ],
  );
}

TextTheme _textTheme(TextTheme t) => t.copyWith(
      displayLarge: flex(t.displayLarge, weight: 420, round: 100)
          .copyWith(fontSize: 104, letterSpacing: -3, height: 1),
      displayMedium: flex(t.displayMedium, weight: 450, round: 100),
      displaySmall: flex(t.displaySmall, weight: 500, round: 100),
      headlineLarge: flex(t.headlineLarge, weight: 650, round: 40),
      headlineMedium: flex(t.headlineMedium, weight: 700, round: 30)
          .copyWith(letterSpacing: -0.6, height: 1.12),
      headlineSmall: flex(t.headlineSmall, weight: 500, round: 60),
      titleLarge: flex(t.titleLarge, weight: 500),
      titleMedium: flex(t.titleMedium, weight: 560),
      titleSmall: flex(t.titleSmall, weight: 560),
      bodyLarge: flex(t.bodyLarge, weight: 400),
      bodyMedium: flex(t.bodyMedium, weight: 400),
      bodySmall: flex(t.bodySmall, weight: 400),
      labelLarge: flex(t.labelLarge, weight: 560),
      labelMedium: flex(t.labelMedium, weight: 560),
      labelSmall: flex(t.labelSmall, weight: 560),
    );

final _themeCache = <(Color, Brightness), ThemeData>{};

ThemeData buildTheme(Color seed, Brightness b) =>
    _themeCache.putIfAbsent((seed, b), () => _buildTheme(seed, b));

ThemeData _buildTheme(Color seed, Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: b,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );

  final accent = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE09A2C),
    brightness: b,
  );
  final cs = scheme.copyWith(
    tertiary: accent.primary,
    onTertiary: accent.onPrimary,
    tertiaryContainer: accent.primaryContainer,
    onTertiaryContainer: accent.onPrimaryContainer,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    brightness: b,
    fontFamily: fontFamily,
  );
  final text = _textTheme(base.textTheme);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: cs.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
    ),
    iconButtonTheme: const IconButtonThemeData(
      variant: StyleVariant.material3Expressive,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: cs.outlineVariant),
      labelStyle: text.labelLarge,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelLarge)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {this.seconds = 0.6})
      : _sim = SpringSimulation(spring, 0, 1, 0);
  final SpringSimulation _sim;
  final double seconds;

  @override
  double transformInternal(double t) => t >= 1 ? 1 : _sim.x(t * seconds);
}

final springSpatial = SpringCurve(Springs.expressiveDefaultSpatial, seconds: 0.7);
final springFast = SpringCurve(Springs.expressiveFastSpatial, seconds: 0.45);

RoundedPolygon shapeFor(Sky sky, bool isDay) => switch (sky) {
      Sky.clear => isDay ? MaterialShapes.sunny : MaterialShapes.cookie12Sided,
      Sky.partly => MaterialShapes.cookie9Sided,
      Sky.cloudy => MaterialShapes.puffy,
      Sky.fog => MaterialShapes.pill,
      Sky.drizzle => MaterialShapes.cookie6Sided,
      Sky.rain => MaterialShapes.cookie4Sided,
      Sky.snow => MaterialShapes.flower,
      Sky.storm => MaterialShapes.softBoom,
    };

IconData iconFor(int code, bool isDay) {
  switch (skyFromCode(code)) {
    case Sky.clear:
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    case Sky.partly:
      return isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
    case Sky.cloudy:
      return Icons.cloud_rounded;
    case Sky.fog:
      return Icons.foggy;
    case Sky.drizzle:
      return Icons.grain_rounded;
    case Sky.rain:
      return Icons.water_drop_rounded;
    case Sky.snow:
      return Icons.ac_unit_rounded;
    case Sky.storm:
      return Icons.thunderstorm_rounded;
  }
}

Color iconTint(int code, bool isDay, ColorScheme s) {
  final sky = skyFromCode(code);
  final dark = s.brightness == Brightness.dark;
  Color base;
  switch (sky) {
    case Sky.clear:
    case Sky.partly:
      base = isDay ? const Color(0xFFF2A516) : const Color(0xFFB9C4D6);
    case Sky.rain:
    case Sky.drizzle:
      base = const Color(0xFF4A8FD9);
    case Sky.snow:
      base = const Color(0xFF8FC6E8);
    case Sky.storm:
      base = const Color(0xFFE0B13A);
    case Sky.cloudy:
    case Sky.fog:
      return s.onSurfaceVariant;
  }
  return Color.alphaBlend(
      (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.05 : 0.08),
      base);
}
