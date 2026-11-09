import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/toggles/mobo_toggle.dart';

/// The event form's "Published" switch — Odoo's `website_published` field
/// ("Visible on current website", a `boolean_toggle`), with the "?" help beside
/// its label.
///
/// [scheduledOn] is Odoo 20's `publish_on`. Odoo marks the field readonly while
/// it is set (`readonly="publish_on"`), so the switch locks and says when the
/// event goes live; Odoo 17–19 have no scheduling and never pass it.
class PublishedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final DateTime? scheduledOn;

  const PublishedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.scheduledOn,
  });

  @override
  Widget build(BuildContext context) {
    final scheduled = scheduledOn;
    return MoboToggleTile(
      title: 'Published',
      value: value,
      onChanged: scheduled == null ? onChanged : null,
      helpTitle: 'Visible on current website',
      helpLines: [
        'On: the event shows on your website.',
        'Off: it stays hidden from website visitors.',
        if (scheduled != null) 'Locked while a publish date is scheduled.',
      ],
      caption: scheduled == null
          ? null
          : 'Scheduled to publish on ${publishDateFormat.format(scheduled)}',
    );
  }
}

/// How a scheduled publish date reads, in the device's time zone.
final DateFormat publishDateFormat = DateFormat('dd MMM yyyy, hh:mm a');
