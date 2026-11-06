import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// "Add" action button (CLAUDE.md §5 primary button).
///
/// Fixed 48px height, brand fill, radius 12, `elevation: 0` — buttons never
/// carry a `BoxShadow`. Sized to its content by default — wrap the call in
/// `SizedBox(width: double.infinity, child: actionButton(...))` for a
/// full-width footer button; never force the width here, since this widget
/// is also used inside centered/unbounded-width empty states.
Widget actionButton({
  required String label,
  required List<List<dynamic>> icon,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
