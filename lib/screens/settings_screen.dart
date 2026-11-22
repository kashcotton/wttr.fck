import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../roasts/engine.dart';
import '../services/widget_sync.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/units.dart';
import '../widgets/cards.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          child: Semantics(
            header: true,
            child: Text(text, style: t.titleSmall?.copyWith(color: cs.primary)),
          ),
        );

    Widget group(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(children: children),
          ),
        );

    Widget segmented<T>({
      required String label,
      required T value,
      required List<(T, String)> options,
      required void Function(T) onChanged,
      String? help,
    }) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodyLarge),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<T>(
                  showSelectedIcon: false,
                  segments: [
                    for (final o in options)
                      ButtonSegment(value: o.$1, label: Text(o.$2)),
                  ],
                  selected: {value},
                  onSelectionChanged: (v) => onChanged(v.first),
                ),
              ),
              if (help != null) ...[
                const SizedBox(height: 8),
                Text(help,
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        );

    const divider = Divider(height: 1, indent: 16, endIndent: 16);
    final content = s.content;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 32),
            children: [
              header('Attitude'),
              group([
                segmented<Profanity>(
                  label: 'Language',
                  value: s.profanity,
                  options: [for (final p in Profanity.values) (p, p.label)],
                  onChanged: (v) => s.update((s) => s.profanity = v),
                  help: s.profanity.blurb,
                ),
              ]),
              header('Voice'),
              group([
                RadioGroup<String>(
                  groupValue: s.voice.id,
                  onChanged: (v) {
                    if (v != null) s.update((s) => s.voiceId = v);
                  },
                  child: Column(
                    children: [
                      for (final v in s.voices)
                        RadioListTile<String>(
                          value: v.id,
                          title: Text(v.name),
                          subtitle: Text(v.description),
                          secondary: v.political
                              ? Tooltip(
                                  message: 'Political voice',
                                  child: Icon(Icons.how_to_vote_outlined,
                                      color: cs.onSurfaceVariant),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ]),
              header('Politics'),
              group([
                SwitchListTile(
                  secondary: const Icon(Icons.campaign_outlined),
                  title: const Text('Political humor'),
                  subtitle: const Text(
                      'Satire that roasts every side equally and never names real people. '
                      'Turn it off and the app never mentions politics.'),
                  value: s.politics,
                  onChanged: (v) => s.update((s) => s.politics = v),
                ),
                divider,
                SwitchListTile(
                  secondary: const Icon(Icons.podcasts_rounded),
                  title: const Text('The Pundit Panel'),
                  subtitle: const Text(
                      'Two made-up pundits argue about the weather. The weather wins.'),
                  value: s.panel,
                  onChanged: s.politics
                      ? (v) => s.update((s) => s.panel = v)
                      : null,
                ),
                divider,
                SwitchListTile(
                  secondary: const Icon(Icons.how_to_vote_outlined),
                  title: const Text('Election Night'),
                  subtitle: const Text(
                      'Sun, Rain, Clouds, Wind and Snow run for office. '
                      'Vote shares come from the real forecast.'),
                  value: s.election,
                  onChanged: s.politics
                      ? (v) => s.update((s) => s.election = v)
                      : null,
                ),
              ]),
              header('Units'),
              group([
                segmented<TempUnit>(
                  label: 'Temperature',
                  value: s.tempUnit,
                  options: const [(TempUnit.c, '°C'), (TempUnit.f, '°F')],
                  onChanged: (v) => s.update((s) => s.tempUnit = v),
                ),
                divider,
                segmented<WindUnit>(
                  label: 'Wind speed',
                  value: s.windUnit,
                  options: const [
                    (WindUnit.kmh, 'km/h'),
                    (WindUnit.mph, 'mph'),
                    (WindUnit.ms, 'm/s'),
                  ],
                  onChanged: (v) => s.update((s) => s.windUnit = v),
                ),
                divider,
                SwitchListTile(
                  title: const Text('24-hour clock'),
                  value: s.h24,
                  onChanged: (v) => s.update((s) => s.h24 = v),
                ),
              ]),
              header('Appearance'),
              group([
                segmented<ThemeMode>(
                  label: 'Theme',
                  value: s.themeMode,
                  options: const [
                    (ThemeMode.system, 'System'),
                    (ThemeMode.light, 'Light'),
                    (ThemeMode.dark, 'Dark'),
                  ],
                  onChanged: (v) => s.update((s) => s.themeMode = v),
                ),
                divider,
                _ColorPicker(state: s),
              ]),
              if (WidgetSync.supported) ...[
                header('Home screen'),
                group([
                  ListTile(
                    leading: const Icon(Icons.widgets_outlined),
                    title: const Text('Add the widget'),
                    subtitle: const Text(
                        'Temperature and a fresh roast on your home screen. '
                        'Updates itself every 30 minutes. Tap the arrow for a new insult.'),
                    trailing: const Icon(Icons.add_rounded),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (await WidgetSync.canPin()) {
                        await WidgetSync.pin();
                      } else {
                        messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Long-press your home screen, tap Widgets, and find wttr.fck.'),
                        ));
                      }
                    },
                  ),
                ]),
              ],
              header('Community'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CommunityCard(content: content),
              ),
              group([
                SwitchListTile(
                  secondary: const Icon(Icons.sync_rounded),
                  title: const Text('Get new roasts automatically'),
                  subtitle: Text(
                    'Downloads the latest community roasts from GitHub. '
                    '${content.lineCount} lines'
                    '${content.fromNetwork ? ', up to date' : ', built-in copy'}.',
                  ),
                  value: s.communityUpdates,
                  onChanged: (v) => s.setCommunityUpdates(v),
                ),
              ]),
              header('About'),
              group([
                const ListTile(
                  leading: Icon(Icons.favorite_outline_rounded),
                  title: Text('Free. Actually free.'),
                  subtitle: Text(
                      'No ads, no account, no tracking, no subscription. Your location only goes to the weather service to get your forecast.'),
                ),
                divider,
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Weather data'),
                  subtitle: const Text(
                      'Open-Meteo.com, licensed CC BY 4.0. Place names: Open-Meteo Geocoding & BigDataCloud. Approximate location: GeoJS.'),
                  onTap: () => openUrl('https://open-meteo.com'),
                ),
                divider,
                const ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Weather warnings'),
                  subtitle: Text(
                      'Official warnings from the US National Weather Service, Environment Canada, '
                      'Deutscher Wetterdienst (via Bright Sky) and MeteoAlarm for the rest of Europe. '
                      'MeteoAlarm works in the Android, Windows and Linux apps, not the website. '
                      'Everywhere else, wttr.fck flags dangerous weather from the forecast itself.'),
                ),
                divider,
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Source code'),
                  subtitle: const Text('github.com/${ContentRepo.repo}'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openUrl(repoUrl),
                ),
                divider,
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('wttr.fck 1.1.0'),
                  subtitle: const Text('Open-source licenses'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'wttr.fck',
                    applicationVersion: '1.1.0',
                    applicationLegalese:
                        'Weather data by Open-Meteo.com (CC BY 4.0). '
                        'Google Sans Flex font, SIL Open Font License 1.1.',
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = state;
    final wallpaper = s.system != null;

    Widget option({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Color? color,
      IconData? icon,
    }) =>
        Tooltip(
          message: label,
          child: Semantics(
            label: label,
            selected: selected,
            button: true,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                padding: EdgeInsets.all(selected ? 4 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color ?? cs.surfaceContainerHighest,
                  ),
                  child: icon == null
                      ? (selected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null)
                      : Icon(icon, size: 20, color: color == null ? cs.onSurfaceVariant : Colors.white),
                ),
              ),
            ),
          ),
        );

    final help = switch (s.colorSource) {
      ColorSource.wallpaper when wallpaper => 'Matches your phone\'s wallpaper colors.',
      ColorSource.custom => 'Your pick. It stays put whatever the sky does.',
      _ => 'Colors follow the sky: sunny is warm, rain is blue, storms get moody.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Color', style: t.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (wallpaper)
                option(
                  label: 'Match wallpaper',
                  selected: s.colorSource == ColorSource.wallpaper,
                  color: s.system!.seed,
                  icon: Icons.wallpaper_rounded,
                  onTap: () => s.update((s) => s.colorSource = ColorSource.wallpaper),
                ),
              option(
                label: 'Follow the weather',
                selected: s.colorSource == ColorSource.weather ||
                    (s.colorSource == ColorSource.wallpaper && !wallpaper),
                icon: Icons.wb_cloudy_rounded,
                onTap: () => s.update((s) => s.colorSource = ColorSource.weather),
              ),
              for (final (name, color) in colorSwatches)
                option(
                  label: name,
                  color: color,
                  selected: s.colorSource == ColorSource.custom &&
                      s.customColor == color.toARGB32(),
                  onTap: () => s.update((s) {
                    s.colorSource = ColorSource.custom;
                    s.customColor = color.toARGB32();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(help, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
