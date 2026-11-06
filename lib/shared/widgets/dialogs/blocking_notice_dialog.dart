import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import 'pinned_footer_layout.dart';

/// The shared shell behind the login flow's blocking notices — "Module
/// Missing" and "Access Denied" — so every flow that can hit them (sign-in,
/// two-factor, add account, switch account, app start) shows the same dialog.
///
/// [onClose] runs after the dialog has been popped. Callers reached mid-flow
/// (adding a second account) use it to step back to where that flow started,
/// instead of leaving the user on a form they can never submit.
Future<void> showBlockingNoticeDialog(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'OK',
  VoidCallback? onClose,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? AppTheme.darkSurface : AppTheme.white;
  final textPrimary = isDark ? AppTheme.white : AppTheme.textPrimary;
  final textSecondary = isDark ? Colors.white70 : AppTheme.textSecondary;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return PopScope(
        // A blocking notice is dismissed only through its own button, so
        // [onClose] always runs and the caller's navigation always happens.
        canPop: false,
        // A Dialog around the same parts an AlertDialog stacks — title, message,
        // button, with its default text styles and paddings — rather than an
        // AlertDialog, whose title and button can't give way: the keyboard is
        // often still up from the form behind this notice (a phone in landscape
        // is left ~100–200dp), and they would overflow. Here the title and
        // button stay pinned and the message between them scrolls.
        child: Dialog(
          backgroundColor: surface,
          surfaceTintColor: surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          // The default 24dp top and bottom margins are a tenth of a phone in
          // landscape.
          insetPadding: dialogContext.isShortScreen
              ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
              : null,
          child: PinnedFooterLayout(
            // Title (48) + button (68) + a little message.
            scrollAllBelow: 125,
            header: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: DefaultTextStyle(
                style: theme.textTheme.headlineSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlertCircle,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onClose?.call();
                  },
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
