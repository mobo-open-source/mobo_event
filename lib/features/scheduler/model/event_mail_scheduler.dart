
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class EventMailScheduler {
  final int id;
  final String? displayName;
  final int? eventId;
  final String? eventName;

  final int sequence;
  final int intervalNbr;
  final String intervalUnit;
  final String intervalType;

  final DateTime? scheduledDate;
  final int? lastRegistrationId;

  final List<int> mailRegistrationIds;
  final List<int> mailSlotIds;

  final bool mailDone;
  final String mailState;
  final int mailCountDone;

  final String notificationType;

  final String? templateRef;
  final int? templateId;
  final String? templateName;

  final int? createUid;
  final String? createUser;
  final DateTime? createDate;

  final int? writeUid;
  final String? writeUser;
  final DateTime? writeDate;

  EventMailScheduler({
    required this.id,
    this.displayName,
    this.eventId,
    this.eventName,
    required this.sequence,
    required this.intervalNbr,
    required this.intervalUnit,
    required this.intervalType,
    this.scheduledDate,
    this.lastRegistrationId,
    required this.mailRegistrationIds,
    required this.mailSlotIds,
    required this.mailDone,
    required this.mailState,
    required this.mailCountDone,
    required this.notificationType,
    this.templateRef,
    this.templateId,
    this.templateName,
    this.createUid,
    this.createUser,
    this.createDate,
    this.writeUid,
    this.writeUser,
    this.writeDate,
  });

  static DateTime _safeDate(dynamic v) {
    try {
      if (v is String && v.isNotEmpty) {
        final cleaned =
        v.split('.').first.replaceAll(' ', 'T').padRight(20, 'Z');
        return DateTime.parse(cleaned).toLocal();
      }
    } catch (_) {}
    return DateTime.now();
  }

  factory EventMailScheduler.fromJson(Map<String, dynamic> json) {
    int? tId;
    if (json['template_ref'] is String &&
        (json['template_ref'] as String).contains(',')) {
      tId = int.tryParse(
          (json['template_ref'] as String).split(',').last);
    }

    return EventMailScheduler(
      id: json['id'],
      displayName: json['display_name'],
      templateRef: json['template_ref'],
      templateId: tId,
      templateName: null,

      eventId: json['event_id'] is List ? json['event_id'][0] : null,
      eventName: json['event_id'] is List ? json['event_id'][1] : null,

      sequence: json['sequence'] ?? 0,
      intervalNbr: json['interval_nbr'] ?? 0,
      intervalUnit: json['interval_unit'] ?? '',
      intervalType: json['interval_type'] ?? '',

      scheduledDate: json['scheduled_date'] != null
          ? _safeDate(json['scheduled_date'])
          : null,

      lastRegistrationId: json['last_registration_id'] is int
          ? json['last_registration_id']
          : null,

      mailRegistrationIds:
      List<int>.from(json['mail_registration_ids'] ?? []),

      mailSlotIds:
      List<int>.from(json['mail_slot_ids'] ?? []),

      mailDone: json['mail_done'] ?? false,
      mailState: json['mail_state'] ?? '',
      mailCountDone: json['mail_count_done'] ?? 0,

      notificationType: json['notification_type'] ?? '',

      createUid: json['create_uid'] is List ? json['create_uid'][0] : null,
      createUser: json['create_uid'] is List ? json['create_uid'][1] : null,

      createDate: json['create_date'] != null
          ? DateTime.parse(json['create_date'])
          : null,

      writeUid: json['write_uid'] is List ? json['write_uid'][0] : null,
      writeUser: json['write_uid'] is List ? json['write_uid'][1] : null,

      writeDate: json['write_date'] != null
          ? DateTime.parse(json['write_date'])
          : null,
    );
  }
}
extension EventMailSchedulerUI on EventMailScheduler {

  /// Extract model from template_ref
  String? get templateModel {
    if (templateRef == null) return null;
    if (!templateRef!.contains(',')) return null;
    return templateRef!.split(',').first; // mail.template / sms.template
  }

  bool get isMail => templateModel == 'mail.template';
  bool get isSms  => templateModel == 'sms.template';

  IconData get notificationIcon {
    if (isSms) return Icons.sms;
    if (isMail) return Icons.email;
    return Icons.notifications;
  }

  Color get notificationColor {
    if (isSms) return StatusColors.green;
    if (isMail) return StatusColors.blue;
    return Colors.grey;
  }

  String get notificationLabel {
    if (isSms) return 'SMS';
    if (isMail) return 'Email';
    return 'Notification';
  }

  String get scheduleTime =>
      scheduledDate == null ? '--:--' : DateFormat('hh:mm a').format(scheduledDate!);

  String get startFullDate =>
      scheduledDate == null ? '--' : DateFormat('dd MMM yyyy').format(scheduledDate!);
}

