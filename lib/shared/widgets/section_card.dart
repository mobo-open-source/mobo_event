import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final List<Widget> children;
  final Widget? headerTrailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Was Colors.grey[900] — identical to this screen's own dark scaffold
    // background (settings_screen.dart), so a card had no contrast against
    // the page behind it and was effectively invisible. AppTheme.darkSurface
    // is this app's actual "card on a dark scaffold" tone.
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        // Computed above but never actually applied — another reason a
        // card's edge was indistinguishable from the page in dark mode.
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (headerTrailing != null) ...[headerTrailing!],
              ],
            ),
          ),

          ...children,
        ],
      ),
    );
  }
}
