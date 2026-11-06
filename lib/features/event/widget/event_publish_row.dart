import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../model/event_detailed_model.dart';

/// Whether the event is live on the website, as a globe icon and a word — laid
/// out like the date row above it on Details (16px icon, 12px bold text).
///
/// Green for Published, grey for Not published and — on Odoo 20, which can
/// schedule a publish — blue for Scheduled. Callers show it only when
/// [EventDetailedModel.hasPublishState], since a server without
/// `website_event` has no published state to report.
class EventPublishRow extends StatelessWidget {
  final EventDetailedModel event;

  const EventPublishRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String label;
    final Color color;
    if (event.isLive) {
      label = 'Published';
    } else if (event.isPublishScheduled) {
      label =
          'Scheduled · ${DateFormat('dd MMM, hh:mm a').format(event.publishOn!)}';
    } else {
      label = 'Not published';
      color = AppTheme.secondaryLabelColor(isDark);
    }

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedGlobal, size: 16, color: AppTheme.secondaryLabelColor(isDark)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
