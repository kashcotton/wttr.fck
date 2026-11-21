import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';

/// Material 3 window size classes.
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum WindowClass { compact, medium, expanded, large }

WindowClass windowClassOf(double width) => width < 600
    ? WindowClass.compact
    : width < 840
    ? WindowClass.medium
    : width < 1200
    ? WindowClass.expanded
    : WindowClass.large;

/// Foldable awareness. A "book" fold splits the screen left/right; a
/// "tabletop" fold (half-open, horizontal hinge) splits it top/bottom.
class Fold {
  final Rect bounds;
  final bool vertical;
  final bool halfOpen;
  const Fold(this.bounds, this.vertical, this.halfOpen);

  static Fold? of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    for (final f in mq.displayFeatures) {
      if (f.type != DisplayFeatureType.hinge &&
          f.type != DisplayFeatureType.fold) {
        continue;
      }
      var b = f.bounds;
      // Some platforms report folds in physical pixels, others in logical
      // pixels. If it doesn't fit the logical screen, it's physical.
      if (b.right > size.width + 1 || b.bottom > size.height + 1) {
        final r = mq.devicePixelRatio;
        b = Rect.fromLTRB(b.left / r, b.top / r, b.right / r, b.bottom / r);
      }
      final halfOpen = f.state == DisplayFeatureState.postureHalfOpened;
      // Folds only matter when they actually separate content: hinges always
      // do, flat folds only if the posture is half-open.
      final separating = f.type == DisplayFeatureType.hinge || halfOpen;
      if (b.height >= size.height - 1 && b.top <= 1) {
        return Fold(b, true, halfOpen && separating);
      }
      if (b.width >= size.width - 1 && b.left <= 1) {
        return Fold(b, false, halfOpen && separating);
      }
    }
    return null;
  }
}

/// Two panes that respect a vertical hinge: each pane sits entirely on one
/// side of the fold so nothing gets cut in half by the crease.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.start,
    required this.end,
    required this.width,
    required this.left,
    this.fold,
    this.gap = 16,
  });
  final Widget start;
  final Widget end;

  /// The width the panes get, and where they start on screen. Passed in
  /// rather than measured with a LayoutBuilder: a LayoutBuilder here would
  /// re-lay-out the whole page whenever any card animates.
  final double width;
  final double left;
  final Fold? fold;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final f = fold;
    if (f != null && f.vertical) {
      final l = (f.bounds.left - left).clamp(0.0, width);
      final r = (f.bounds.right - left).clamp(0.0, width);
      final startW = l - gap / 2;
      final endW = width - r - gap / 2;
      // Only follow the hinge if both sides are usable.
      if (startW >= 280 && endW >= 280) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: startW, child: start),
            SizedBox(width: (r - l) + gap),
            Expanded(child: end),
          ],
        );
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: start),
        SizedBox(width: gap),
        Expanded(child: end),
      ],
    );
  }
}
