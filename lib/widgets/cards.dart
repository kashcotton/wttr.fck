import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/weather.dart';
import '../roasts/engine.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/units.dart';
import 'shapes.dart';

const repoUrl = 'https://github.com/${ContentRepo.repo}';
const contributeUrl = '$repoUrl/blob/main/CONTRIBUTING.md';

Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

// ---------------------------------------------------------------------------
// Shared bits

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.padding = const EdgeInsets.all(20),
    this.trailing,
    this.color,
  });
  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsets padding;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: color,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: padding.left == 0 ? 20 : 0,
                  right: padding.right == 0 ? 12 : 0,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title!,
                            style: t.labelLarge
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class CreditChip extends StatelessWidget {
  const CreditChip({super.key, required this.by, this.color});
  final String by;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      link: true,
      label: 'Written by $by on GitHub',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openUrl('https://github.com/$by'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text('by @$by',
              style: t.labelMedium?.copyWith(
                  color: c, decoration: TextDecoration.underline, decorationColor: c)),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$message Showing the last forecast we had.',
                    style: TextStyle(color: cs.onErrorContainer)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero

class HeroBlock extends StatelessWidget {
  const HeroBlock({super.key, required this.forecast, required this.state});
  final Forecast forecast;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final c = forecast.current;
    final u = state.units;
    final place = forecast.place;
    final saved = state.isSaved(place);
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.followingDevice
                    ? Icons.near_me_rounded
                    : Icons.location_on_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(place.name,
                    style: t.titleMedium, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: saved ? 'Remove from saved places' : 'Save this place',
                icon: Icon(saved ? Icons.star_rounded : Icons.star_outline_rounded),
                color: saved ? cs.primary : cs.onSurfaceVariant,
                onPressed: () => state.toggleSaved(place),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '${u.degU(c.temp)}, ${describeCode(c.code)}. Feels like ${u.degU(c.feelsLike)}.',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: u.t(c.temp)),
                        duration: const Duration(milliseconds: 900),
                        curve: springSpatial,
                        builder: (context, v, _) => Text('${v.round()}°',
                            style: narrow
                                ? t.displayLarge?.copyWith(fontSize: 84)
                                : t.displayLarge),
                      ),
                      const SizedBox(height: 10),
                      Text(describeCode(c.code), style: t.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        'Feels like ${u.deg(c.feelsLike)}  ·  '
                        'H ${u.deg(forecast.today.max)}  L ${u.deg(forecast.today.min)}',
                        style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              SkyBadge(
                size: narrow ? 120 : 148,
                shape: shapeFor(c.sky, c.isDay),
                icon: iconFor(c.code, c.isDay),
                iconColor: iconTint(c.code, c.isDay, cs),
                fill: cs.surfaceContainerHigh,
                twist: c.sky == Sky.clear && c.isDay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The roast

class RoastCard extends StatelessWidget {
  const RoastCard({super.key, required this.engine, required this.state});
  final RoastEngine engine;
  final AppState state;

  String _shareText(Roast r) {
    final c = engine.f.current;
    return '${r.head} ${r.sub}\n'
        '${engine.f.place.name}: ${state.units.degU(c.temp)}, '
        '${describeCode(c.code).toLowerCase()}.\n— wttr.fck';
  }

  bool get _canShare =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = engine.roast(state.voice, state.roastSeed);
    final on = cs.onPrimaryContainer;

    return Card(
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 450),
              curve: springSpatial,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.none,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: springFast,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...prev, ?cur],
                ),
                child: Padding(
                  key: ValueKey('${r.head}${state.voice.id}'),
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(r.head,
                          style: t.headlineMedium?.copyWith(color: on)),
                      const SizedBox(height: 10),
                      SelectableText(r.sub,
                          style: t.bodyLarge
                              ?.copyWith(color: on.withValues(alpha: 0.82))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(state.voice.name,
                          style: t.labelMedium
                              ?.copyWith(color: on.withValues(alpha: 0.72))),
                      if (r.by != null)
                        CreditChip(by: r.by!, color: on.withValues(alpha: 0.72)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Copy',
                  color: on,
                  icon: const Icon(Icons.content_copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _shareText(r)));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(censor(
                            "Copied. Go ruin someone's damn day.",
                            state.profanity)),
                      ));
                  },
                ),
                if (_canShare)
                  IconButton(
                    tooltip: 'Share',
                    color: on,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    onPressed: () => SharePlus.instance
                        .share(ShareParams(text: _shareText(r))),
                  ),
                IconButton.filled(
                  tooltip: 'Roast me again',
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: state.reroll,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Misery + verdict

class VerdictRow extends StatelessWidget {
  const VerdictRow({super.key, required this.engine});
  final RoastEngine engine;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final m = engine.misery;

    final misery = SectionCard(
      title: 'Misery index',
      icon: Icons.sentiment_very_dissatisfied_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$m', style: t.displaySmall),
              Text(' / 10',
                  style: t.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(engine.miseryLabel, style: t.bodyMedium),
          const SizedBox(height: 12),
          Semantics(
            label: 'Misery $m out of 10',
            child: SizedBox(
              height: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < 10; i++) ...[
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: i < m ? 1 : 0),
                        duration: Duration(milliseconds: 300 + i * 50),
                        curve: springFast,
                        builder: (context, v, _) => Container(
                          height: 6 + 6 * v.clamp(0, 1),
                          decoration: BoxDecoration(
                            color: Color.lerp(cs.surfaceContainerHighest,
                                m >= 7 ? cs.error : cs.primary, v.clamp(0, 1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    if (i < 9) const SizedBox(width: 3),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final (fill, on, shape, icon) = m <= 4
        ? (cs.primaryContainer, cs.onPrimaryContainer, MaterialShapes.cookie9Sided, Icons.check_rounded)
        : m <= 6
            ? (cs.tertiaryContainer, cs.onTertiaryContainer, MaterialShapes.pentagon, Icons.question_mark_rounded)
            : (cs.errorContainer, cs.onErrorContainer, MaterialShapes.softBurst, Icons.close_rounded);

    final verdict = SectionCard(
      title: 'Should I go outside?',
      icon: Icons.directions_walk_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 48,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: MaterialShapeBorder(shape: shape),
              ),
              child: Icon(icon, color: on),
            ),
          ),
          const SizedBox(height: 10),
          Text(engine.verdict, style: t.titleMedium),
        ],
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: misery),
          const SizedBox(width: 12),
          Expanded(child: verdict),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hourly, with a temperature curve

class HourlyCard extends StatelessWidget {
  const HourlyCard({
    super.key,
    required this.forecast,
    required this.units,
    required this.h24,
    required this.level,
  });
  final Forecast forecast;
  final Units units;
  final bool h24;
  final Profanity level;

  static const itemW = 64.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hours = forecast.hours;
    final wetSoon = hours.take(12).where((h) => h.precipChance >= 50).toList();
    final sky = forecast.current.sky;
    final wetNow = sky == Sky.rain || sky == Sky.drizzle || sky == Sky.storm;
    final dryAt = hours.take(12).where((h) {
      final s = skyFromCode(h.code);
      return s != Sky.rain && s != Sky.drizzle && s != Sky.storm;
    }).firstOrNull;
    final summary = sky == Sky.snow
        ? 'Snowing now. Stay put if you can.'
        : wetNow
            ? (dryAt == null
                ? 'Wet for the next 12 hours at least. Settle in.'
                : 'Should ease up around ${hourLabel(dryAt.time, h24: h24)}. Maybe.')
            : wetSoon.isEmpty
                ? 'No rain in the next 12 hours. Leave the umbrella.'
                : 'Rain likely around ${hourLabel(wetSoon.first.time, h24: h24)}. Plan your shit.';

    return SectionCard(
      title: 'Hourly forecast',
      icon: Icons.schedule_rounded,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(censor(summary, level),
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: hours.length * itemW,
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: CustomPaint(
                      size: Size(hours.length * itemW, 76),
                      painter: _TempCurve(
                        temps: [for (final h in hours) units.t(h.temp)],
                        itemW: itemW,
                        line: cs.primary,
                        dot: cs.onPrimary,
                        label: t.titleSmall!.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < hours.length; i++)
                        _HourCell(
                          hour: hours[i],
                          now: i == 0,
                          units: units,
                          h24: h24,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.hour,
    required this.now,
    required this.units,
    required this.h24,
  });
  final Hour hour;
  final bool now;
  final Units units;
  final bool h24;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = hour;
    final label = now ? 'Now' : hourLabel(h.time, h24: h24);
    return Semantics(
      label:
          '$label: ${units.degU(h.temp)}, ${describeCode(h.code)}, ${h.precipChance}% chance of rain',
      excludeSemantics: true,
      child: SizedBox(
        width: HourlyCard.itemW,
        child: Column(
          children: [
            Icon(iconFor(h.code, h.isDay),
                color: iconTint(h.code, h.isDay, cs), size: 26),
            const SizedBox(height: 4),
            Text(
              h.precipChance >= 10 ? '${h.precipChance}%' : ' ',
              style: t.labelSmall?.copyWith(color: cs.primary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: now
                  ? ShapeDecoration(color: cs.primary, shape: const StadiumBorder())
                  : null,
              child: Text(
                label,
                maxLines: 1,
                style: t.labelMedium?.copyWith(
                  color: now ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempCurve extends CustomPainter {
  _TempCurve({
    required this.temps,
    required this.itemW,
    required this.line,
    required this.dot,
    required this.label,
  });
  final List<double> temps;
  final double itemW;
  final Color line;
  final Color dot;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.isEmpty) return;
    final lo = temps.reduce(math.min);
    final hi = temps.reduce(math.max);
    final span = math.max(1.0, hi - lo);
    const top = 32.0, bottom = 64.0;
    final pts = [
      for (var i = 0; i < temps.length; i++)
        Offset(i * itemW + itemW / 2,
            bottom - (temps[i] - lo) / span * (bottom - top)),
    ];

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.16), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < pts.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: '${temps[i].round()}°', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pts[i] - Offset(tp.width / 2, tp.height + 8));
    }
    canvas.drawCircle(pts.first, 6, Paint()..color = line);
    canvas.drawCircle(pts.first, 2.5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_TempCurve old) =>
      !listEquals(old.temps, temps) || old.line != line || old.label != label;
}

// ---------------------------------------------------------------------------
// 10-day

class DailyCard extends StatelessWidget {
  const DailyCard({super.key, required this.forecast, required this.units});
  final Forecast forecast;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final days = forecast.days;
    final lo = days.map((d) => d.min).reduce(math.min);
    final hi = days.map((d) => d.max).reduce(math.max);
    final span = math.max(1.0, hi - lo);

    return SectionCard(
      title: '10-day forecast',
      icon: Icons.calendar_month_outlined,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            _DayRow(
              day: days[i],
              label: i == 0 ? 'Today' : weekday(days[i].date),
              units: units,
              lo: lo,
              span: span,
              currentTemp: i == 0 ? forecast.current.temp : null,
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.label,
    required this.units,
    required this.lo,
    required this.span,
    required this.currentTemp,
  });
  final Day day;
  final String label;
  final Units units;
  final double lo;
  final double span;
  final double? currentTemp;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '$label: ${describeCode(day.code)}, high ${units.degU(day.max)}, low ${units.degU(day.min)}, ${day.precipChance}% chance of rain',
      excludeSemantics: true,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label, style: t.titleSmall)),
            SizedBox(
              width: 40,
              child: Text(
                day.precipChance >= 10 ? '${day.precipChance}%' : '',
                style: t.labelMedium?.copyWith(color: cs.primary),
              ),
            ),
            Icon(iconFor(day.code, true),
                size: 24, color: iconTint(day.code, true, cs)),
            const SizedBox(width: 12),
            SizedBox(
              width: 36,
              child: Text(units.deg(day.min),
                  textAlign: TextAlign.right,
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth;
                final start = (day.min - lo) / span * w;
                final end = (day.max - lo) / span * w;
                return SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned(
                        left: start,
                        width: math.max(8, end - start),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      if (currentTemp != null && w > 8)
                        Positioned(
                          left: ((currentTemp! - lo) / span * w - 4)
                              .clamp(0, w - 8),
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.onPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.primary, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(units.deg(day.max), style: t.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pundit Panel

class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.engine, required this.seed});
  final RoastEngine engine;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final p = engine.panel(seed);
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'The Pundit Panel',
      icon: Icons.podcasts_rounded,
      trailing: Tooltip(
        message: 'Fictional pundits. Both sides get roasted equally.',
        child: Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Speaker(
            avatar: const Text('L'),
            shape: MaterialShapes.circle,
            name: 'Lefty Lou',
            role: 'Left of center',
            quote: p.left,
            color: const Color(0xFF2F6DB5),
          ),
          const SizedBox(height: 12),
          _Speaker(
            avatar: const Text('R'),
            shape: MaterialShapes.circle,
            name: 'Righty Rhonda',
            role: 'Right of center',
            quote: p.right,
            color: const Color(0xFFC0392B),
          ),
          const SizedBox(height: 12),
          _Speaker(
            avatar: const Icon(Icons.cloud_rounded, size: 20),
            shape: MaterialShapes.puffy,
            name: 'The Actual Weather',
            role: 'Independent. Tired.',
            quote: p.weather,
            color: cs.outline,
            emphasize: true,
          ),
          if (p.by != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: CreditChip(by: p.by!)),
          ],
        ],
      ),
    );
  }
}

class _Speaker extends StatelessWidget {
  const _Speaker({
    required this.avatar,
    required this.shape,
    required this.name,
    required this.role,
    required this.quote,
    required this.color,
    this.emphasize = false,
  });
  final Widget avatar;
  final RoundedPolygon shape;
  final String name, role, quote;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 38,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color,
              shape: MaterialShapeBorder(shape: shape),
            ),
            child: Center(
              child: DefaultTextStyle(
                style: t.titleSmall!.copyWith(color: Colors.white),
                child: IconTheme(
                    data: const IconThemeData(color: Colors.white), child: avatar),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: emphasize ? cs.secondaryContainer : cs.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: name, style: t.labelLarge),
                  TextSpan(
                    text: '  $role',
                    style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ])),
                const SizedBox(height: 4),
                Text(quote, style: t.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Election Night

class ElectionCard extends StatelessWidget {
  const ElectionCard({super.key, required this.engine, required this.seed});
  final RoastEngine engine;
  final int seed;

  static const _icons = {
    'sun': Icons.wb_sunny_rounded,
    'rain': Icons.water_drop_rounded,
    'clouds': Icons.cloud_rounded,
    'wind': Icons.air_rounded,
    'snow': Icons.ac_unit_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final e = engine.election(seed);
    final w = e.winner;
    final good = e.approval >= 50;

    return SectionCard(
      title: 'Election Night',
      icon: Icons.how_to_vote_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: ShapeDecoration(color: cs.error, shape: const StadiumBorder()),
        child: Text('LIVE',
            style: t.labelSmall?.copyWith(color: cs.onError, letterSpacing: 1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROJECTED WINNER',
              style: t.labelSmall?.copyWith(color: cs.primary, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(_icons[w.key], color: cs.primary, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text('${w.who.name} · ${w.pct}%', style: t.headlineSmall),
              ),
            ],
          ),
          Text(w.who.party,
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          for (final r in e.results) ...[
            Semantics(
              label: '${r.who.name}, ${r.who.party}: ${r.pct} percent',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(r.who.name, style: t.labelLarge)),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: r.pct / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: springSpatial,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v.clamp(0, 1),
                          minHeight: 12,
                          color: r.key == w.key ? cs.primary : cs.secondary,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${r.pct}%',
                        textAlign: TextAlign.right, style: t.labelLarge),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(e.quip, style: t.bodyLarge),
          const Divider(height: 28),
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: good ? cs.primaryContainer : cs.errorContainer,
                    shape: MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
                  ),
                  child: Center(
                    child: Text('${e.approval}%',
                        style: t.titleMedium?.copyWith(
                          color: good ? cs.onPrimaryContainer : cs.onErrorContainer,
                        )),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's weather approval rating", style: t.labelLarge),
                    const SizedBox(height: 2),
                    Text(e.approvalText,
                        style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outfit

class OutfitCard extends StatelessWidget {
  const OutfitCard({super.key, required this.engine});
  final RoastEngine engine;

  @override
  Widget build(BuildContext context) {
    final o = engine.outfit();
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: 'What to wear',
      icon: Icons.checkroom_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.quip, style: t.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in o.items) Chip(label: Text(item))],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Details grid

class DetailsGrid extends StatelessWidget {
  const DetailsGrid({
    super.key,
    required this.engine,
    required this.units,
    required this.h24,
  });
  final RoastEngine engine;
  final Units units;
  final bool h24;

  @override
  Widget build(BuildContext context) {
    final f = engine.f;
    final c = f.current;
    final d = f.today;
    final tiles = <Widget>[
      _Tile(
        icon: Icons.air_rounded,
        label: 'Wind',
        value: units.speed(c.wind),
        detail: '${compass(c.windDir)} · gusts ${units.speed(c.gusts)}',
        quip: engine.windQuip(c.gusts),
        trailing: Transform.rotate(
          // Arrow points where the wind is going.
          angle: (c.windDir + 180) * math.pi / 180,
          child: const Icon(Icons.navigation_rounded, size: 20),
        ),
      ),
      _Tile(
        icon: Icons.water_drop_outlined,
        label: 'Humidity',
        value: '${c.humidity}%',
        quip: engine.humidityQuip(c.humidity),
      ),
      _Tile(
        icon: Icons.wb_sunny_outlined,
        label: 'UV index',
        value: c.uv.toStringAsFixed(0),
        detail: 'Max today ${d.uvMax.toStringAsFixed(0)}',
        quip: engine.uvQuip(math.max(c.uv, d.uvMax)),
      ),
      _Tile(
        icon: Icons.umbrella_rounded,
        label: 'Precipitation',
        value: '${d.precipChance}%',
        detail: '${units.precip(d.precipSum)} today',
        quip: engine.precipQuip(d),
      ),
      if (f.air != null)
        _Tile(
          icon: Icons.masks_outlined,
          label: 'Air quality',
          value: '${f.air!.usAqi}',
          detail: RoastEngine.aqiLabel(f.air!.usAqi),
          quip: engine.aqiQuip(f.air!.usAqi),
        ),
      _Tile(
        icon: Icons.compress_rounded,
        label: 'Pressure',
        value: units.pressure(c.pressure),
        quip: engine.pressureQuip(c.pressure),
      ),
      _Tile(
        icon: Icons.visibility_outlined,
        label: 'Visibility',
        value: units.distance(c.visibility),
        quip: engine.visibilityQuip(c.visibility),
      ),
      if (d.sunrise != null && d.sunset != null)
        _Tile(
          icon: Icons.wb_twilight_rounded,
          label: 'Sunrise & sunset',
          value: clock(d.sunrise!, h24: h24),
          detail: 'Sunset ${clock(d.sunset!, h24: h24)}',
          quip: _daylight(d.sunrise!, d.sunset!),
        ),
    ];

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 520 ? 3 : 2;
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }

  String _daylight(DateTime rise, DateTime set) {
    final dur = set.difference(rise);
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    final base = '${h}h ${m}m of daylight.';
    if (h < 9) return censor('$base Depressing as hell.', engine.level);
    if (h >= 15) return '$base Go use it.';
    return base;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.quip,
    this.detail,
    this.trailing,
  });
  final IconData icon;
  final String label, value, quip;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (trailing != null)
                    IconTheme(
                        data: IconThemeData(color: cs.primary), child: trailing!),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.headlineSmall),
              ),
              if (detail != null)
                Text(detail!,
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              const Spacer(),
              Text(quip,
                  style: t.labelMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Community + footer

class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.content});
  final Content content;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final people = content.contributors.length;
    return SectionCard(
      color: cs.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: cs.secondary,
                    shape: MaterialShapeBorder(shape: MaterialShapes.clover4Leaf),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: cs.onSecondary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Think you're funnier?",
                        style: t.titleMedium
                            ?.copyWith(color: cs.onSecondaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      '${content.lineCount} roasts'
                      '${people > 0 ? ' from $people contributors' : ''}. '
                      'Write your own and it ships to everyone.',
                      style: t.bodyMedium
                          ?.copyWith(color: cs.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => openUrl(contributeUrl),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a roast on GitHub'),
            ),
          ),
        ],
      ),
    );
  }
}

class AttributionFooter extends StatelessWidget {
  const AttributionFooter({super.key, required this.fetchedAt, required this.h24});
  final DateTime fetchedAt;
  final bool h24;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = t.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final link = style?.copyWith(decoration: TextDecoration.underline);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Updated ${clock(fetchedAt, h24: h24)} · ', style: style),
          InkWell(
            onTap: () => openUrl('https://open-meteo.com'),
            child: Text('Weather data by Open-Meteo.com', style: link),
          ),
          Text(' (CC BY 4.0) · ', style: style),
          InkWell(
            onTap: () => openUrl(repoUrl),
            child: Text('Open source on GitHub', style: link),
          ),
        ],
      ),
    );
  }
}
