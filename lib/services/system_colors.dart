import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class SystemPalette {
  final Color seed;
  final Map<String, Color> light;
  final Map<String, Color> dark;
  const SystemPalette(this.seed, this.light, this.dark);

  @override
  bool operator ==(Object other) =>
      other is SystemPalette &&
      other.seed == seed &&
      mapEquals(other.light, light) &&
      mapEquals(other.dark, dark);

  @override
  int get hashCode => Object.hash(seed, light.length, dark.length);

  static const _channel = MethodChannel('wttr.fck/system_colors');

  static bool get platformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<SystemPalette?> load() async {
    if (!platformSupported) return null;
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('get');
      if (r == null || r['seed'] is! int) return null;
      Map<String, Color> roles(Object? m) => {
            if (m is Map)
              for (final e in m.entries)
                if (e.value is int) '${e.key}': Color(e.value as int),
          };
      return SystemPalette(
          Color(r['seed'] as int), roles(r['light']), roles(r['dark']));
    } catch (_) {
      return null;
    }
  }

  ColorScheme apply(ColorScheme base) {
    final m = base.brightness == Brightness.dark ? dark : light;
    if (m.isEmpty) return base;
    Color c(String k, Color fallback) => m[k] ?? fallback;
    return base.copyWith(
      primary: c('primary', base.primary),
      onPrimary: c('onPrimary', base.onPrimary),
      primaryContainer: c('primaryContainer', base.primaryContainer),
      onPrimaryContainer: c('onPrimaryContainer', base.onPrimaryContainer),
      secondary: c('secondary', base.secondary),
      onSecondary: c('onSecondary', base.onSecondary),
      secondaryContainer: c('secondaryContainer', base.secondaryContainer),
      onSecondaryContainer: c('onSecondaryContainer', base.onSecondaryContainer),
      tertiary: c('tertiary', base.tertiary),
      onTertiary: c('onTertiary', base.onTertiary),
      tertiaryContainer: c('tertiaryContainer', base.tertiaryContainer),
      onTertiaryContainer: c('onTertiaryContainer', base.onTertiaryContainer),
      error: c('error', base.error),
      onError: c('onError', base.onError),
      errorContainer: c('errorContainer', base.errorContainer),
      onErrorContainer: c('onErrorContainer', base.onErrorContainer),
      surface: c('surface', base.surface),
      onSurface: c('onSurface', base.onSurface),
      onSurfaceVariant: c('onSurfaceVariant', base.onSurfaceVariant),
      surfaceDim: c('surfaceDim', base.surfaceDim),
      surfaceBright: c('surfaceBright', base.surfaceBright),
      surfaceContainerLowest:
          c('surfaceContainerLowest', base.surfaceContainerLowest),
      surfaceContainerLow: c('surfaceContainerLow', base.surfaceContainerLow),
      surfaceContainer: c('surfaceContainer', base.surfaceContainer),
      surfaceContainerHigh: c('surfaceContainerHigh', base.surfaceContainerHigh),
      surfaceContainerHighest:
          c('surfaceContainerHighest', base.surfaceContainerHighest),
      outline: c('outline', base.outline),
      outlineVariant: c('outlineVariant', base.outlineVariant),
      inverseSurface: c('inverseSurface', base.inverseSurface),
      onInverseSurface: c('onInverseSurface', base.onInverseSurface),
      inversePrimary: c('inversePrimary', base.inversePrimary),
    );
  }
}
