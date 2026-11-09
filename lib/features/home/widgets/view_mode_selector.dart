import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/home_provider.dart';

/// The "Kanban ⌄" / "List ⌄" pill above the event list (§7's compact
/// dropdown recipe) that switches [HomeProvider.viewMode].
class ViewModeSelector extends StatelessWidget {
  final HomeViewMode value;
  final ValueChanged<HomeViewMode> onChanged;

  const ViewModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  String _label(HomeViewMode mode) =>
      mode == HomeViewMode.kanban ? 'Kanban' : 'List';

  /// The same glyphs mobo CRM's view selector uses for these two views.
  IconData _icon(HomeViewMode mode) =>
      mode == HomeViewMode.kanban ? Icons.view_kanban : Icons.menu;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<HomeViewMode>(
      initialValue: value,
      color: isDark ? AppTheme.darkPopupSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onSelected: onChanged,
      itemBuilder: (context) {
        // §7's selected-item convention: bold marks the current choice,
        // not a colour change — every item stays the same plain text
        // colour, matching the rest of the app's popup menus.
        final itemColor = isDark ? Colors.white : Colors.black87;
        return HomeViewMode.values
            .map(
              (mode) => PopupMenuItem<HomeViewMode>(
                value: mode,
                child: Row(
                  children: [
                    Icon(_icon(mode), size: 20, color: itemColor),
                    const SizedBox(width: 12),
                    Text(
                      _label(mode),
                      style: TextStyle(
                        fontWeight: mode == value
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: itemColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      child: Container(
        // 36px, the same as the chip and counter pill it shares a row with.
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(value),
              size: 18,
              color: AppTheme.textPrimaryOn(isDark),
            ),
            const SizedBox(width: 8),
            Text(
              _label(value),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOn(isDark),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppTheme.secondaryLabelColor(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
