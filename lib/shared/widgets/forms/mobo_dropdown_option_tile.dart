import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One option row inside a dropdown, search or type-ahead list (CLAUDE.md §7).
///
/// Ported from mobo_fleet's vehicle-form dropdown so both apps read as one
/// system: the selected option shows in the brand colour with a trailing
/// check and a faint primary wash, so the current value is obvious in a long
/// list. Text weight follows §7: `w600` when selected, `w400` otherwise.
class MoboDropdownOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Leading avatar/icon, e.g. a person or company thumbnail.
  final Widget? leading;

  /// Right-hand content that is part of the option itself (stock, price, …).
  /// The selected check is shown after it.
  final Widget? trailing;

  final bool isSelected;
  final VoidCallback onTap;

  /// Override for a subtitle that carries its own meaning, e.g. an SKU shown
  /// in the brand colour.
  final Color? subtitleColor;

  const MoboDropdownOptionTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isSelected = false,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.valueColor(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            subtitleColor ?? AppTheme.secondaryLabelColor(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic grey circular avatar for an option that has no photo (§16).
/// Falls back to a person icon — the same treatment mobo_fleet uses for a
/// driver with no `avatar128`.
class MoboOptionAvatar extends StatelessWidget {
  final IconData icon;

  const MoboOptionAvatar({super.key, this.icon = Icons.person});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CircleAvatar(
      radius: 18,
      backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      child: Icon(
        icon,
        color: isDark ? Colors.white70 : Colors.black54,
        size: 20,
      ),
    );
  }
}
