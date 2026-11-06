import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_layout.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? lottieAsset;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.lottieAsset,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // On a short window (a phone in landscape) the illustration shrinks so the
    // title, subtitle and action still fit without scrolling.
    final short = context.isShortScreen;

    Widget illustration;
    if (lottieAsset != null && lottieAsset!.isNotEmpty) {
      illustration = Lottie.asset(
        lottieAsset!,
        width: short ? 120 : 220,
        height: short ? 120 : 220,
        repeat: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          return Icon(
            icon ?? Icons.inbox_outlined,
            size: short ? 56 : 96,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          );
        },
      );
    } else {
      illustration = Icon(
        icon ?? Icons.inbox_outlined,
        size: short ? 56 : 96,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration,
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );

    // Centred in the space it is given, and scrolls — rather than overflowing —
    // when that space is shorter than the content (a phone in landscape, a
    // large text size). With room to spare it looks exactly as before.
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// The action of a list's "No results found" state: clears the filters, the
/// search and the group-by together. Outlined in the brand colour (border and
/// text), 48px tall, radius 12.
class ClearAllFiltersButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ClearAllFiltersButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: const Text(
          'Clear All Filters',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
