import 'package:flutter/material.dart';

/// Viewport helpers for screens that need to behave differently when the
/// window is short — a phone in landscape is only ~300–400dp tall, so layouts
/// built around a tall portrait column (fixed heights, stacked toolbars,
/// bottom gaps) have to compact, scroll or move to a side rail.
extension ScreenLayout on BuildContext {
  /// True when the window is wider than it is tall.
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// True when the window is too short for a portrait-style stacked layout.
  /// Catches a phone in landscape (and split-screen / desktop windows), but
  /// not a tablet in landscape, which has height to spare.
  bool get isShortScreen => MediaQuery.sizeOf(this).height < 500;
}

/// Caps and centres [child] to [maxWidth] on wide windows.
///
/// A phone in landscape is 700–900dp wide, and a form field or card that
/// stretches the whole width reads badly. Below [maxWidth] this is a no-op, so
/// portrait is untouched. Meant for scrollable form / detail bodies, where the
/// scroll view itself should still span the full width (so the scrollbar and
/// overscroll stay at the screen edge) with this wrapped around its content.
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
