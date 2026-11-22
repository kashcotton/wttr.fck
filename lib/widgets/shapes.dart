import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

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
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _MorphPainter(shapes: _shapes, progress: _c, color: color),
          ),
        ),
      ),
    );
  }
}

class SkyBadge extends StatefulWidget {
  const SkyBadge({
    super.key,
    required this.shape,
    required this.icon,
    required this.iconColor,
    required this.fill,
    this.size = 148,
    this.twist = false,
  });
  final RoundedPolygon shape;
  final IconData icon;
  final Color iconColor;
  final Color fill;
  final double size;

  final bool twist;

  @override
  State<SkyBadge> createState() => _SkyBadgeState();
}

class _SkyBadgeState extends State<SkyBadge> with TickerProviderStateMixin {
  late final AnimationController _twist = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );
  late final Animation<double> _turns = Tween<double>(begin: -0.25, end: 0)
      .animate(CurvedAnimation(parent: _twist, curve: springSpatial));
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
      _playTwist();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playTwist();
    });
  }

  void _playTwist() {
    if (!widget.twist || MediaQuery.of(context).disableAnimations) return;
    _twist.forward(from: 0);
  }

  @override
  void dispose() {
    _twist.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PaintRotation(
                turns: _turns,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _morph,
                    builder: (context, _) {
                      final a = MaterialShapeBorder(shape: _from);
                      final b = MaterialShapeBorder(shape: widget.shape);
                      final t = springSpatial.transform(_morph.value);
                      return TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: widget.fill),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, color, _) => DecoratedBox(
                          decoration: ShapeDecoration(
                            color: color,
                            shape: t >= 1 ? b : (a.lerpTo(b, t) ?? b),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
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
          ),
        ),
      ),
    );
  }
}

class PaintRotation extends SingleChildRenderObjectWidget {
  const PaintRotation({super.key, required this.turns, super.child});
  final Animation<double> turns;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPaintRotation(turns);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaintRotation renderObject,
  ) => renderObject.turns = turns;
}

class RenderPaintRotation extends RenderProxyBox {
  RenderPaintRotation(this._turns);
  Animation<double> _turns;

  set turns(Animation<double> v) {
    if (v == _turns) return;
    if (attached) _turns.removeListener(markNeedsPaint);
    _turns = v;
    if (attached) _turns.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _turns.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _turns.removeListener(markNeedsPaint);
    super.detach();
  }

  final _layer = LayerHandle<TransformLayer>();

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final center = size.center(Offset.zero);
    final m = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(_turns.value * math.pi * 2)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      m,
      (ctx, o) => ctx.paintChild(c, o),
      oldLayer: _layer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final center = size.center(Offset.zero);
    transform
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(_turns.value * math.pi * 2)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.shapes,
    required this.progress,
    required this.color,
  }) : super(repaint: progress);
  final List<RoundedPolygon> shapes;
  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value * shapes.length;
    final i = t.floor() % shapes.length;
    final local = springFast.transform((t - t.floor()).clamp(0.0, 1.0));
    final a = MaterialShapeBorder(shape: shapes[i]);
    final b = MaterialShapeBorder(shape: shapes[(i + 1) % shapes.length]);
    final border = a.lerpTo(b, local) ?? b;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(progress.value * math.pi * 3);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPath(
      border.getOuterPath(Offset.zero & size),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.color != color || old.progress != progress;
}
