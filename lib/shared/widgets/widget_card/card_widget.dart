import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class CardWidget extends StatelessWidget {
  final Widget child;

  /// Space between the card's edge and [child]: 20 at the sides, 10 above and
  /// below, unless a caller needs its child to reach the edge.
  final EdgeInsetsGeometry padding;

  /// [Clip.antiAlias] cuts [child] to the card's rounded corners (the card's
  /// own shadow is not clipped). It lets content that moves sideways — the tab
  /// pages as they swipe — run to the card's edge rather than stop at its
  /// padding.
  final Clip clipBehavior;

  const CardWidget({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 18,vertical: 14),
      padding: padding,
      clipBehavior: clipBehavior,
      width: double.infinity,
      decoration: BoxDecoration(
        // Dark: the #1E1E1E dialog surface, so tab content such as the Notes
        // form sits flush and its grey[850] fields stay visible; the hairline
        // keeps the card distinct from the grey[900] page behind it.
        color: AppTheme.surface(isDark),
        border: isDark ? Border.all(color: Colors.grey[800]!) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          AppShadows.cardShadow,
          
        ],
      ),
      child:child
    );
  }
}
