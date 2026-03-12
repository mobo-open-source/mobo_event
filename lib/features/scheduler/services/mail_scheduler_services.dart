import 'package:mobo_event/core/services/odoo_session_manager.dart';
import 'package:mobo_event/features/scheduler/model/template_model.dart';

import '../model/event_mail_scheduler.dart';

class MailSchedulerServices {
  Future<List<EventMailScheduler>> fetchCommunication(int eventId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.mail',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['event_id', '=', eventId],
          ],
          'fields': [],
        },
      });

      final res = result as List;
      var communication = res
          .map((e) => EventMailScheduler.fromJson(e))
          .toList();

      final mailIds = <int>[];
      final smsIds = <int>[];

      for (var e in communication) {
        if (e.templateRef == null) continue;

        final parts = e.templateRef!.split(',');
        if (parts.length != 2) continue;

        final model = parts[0];
        final id = int.tryParse(parts[1]);
        if (id == null) continue;

        if (model == 'mail.template') mailIds.add(id);
        if (model == 'sms.template') smsIds.add(id);
      }

      final Map<String, String> templateMap = {};

      if (mailIds.isNotEmpty) {
        final mails = await OdooSessionManager.callKwWithCompany({
          'model': 'mail.template',
          'method': 'read',
          'args': [
            mailIds.toSet().toList(),
            ['id', 'name'],
          ],
          'kwargs': {},
        });

        for (var t in mails) {
          templateMap['mail.template,${t['id']}'] = t['name'];
        }
      }

      if (smsIds.isNotEmpty) {
        final sms = await OdooSessionManager.callKwWithCompany({
          'model': 'sms.template',
          'method': 'read',
          'args': [
            smsIds.toSet().toList(),
            ['id', 'name'],
          ],
          'kwargs': {},
        });

        for (var t in sms) {
          templateMap['sms.template,${t['id']}'] = t['name'];
        }
      }

      communication = communication.map((e) {
        return EventMailScheduler(
          id: e.id,
          displayName: e.displayName,
          eventId: e.eventId,
          eventName: e.eventName,
          sequence: e.sequence,
          intervalNbr: e.intervalNbr,
          intervalUnit: e.intervalUnit,
          intervalType: e.intervalType,
          scheduledDate: e.scheduledDate,
          lastRegistrationId: e.lastRegistrationId,
          mailRegistrationIds: e.mailRegistrationIds,
          mailSlotIds: e.mailSlotIds,
          mailDone: e.mailDone,
          mailState: e.mailState,
          mailCountDone: e.mailCountDone,
          notificationType: e.notificationType,
          templateRef: e.templateRef,
          templateId: e.templateId,
          templateName: templateMap[e.templateRef],
          createUid: e.createUid,
          createUser: e.createUser,
          createDate: e.createDate,
          writeUid: e.writeUid,
          writeUser: e.writeUser,
          writeDate: e.writeDate,
        );
      }).toList();

      return communication;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> removeScheduledMail(int schedulerId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.mail',
        'method': 'unlink',
        'args': [
          [schedulerId],
        ],
        'kwargs': {},
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TemplateModel>> getTemplate({
    required String model,
    String? search,
    int limit = 3,
  }) async {
    try {
      final List domain = [];

      if (search != null && search.isNotEmpty) {
        domain.add(['name', 'ilike', search]);
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['model', '=', 'event.registration'],
            if (search != null && search.isNotEmpty) ['name', 'ilike', search],
          ],
          'fields': ['id', 'name'],

          'limit': limit,
        },
      });

      final List result = response as List;

      return result
          .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      rethrow;
    }
  }

  Future<bool> attachMailToEvent({
    required int eventId,
    required List<dynamic> mailValues,
  }) async {
    final result = await OdooSessionManager.callKwWithCompany({
      "model": "event.event",
      "method": "write",
      "args": [
        [eventId],
        {
          "event_mail_ids": [mailValues],
        },
      ],
    });

    return result == true;
  }
}
