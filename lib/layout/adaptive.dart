import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';

enum WindowClass { compact, medium, expanded, large }

WindowClass windowClassOf(double width) => width < 600
    ? WindowClass.compact
    : width < 840
    ? WindowClass.medium
    : width < 1200
    ? WindowClass.expanded
    : WindowClass.large;

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

      if (b.right > size.width + 1 || b.bottom > size.height + 1) {
        final r = mq.devicePixelRatio;
        b = Rect.fromLTRB(b.left / r, b.top / r, b.right / r, b.bottom / r);
      }
      final halfOpen = f.state == DisplayFeatureState.postureHalfOpened;

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
