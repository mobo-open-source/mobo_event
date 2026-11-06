import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// "Stage"-style pill a list or board shows in its toolbar while a Group By is
/// applied.
///
/// It is the "N Active" filter badge's twin — the same black pill (white in
/// dark mode), so the two read as one family — with a layers icon in front to
/// say it is a grouping rather than a count. Callers size it to match the
/// badge on their own screen ([height], [padding], [radius], [fontSize]).
class GroupByPill extends StatelessWidget {
  final String label;

  /// Fixed height, for a toolbar whose controls are all the same; null sizes
  /// the pill to its text and [padding].
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double fontSize;

  const GroupByPill({
    super.key,
    required this.label,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.radius = AppRadius.pill,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.black : Colors.white;

    return Container(
      height: height,
      padding: padding,
      // No `alignment:` — a Container given one grows to fill every pixel of
      // width it is offered, which is the whole toolbar slot. A fixed height
      // already gives the Row a tight height to centre itself in.
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: fontSize + 3, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
