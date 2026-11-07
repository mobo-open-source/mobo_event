import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';

/// The filters currently applied, as removable capsules with a trailing ×.
/// Light: a pale brand box, brand @ 30% outline, brand text. Dark: a deep brand
/// box with the brand text lightened to stay readable on it. Both fills are
/// opaque (see [FilterOptionChip]). The × is drawn in the text colour.
class ActivatedFilterList extends StatelessWidget {
  final List<String> activeList;
  final Function(String value)? onRemove;

  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;

  const ActivatedFilterList({
    super.key,
    required this.activeList,
    this.onRemove,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppTheme.darkActiveFill : AppTheme.primaryTintSolid;
    final outline = isDark
        ? AppTheme.darkActiveBorder
        : AppTheme.primaryColor.withValues(alpha: 0.3);
    final text = isDark ? AppTheme.darkActiveText : AppTheme.primaryColor;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: activeList.map((single) {
        return GestureDetector(
          onTap: () {
            if (onRemove != null) {
              onRemove!(single);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor ?? fill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor ?? outline, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  single,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? text,
                  ),
                ),
                const SizedBox(width: 6),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMultiplicationSign,
                  color: iconColor ?? textColor ?? text,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
