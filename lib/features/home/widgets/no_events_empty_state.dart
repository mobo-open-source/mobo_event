import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// The Home screen's "no events" empty state — ghost animation, message,
/// and (when a search, filter or group-by is what emptied the list) a Clear
/// All Filters button — shared by both the List and Kanban views so a filtered-out
/// board looks the same as a filtered-out list instead of each view
/// inventing its own empty state.
class NoEventsEmptyState extends StatelessWidget {
  final bool showClearFilters;
  final VoidCallback? onClearFilters;

  const NoEventsEmptyState({
    super.key,
    this.showClearFilters = false,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    // A phone in landscape is only ~300–400dp tall, so the animation shrinks to
    // leave room for the message and the button.
    final short = context.isShortScreen;
    final illustration = short ? 130.0 : 220.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: illustration,
          child: Lottie.asset(
            'assets/lotties/empty ghost.json',
            width: illustration,
          ),
        ),
        // A filter, search or group-by that left nothing gets the "No
        // results" wording and the way out; a plain empty list doesn't.
        Text(
          showClearFilters ? 'No results found' : 'No events found',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.dark,
          ),
        ),
        if (showClearFilters) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Try adjusting your filters or group by',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          SizedBox(height: short ? 12 : 20),
          ClearAllFiltersButton(onPressed: onClearFilters),
        ],
      ],
    );

    // Centred in the space it is given and scrolling, rather than overflowing,
    // when that space is shorter than the content. A list hands it unbounded
    // height, where it simply wraps the content as before.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
