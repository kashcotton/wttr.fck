import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../layout/adaptive.dart';
import '../main.dart';
import '../models/weather.dart';
import '../roasts/censor.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';
import '../widgets/first_run.dart';
import '../widgets/shapes.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep it fresh while the app is open.
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) AppScope.of(context).refresh(silent: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.of(context);
      if (!s.onboarded) showFirstRun(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final s = AppScope.of(context);
      final age = s.forecast == null
          ? const Duration(days: 1)
          : DateTime.now().difference(s.forecast!.fetchedAt);
      if (age > const Duration(minutes: 10)) s.refresh(silent: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.forecast;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: f == null
            ? _EmptyState(state: s)
            : _AdaptiveHome(state: s, forecast: f),
      ),
    );
  }
}

void openSearch(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const SearchScreen()));

void openSettings(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, this.showSettings = true});
  final AppState state;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Search for a place',
              excludeSemantics: true,
              child: Material(
                color: cs.surfaceContainerHigh,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openSearch(context),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text('Search for a place',
                              style: t.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: state.state == LoadState.loading
                              ? ShapeLoader(size: 22, color: cs.primary)
                              : Text('wttr.fck',
                                  style:
                                      t.labelLarge?.copyWith(color: cs.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showSettings) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => openSettings(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdaptiveHome extends StatelessWidget {
  const _AdaptiveHome({required this.state, required this.forecast});
  final AppState state;
  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final f = forecast;
    final e = s.engine!;
    const gap = SizedBox(height: 12);

    final hero = <Widget>[
      HeroBlock(forecast: f, state: s),
      gap,
      RoastCard(engine: e, state: s),
    ];
    final primaryRest = <Widget>[
      gap,
      VerdictRow(engine: e),
      gap,
      HourlyCard(forecast: f, units: s.units, h24: s.h24, level: s.profanity),
      gap,
      OutfitCard(engine: e),
    ];
    final secondary = <Widget>[
      DailyCard(forecast: f, units: s.units),
      if (s.showElection) ...[gap, ElectionCard(engine: e, seed: s.roastSeed)],
      if (s.showPanel) ...[gap, PanelCard(engine: e, seed: s.roastSeed)],
      gap,
      DetailsGrid(engine: e, units: s.units, h24: s.h24),
      gap,
      CommunityCard(content: s.content),
    ];
    final footer = <Widget>[
      const SizedBox(height: 16),
      AttributionFooter(fetchedAt: f.fetchedAt, h24: s.h24),
      SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
    ];
    final banner = s.error == null
        ? const SizedBox.shrink()
        : ErrorBanner(message: s.error!, onRetry: () => s.refresh());

    Widget scroll(List<Widget> children, {double maxWidth = 1400}) =>
        RefreshIndicator(
          onRefresh: () => s.refresh(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(children: children),
                ),
              ),
            ],
          ),
        );

    return LayoutBuilder(builder: (context, box) {
      final fold = Fold.of(context);
      final cls = windowClassOf(box.maxWidth);

      // Tabletop: half-folded with a horizontal hinge. Weather on the top
      // half like a little screen, everything else scrolls on the bottom.
      if (fold != null && !fold.vertical && fold.halfOpen) {
        final top = MediaQuery.paddingOf(context).top;
        final topH = (fold.bounds.top - top).clamp(0.0, box.maxHeight);
        return Column(
          children: [
            SizedBox(
              height: topH,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(children: hero),
              ),
            ),
            SizedBox(height: fold.bounds.height),
            Expanded(
              child: scroll([
                _TopBar(state: s),
                banner,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [...primaryRest, gap, ...secondary]),
                ),
                ...footer,
              ]),
            ),
          ],
        );
      }

      final twoPane = cls.index >= WindowClass.expanded.index ||
          (fold != null && fold.vertical && box.maxWidth >= 600);

      if (!twoPane) {
        return scroll([
          _TopBar(state: s),
          banner,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(children: [...hero, ...primaryRest, gap, ...secondary]),
          ),
          ...footer,
        ], maxWidth: cls == WindowClass.medium ? 720 : 640);
      }

      final panes = TwoPane(
        fold: fold,
        gap: 24,
        start: Column(children: [...hero, ...primaryRest]),
        end: Column(children: secondary),
      );

      final main = scroll([
        _TopBar(state: s, showSettings: cls != WindowClass.large),
        banner,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: panes,
        ),
        ...footer,
      ]);

      if (cls == WindowClass.large && fold == null) {
        return Row(
          children: [
            SizedBox(width: 300, child: _PlacesPane(state: s)),
            Expanded(child: main),
          ],
        );
      }
      return main;
    });
  }
}

/// Large screens: a list-detail layout with saved places always visible.
class _PlacesPane extends StatelessWidget {
  const _PlacesPane({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final current = state.forecast?.place;

    Widget item({
      required IconData icon,
      required String title,
      String? subtitle,
      required bool selected,
      required VoidCallback onTap,
      Widget? trailing,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: selected ? cs.secondaryContainer : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(icon,
                  color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant),
              title: Text(title,
                  style: t.labelLarge?.copyWith(
                      color: selected ? cs.onSecondaryContainer : cs.onSurface)),
              subtitle: subtitle == null || subtitle.isEmpty
                  ? null
                  : Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall),
              trailing: trailing,
              onTap: onTap,
            ),
          ),
        );

    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
              child: Row(
                children: [
                  Expanded(child: Text('wttr.fck', style: t.headlineSmall)),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => openSettings(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.tonalIcon(
                onPressed: () => openSearch(context),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a place'),
              ),
            ),
            item(
              icon: Icons.near_me_rounded,
              title: 'Your location',
              subtitle: state.followingDevice ? current?.name : null,
              selected: state.followingDevice,
              onTap: () => state.select(null),
            ),
            if (state.saved.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
                child: Text('Saved places',
                    style: t.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in state.saved)
                    item(
                      icon: Icons.location_on_outlined,
                      title: p.name,
                      subtitle: p.subtitle,
                      selected:
                          !state.followingDevice && state.selected?.id == p.id,
                      onTap: () => state.select(p),
                      trailing: IconButton(
                        tooltip: 'Remove ${p.name}',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => state.removeSaved(p),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final failed = state.state == LoadState.error;
    final lines = state.content.loading;
    final line =
        censor(lines[DateTime.now().second % lines.length], state.profanity);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed) ...[
                const ShapeLoader(size: 64),
                const SizedBox(height: 28),
                Text(line,
                    style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
              ] else ...[
                SizedBox.square(
                  dimension: 96,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: cs.errorContainer,
                      shape: MaterialShapeBorder(shape: MaterialShapes.puffy),
                    ),
                    child: Icon(Icons.cloud_off_rounded,
                        size: 40, color: cs.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 20),
                Text(censor('Well, shit.', state.profanity),
                    style: t.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(state.error ?? 'Something broke.',
                    style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => state.refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openSearch(context),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Pick a city'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
