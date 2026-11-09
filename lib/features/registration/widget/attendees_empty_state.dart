import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/theme/app_theme.dart';

import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// "No Attendees expected yet!" — the empty body of the two attendee lists.
///
/// Only one action makes sense at a time: a filter, search or group-by
/// narrowed the list to nothing ([filtered], offer to clear all three), or the list is genuinely empty
/// (offer to retry).
///
/// On a short (landscape) window the lead-in and the ghost shrink: at full
/// size the 50dp lead-in + 180dp animation alone take the whole visible height
/// and push the message and button below the fold (it still scrolls).
class AttendeesEmptyState extends StatelessWidget {
  final bool filtered;
  final Future<void> Function() onClear;
  final Future<void> Function() onRetry;

  const AttendeesEmptyState({
    super.key,
    required this.filtered,
    required this.onClear,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final short = context.isShortScreen;

    // A filter, search or group-by that left nothing gets the "No results"
    // wording and the way out; a genuinely empty list keeps its own.
    final title = Text(
      filtered ? 'No results found' : 'No Attendees expected yet!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppTheme.dark,
      ),
    );
    final message = Text(
      filtered
          ? 'Try adjusting your filters or group by'
          : 'wait until Attendees register to your Event or Create their registration manually',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
    );

    final action = filtered
        ? ClearAllFiltersButton(onPressed: onClear)
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 40),
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onRetry,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 13,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text("Retry", style: TextStyle(color: Colors.white)),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            // Centred top-to-bottom in the available area (mobo Billing's
            // EmptyStateWidget), not pinned under a fixed lead-in gap — that
            // left the title, message and button clustered near the top with
            // the rest of the screen's height sitting empty beneath them.
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: short ? 80 : 180,
                    child: Lottie.asset('assets/lotties/empty ghost.json'),
                  ),
                  SizedBox(height: short ? 4 : 16),
                  title,
                  SizedBox(height: short ? 6 : 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: message,
                  ),
                  SizedBox(height: short ? 8 : 20),
                  action,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
