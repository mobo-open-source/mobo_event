import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A selectable filter option: a rounded square (radius 8), no checkmark.
/// Picked, it is solid brand colour with white w600 text. At rest it is a
/// pale brand box with a grey outline in light mode and a neutral grey box in
/// dark mode. Every fill is opaque — the dark theme keeps a light canvas, so a
/// translucent fill would glow on the dark sheet. Shared by every filter sheet
/// so they all read the same.
class FilterOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill;
    final Color outline;
    final Color text;
    if (selected) {
      fill = AppTheme.primaryColor;
      outline = AppTheme.primaryColor;
      text = Colors.white;
    } else if (isDark) {
      fill = AppTheme.darkOptionFill;
      outline = AppTheme.darkOptionBorder;
      text = Colors.white;
    } else {
      fill = AppTheme.primaryTintSolid;
      outline = Colors.grey[300]!;
      text = Colors.black87;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        // 1px less than the 8×12 inset, to make room for the outline.
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 13,
            fontWeight: selected || isDark ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
