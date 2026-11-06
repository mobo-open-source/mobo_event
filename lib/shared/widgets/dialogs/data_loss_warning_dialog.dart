import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/utils/screen_layout.dart';
import '../mobo/mobo_button.dart';
import 'pinned_footer_layout.dart';

class DataLossWarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;

  const DataLossWarningDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.onCancel,
    this.confirmText = 'Leave',
    this.cancelText = 'Stay',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    // A phone in landscape is ~300–400dp tall: tighter margins and a smaller
    // icon, and the text scrolls while the footer buttons stay in view.
    final short = context.isShortScreen;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      insetPadding: short
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
          : null,
      child: Padding(
        padding: EdgeInsets.all(short ? 16 : 24),
        child: PinnedFooterLayout(
          gap: short ? 16 : 24,
          scrollAllBelow: 110,

          // Action Buttons — the §5 footer.
          footer: MoboButtonRow(
            secondaryLabel: cancelText,
            onSecondary: onCancel ?? () => Navigator.of(context).pop(false),
            primaryLabel: confirmText,
            onPrimary: () {
              Navigator.of(context).pop(true);
              onConfirm();
            },
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(short ? 12 : 16),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  color: primaryColor,
                  size: short ? 26 : 32,
                ),
              ),
              SizedBox(height: short ? 12 : 20),

              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Leave',
    String cancelText = 'Stay',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DataLossWarningDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: () {},
      ),
    );
  }
}
