import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../forms/mobo_form_field.dart';
import '../mobo/mobo_button.dart';
import 'pinned_footer_layout.dart';

/// Common, theme-aware popup dialog used across the app
/// Supports: title, description, optional input field, 1-2 action buttons, and optional leading icon.
class CommonDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<List<dynamic>>? icon;
  final bool showInput;
  final String? inputHint;
  final TextEditingController? controller;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// When true, renders the icon at the top center with centered title/message
  /// to match the app's confirmation/discard dialog design.
  final bool topIconCentered;

  /// Optional custom body placed between the header and action buttons
  final Widget? body;

  const CommonDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.showInput = false,
    this.inputHint,
    this.controller,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.topIconCentered = false,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    // A phone in landscape is ~300–400dp tall, less again with the keyboard up
    // for the input variant: the dialog trims its own margins, and the header,
    // message and input scroll while the footer stays put.
    final short = context.isShortScreen;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: short
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
          : null,
      child: Padding(
        padding: EdgeInsets.all(short ? 16 : 20),
        child: PinnedFooterLayout(
          gap: short ? 12 : 20,
          // Footer (48) + gap + a little body: below that, everything scrolls.
          scrollAllBelow: 100,
          // The app's §5 footer: outlined Cancel on the left, filled action
          // on the right, both 48 high and in the brand colour.
          footer: secondaryLabel != null && onSecondary != null
              ? MoboButtonRow(
                  secondaryLabel: secondaryLabel!,
                  onSecondary: onSecondary,
                  primaryLabel: primaryLabel,
                  onPrimary: onPrimary,
                )
              : MoboButton.filled(label: primaryLabel, onPressed: onPrimary),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topIconCentered) ...[
                if (icon != null) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(icon: icon!, size: 26, color: primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: HugeIcon(icon: icon!, size: 20, color: primary),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ],
              if (body != null) ...[const SizedBox(height: 12), body!],
              if (showInput) ...[
                const SizedBox(height: 14),
                // The app's standard field look (see `Field`).
                MoboTextField(
                  controller: controller,
                  autofocus: true,
                  hintText: inputHint ?? 'Placeholder',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    List<List<dynamic>>? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        primaryLabel: confirmText,
        onPrimary: () => Navigator.of(ctx).pop(true),
        secondaryLabel: cancelText,
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  /// A single-button informational dialog — used for messages the user must
  /// acknowledge rather than choose between (e.g. a portal-account refusal).
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = 'OK',
    List<List<dynamic>>? icon,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        primaryLabel: confirmText,
        onPrimary: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String placeholder = 'Enter value',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    List<List<dynamic>>? icon,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        showInput: true,
        controller: controller,
        inputHint: placeholder,
        primaryLabel: confirmText,
        onPrimary: () => Navigator.of(ctx).pop(controller.text.trim()),
        secondaryLabel: cancelText,
        onSecondary: () => Navigator.of(ctx).pop(null),
      ),
    );
  }
}
