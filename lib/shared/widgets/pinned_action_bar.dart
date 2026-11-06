import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The fixed footer under a full-screen form that holds its Save / Create
/// button: the card surface with a soft shadow along its top edge, so the
/// fields read as scrolling underneath it. Kept clear of the home indicator.
class PinnedActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PinnedActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
