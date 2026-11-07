import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/services/event_access_rights.dart';
import '../../../shared/widgets/section_list_state.dart';
import '../model/event_mail_scheduler.dart';
import 'mail_schedule_dialog.dart';
import '../../../core/theme/app_theme.dart';

class MailScheduleCard extends StatelessWidget {
  final EventMailScheduler mail;
  final int eventId;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const MailScheduleCard({
    super.key,
    required this.mail,
    required this.eventId,
    this.onDelete,
    this.onEdit,
  });

  Color getStatusColor() {
    switch (mail.mailState.toLowerCase()) {
      case 'sent':
        return StatusColors.green;
      case 'scheduled':
        return StatusColors.green;
      case 'running':
        return StatusColors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = AppTheme.secondaryLabelColor(isDark);
    // Editing a scheduler writes `event.mail` through the event, so the card
    // opens for editing only when the account can write both.
    final canEdit = context.watch<AccessRights>().canEditScheduler;

    // The bordered, shadow-less row the Tickets, Communication and Questions
    // lists share (see [SectionCard]).
    return SectionCard(
      onTap: !canEdit
          ? null
          : () {
              showDialog(
                context: context,
                builder: (_) => MailScheduleDialog(
                  eventId: eventId,
                  isEdit: true,
                  scheduler: mail,
                ),
              );
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Centred, as the ticket and question cards, so the "⋮" sits
            // level with the title block.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mail.templateName.toString().isEmpty
                          ? "Not"
                          : mail.templateName.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOn(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mail.eventName.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: meta),
                    ),
                  ],
                ),
              ),

              if (onDelete != null) SectionDeleteButton(onPressed: onDelete!),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                getNotificationIcon(mail.notificationType),
                color: getStatusColor(),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                mail.mailState.toUpperCase(),
                style: TextStyle(
                  color: getStatusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: meta),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Scheduled: ${mail.startFullDate} - ${mail.scheduleTime}",
                  style: TextStyle(fontSize: 12.5, color: meta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.people, size: 16, color: meta),
              const SizedBox(width: 6),
              Text(
                "Recipients: ${mail.mailCountDone}",
                style: TextStyle(fontSize: 12.5, color: meta),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sms':
        return Icons.sms;
      case 'mail':
        return Icons.email;
      default:
        return Icons.notifications;
    }
  }
}
