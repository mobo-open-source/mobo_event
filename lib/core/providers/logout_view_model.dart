import 'package:flutter/material.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:mobo_event/shared/widgets/dialogs/common_dialog.dart';
import 'package:provider/provider.dart';
import '../../../main.dart';
import '../services/session_service.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../shared/widgets/loaders/loading_widget.dart';
import '../../app/app_entry.dart';
import '../routing/page_transition.dart';
import '../utils/screen_layout.dart';

class LogoutViewModel extends ChangeNotifier {
  Future<void> confirmLogout(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out? Your session will be ended.',
      confirmText: 'Log Out',
      cancelText: 'Cancel',
    );

    if (confirmed == true && context.mounted) {
      await _performLogout(context);
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = Theme.of(context).colorScheme.primary;
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            insetPadding: ctx.isShortScreen
                ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
                : null,
            child: Padding(
              // Tighter on a short window (a phone in landscape), where the
              // dialog's 32dp margins and the stacked icon, title and hint
              // would otherwise leave no room to spare.
              padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: ctx.isShortScreen ? 20 : 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Builder(
                        builder: (_) {
                          final reduceMotion = context
                              .read<SettingsProvider>()
                              .reduceMotion;
                          if (reduceMotion) {
                            return Icon(
                              Icons.hourglass_empty_rounded,
                              color: color,
                              size: 50,
                            );
                          }
                          return LoadingWidget(
                            size: 50,
                            color: color,
                            variant: LoadingVariant.staggeredDots,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Logging out...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we process your request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Small delay to let the dialog render smoothly
    await Future.delayed(const Duration(milliseconds: 900));

    context.read<HomeProvider>().clearProvider();

    await context.read<SessionService>().logout();

    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    }

    // Navigate to AppEntry (root decides next screen based on session state)
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        dynamicRoute(context, const AppEntry()),
        (route) => false,
      );
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }
  }
}
