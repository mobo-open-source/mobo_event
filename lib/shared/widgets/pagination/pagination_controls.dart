import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';

/// The "1-7 / 7" counter pill (CLAUDE.md §14): 36px tall, fully rounded,
/// bordered, no shadow. Shared by [PaginationControls] and by views that show
/// a count without paging (the Kanban board), so the two never drift apart.
class PaginationCounterPill extends StatelessWidget {
  final String text;

  const PaginationCounterPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The record count and prev/next arrows of a paged list.
///
/// * No count when [totalCount] is 0.
/// * No arrows when everything fits on one page.
/// * On a longer list an arrow that can't be used stays on screen, dimmed and
///   inert (CLAUDE.md §14), so the pair is always there and both keep their
///   slot — a quick second tap never lands on the other arrow.
/// * With neither a count nor an arrow, nothing is drawn.
class PaginationControls extends StatelessWidget {
  final bool canGoToPreviousPage;
  final bool canGoToNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String paginationText;
  final bool isDark;
  final ThemeData theme;

  /// Records across every page; null always shows the count.
  final int? totalCount;

  const PaginationControls({
    super.key,
    required this.canGoToPreviousPage,
    required this.canGoToNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.paginationText,
    required this.isDark,
    required this.theme,
    this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    // Black arrows vanish on the dark background, so they flip with the theme.
    final Color iconActive = isDark ? Colors.white : Colors.black;
    // §14: an arrow with nowhere to go dims to grey[400] / grey[600].
    final Color iconDisabled = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final showCount = totalCount != 0;
    final showArrows = canGoToPreviousPage || canGoToNextPage;

    if (!showCount && !showArrows) return const SizedBox.shrink();

    Widget arrow(
      List<List<dynamic>> icon,
      bool enabled,
      VoidCallback onPressed,
    ) {
      // §14: a 32×36 tap target with a circular ripple. With no `onTap` the
      // InkWell neither ripples nor reports itself as a button.
      return InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 36,
          child: Center(
            child: HugeIcon(
              icon: icon,
              size: 20,
              color: enabled ? iconActive : iconDisabled,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCount) PaginationCounterPill(text: paginationText),
        if (showArrows) ...[
          const SizedBox(width: 4),
          arrow(
            HugeIcons.strokeRoundedArrowLeft01,
            canGoToPreviousPage,
            onPreviousPage,
          ),
          arrow(
            HugeIcons.strokeRoundedArrowRight01,
            canGoToNextPage,
            onNextPage,
          ),
        ],
      ],
    );
  }
}
