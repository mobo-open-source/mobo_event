import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The app's two buttons: one filled, one outlined (CLAUDE.md §5).
///
/// Both share their shape, height and label weight, so a Cancel/Save pair sits
/// level and matches edge for edge. Sizing comes from a fixed height rather
/// than from padding, which keeps a one-word button and a five-word button
/// the same height.
enum MoboButtonVariant {
  /// The action being invited. One per screen or dialog.
  filled,

  /// Everything else — Cancel, Clear, Back.
  outlined,
}

class MoboButton extends StatelessWidget {
  const MoboButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MoboButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  /// Shorthand for the primary action.
  const MoboButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = MoboButtonVariant.filled;

  /// Shorthand for the secondary action.
  const MoboButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = MoboButtonVariant.outlined;

  static const double _height = 48;

  final String label;

  /// Null disables the button. A disabled button stays in place rather than
  /// disappearing, so nothing else on the screen moves.
  final VoidCallback? onPressed;

  final MoboButtonVariant variant;
  final IconData? icon;

  /// Swaps the label for a spinner and blocks the tap, so a slow save cannot
  /// be submitted twice.
  final bool isLoading;

  /// False sizes the button to its label instead of the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == MoboButtonVariant.filled
                  ? AppTheme.white
                  : accent,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );

    final button = variant == MoboButtonVariant.filled
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppTheme.white,
              disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
              disabledForegroundColor: AppTheme.disabledButtonText,
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: const Size(0, _height),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              disabledForegroundColor: accent.withValues(alpha: 0.4),
              backgroundColor: Colors.transparent,
              minimumSize: const Size(0, _height),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(
                color: enabled ? accent : accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: child,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A Cancel/Confirm pair, level and equal width — the §5 two-button footer.
///
/// The outlined one leads because the filled one is the action being invited,
/// and the inviting action belongs under the thumb on the right.
class MoboButtonRow extends StatelessWidget {
  const MoboButtonRow({
    super.key,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.isLoading = false,
    this.gap = 12,
  });

  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool isLoading;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MoboButton.outlined(
            label: secondaryLabel,
            onPressed: onSecondary,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: MoboButton.filled(
            label: primaryLabel,
            onPressed: onPrimary,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}
