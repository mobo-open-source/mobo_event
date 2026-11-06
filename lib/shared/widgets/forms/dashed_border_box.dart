import 'package:flutter/material.dart';

/// Traces [child]'s rounded-rectangle edge with a dashed/dotted line — the
/// conventional "drop a file here" upload box look, which this app's own
/// upload boxes were missing (a plain filled rectangle, no border at all).
///
/// [child] supplies its own fill and [borderRadius] (the two have to agree,
/// or the dashes won't sit flush with the box's corners); this only adds the
/// line on top of it.
class DashedBorderBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  const DashedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 5,
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.gapWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Foreground, not background: painted over the child, so the dashes
      // read as a border rather than vanishing under its fill colour.
      foregroundPainter: _DashedRRectPainter(
        color: color,
        radius: borderRadius,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke, so the line sits inside the box rather than
    // being clipped by whatever rounds the child's own corners the same way.
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(
      _dashPath(Path()..addRRect(rrect)),
      paint,
    );
  }

  /// Walks the path's length in `dashWidth`-on, `gapWidth`-off steps, the
  /// standard `PathMetrics`-based way to dash an arbitrary (here, rounded)
  /// path — Flutter has no built-in dashed `BorderSide`.
  Path _dashPath(Path source) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final step = drawing ? dashWidth : gapWidth;
        final next = (distance + step).clamp(0.0, metric.length);
        if (drawing) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        drawing = !drawing;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      gapWidth != oldDelegate.gapWidth;
}
