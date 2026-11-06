import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../dialogs/pinned_footer_layout.dart';

Future<bool> showBackDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String leftButtonName,
  required String rightButtonName,
  required VoidCallback function,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          // A phone in landscape is ~300–400dp tall: tighter margins, and the
          // text scrolls while the Stay / Leave buttons stay in view.
          final short = context.isShortScreen;
          return Dialog(
            backgroundColor: isDark ? Colors.grey[850] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: short
                ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
                : null,
            child: Padding(
              padding: EdgeInsets.all(short ? 16 : 25),
              child: PinnedFooterLayout(
                gap: short ? 14 : 20,
                scrollAllBelow: 100,
                footer: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(120, 40),

                          backgroundColor: isDark
                              ? Colors.grey[850]
                              : Colors.white,

                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: Text(
                          leftButtonName,
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),

                    Expanded(
                      child: ElevatedButton(
                        key: Key("Success"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(120, 40),

                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: function,
                        child: Text(
                          rightButtonName,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: short ? 48 : 60,
                      width: short ? 48 : 60,

                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orangeAccent
                            : Colors.orangeAccent.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(short ? 10 : 12),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        color: isDark ? Colors.white : Colors.orangeAccent,
                      ),
                    ),
                    SizedBox(height: 10),

                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ) ??
      false;
}
