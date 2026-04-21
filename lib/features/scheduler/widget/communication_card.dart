

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';
import '../model/event_mail_scheduler.dart';
import 'mail_schedule_dialog.dart';

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
        return Colors.green;
      case 'scheduled':
        return Colors.green;
      case 'running':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){

        showDialog(
          context: context,
          builder: (_) =>  MailScheduleDialog(
            eventId: eventId,
            isEdit: true,
            scheduler: mail,
          ),
        );


      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 14, top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                         " ${mail.templateName.toString().isEmpty? "Not":mail.templateName.toString()}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mail.eventName.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (value) {
                       if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [

                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Row(
                    children: [
                      Icon(getNotificationIcon(mail.notificationType),color: getStatusColor(),size: 18,),
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
                ],
              ),

              const SizedBox(height: 10),


              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Scheduled: ${mail.startFullDate} - ${mail.scheduleTime}",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  const Icon(Icons.people,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    "Recipients: ${mail.mailCountDone}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
