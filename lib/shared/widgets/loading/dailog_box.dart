import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import '../../../core/utils/screen_layout.dart';

dialogBox(BuildContext context, String title, Widget icon, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      // A phone in landscape is ~300–400dp tall: tighter margins, and the
      // content scrolls rather than overflowing.
      final short = context.isShortScreen;
      return Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: short
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
            : null,
        child: Padding(
          padding: EdgeInsets.all(short ? 16 : 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: short ? 48 : 60,
                  width: short ? 48 : 60,
                  padding: EdgeInsets.all(short ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryColor.withValues(alpha: 0.25)
                        : primaryColor.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: icon,
                ),

                SizedBox(height: short ? 12 : 20),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),

                const SizedBox(height: 10),
                DefaultTextStyle(
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
