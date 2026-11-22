import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../roasts/censor.dart';

Future<void> showFirstRun(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (context) => const _FirstRunSheet(),
  );
}

class _FirstRunSheet extends StatefulWidget {
  const _FirstRunSheet();
  @override
  State<_FirstRunSheet> createState() => _FirstRunSheetState();
}

class _FirstRunSheetState extends State<_FirstRunSheet> {
  Profanity _pick = Profanity.salty;

  static const _sample = "It's fucking cold. Grab a jacket, you stubborn ass.";

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('wttr.fck', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text(
              "Real forecasts, delivered with attitude. Free, no ads, no account. "
              "First things first: how dirty should it talk?",
              style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Profanity>(
                segments: [
                  for (final p in Profanity.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_pick},
                onSelectionChanged: (v) => setState(() => _pick = v.first),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_pick),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(censor(_sample, _pick),
                        style: t.titleMedium
                            ?.copyWith(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 6),
                    Text(_pick.blurb,
                        style: t.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('You can change this any time in Settings.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  AppScope.of(context).update((s) {
                    s.profanity = _pick;
                    s.onboarded = true;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text("Let's go"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
