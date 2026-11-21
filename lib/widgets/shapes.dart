import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Material 3 Expressive loading indicator: a blob that morphs through the
/// expressive shape set while slowly spinning.
class ShapeLoader extends StatefulWidget {
  const ShapeLoader({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  State<ShapeLoader> createState() => _ShapeLoaderState();
}

class _ShapeLoaderState extends State<ShapeLoader>
    with SingleTickerProviderStateMixin {
  static final _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 650 * _shapes.length),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * _shapes.length;
            final i = t.floor() % _shapes.length;
            final local = springFast.transform((t - t.floor()).clamp(0, 1));
            final a = MaterialShapeBorder(shape: _shapes[i]);
            final b = MaterialShapeBorder(shape: _shapes[(i + 1) % _shapes.length]);
            return Transform.rotate(
              angle: _c.value * math.pi * 2 * 1.5,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: a.lerpTo(b, local) ?? b,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The weather icon sitting on a morphing expressive shape. Sunny weather
/// gets a slowly rotating sun shape; everything else gently breathes.
class SkyBadge extends StatefulWidget {
  const SkyBadge({
    super.key,
    required this.shape,
    required this.icon,
    required this.iconColor,
    required this.fill,
    this.size = 148,
    this.spin = false,
  });
  final RoundedPolygon shape;
  final IconData icon;
  final Color iconColor;
  final Color fill;
  final double size;
  final bool spin;

  @override
  State<SkyBadge> createState() => _SkyBadgeState();
}

class _SkyBadgeState extends State<SkyBadge> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late RoundedPolygon _from = widget.shape;

  @override
  void didUpdateWidget(SkyBadge old) {
    super.didUpdateWidget(old);
    if (old.shape != widget.shape) {
      _from = old.shape;
      _morph.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (widget.spin && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _morph]),
          builder: (context, _) {
            final a = MaterialShapeBorder(shape: _from);
            final b = MaterialShapeBorder(shape: widget.shape);
            final t = springSpatial.transform(_morph.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _spin.value * math.pi * 2,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: widget.fill),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, color, _) => DecoratedBox(
                      decoration: ShapeDecoration(
                        color: color,
                        shape: t >= 1 ? b : (a.lerpTo(b, t) ?? b),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: springFast,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.icon),
                    size: widget.size * 0.5,
                    color: widget.iconColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
