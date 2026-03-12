import 'dart:convert';

import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/odoo_session_manager.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/home/model/user_short_model.dart';

class HomeServices {
  Future gettingStage() async {
    try {
      await OdooSessionManager.getAllowedCompaniesList();

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'search_read',
        'args': [],
        'kwargs': {},
      });
      final response = res as List;
      final stageList = response
          .map((single) => EventStage.fromJson(single))
          .toList();
      return stageList;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EventShort>> gettingEventsShort({
    List<String> filter = const [],
    String search = '',
  }) async {
    try {
      final client = await OdooSessionManager.getClient();

      final userId = client!.sessionId?.userId;

      final domain = [];
      if (search.isNotEmpty) {
        domain.add(['name', 'ilike', search]);
      }

      if (filter.isNotEmpty) {
        if (filter.contains('My events')) {
          domain.add(["user_id", "=", userId]);
        }
        if (filter.contains('Published')) {
          domain.add(["website_published", "=", true]);
        }
        if (filter.contains('Archived')) {
          domain.add(["active", "=", false]);
        }

        if (filter.contains('Online')) {
          domain.add(["address_id", "=", false]);
        }
        if (filter.contains('Upcoming/Running')) {
          domain.add(["date_end", ">=", "now"]);
        }
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain},
      });

      final res = response as List;
      final eventList = res.map((e) => EventShort.fromJson(e)).toList();

      final uniqueUserIds = eventList.map((e) => e.userId).toSet().toList();
      final userImageList = await Future.wait(
        uniqueUserIds.map((userId) async {
          try {
            final userRes = await OdooSessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'read',
              'args': [
                [userId],
                ['name', 'image_1920'],
              ],
              'kwargs': {},
            });

            final data = userRes[0];
            final imgBase64 = data['image_1920'];

            return UserShortModel(
              userId: data['id'],
              name: data['name'],
              image: imgBase64 != null ? base64Decode(imgBase64) : null,
            );
          } catch (e) {
            return null;
          }
        }),
      );

      final userMap = {
        for (var u in userImageList.whereType<UserShortModel>()) u.userId!: u,
      };

      final updatedEvents = eventList.map((e) {
        final user = userMap[e.userId];
        if (user != null) {
          return e.copyWith(image: user.image);
        }
        return e;
      }).toList();

      return updatedEvents;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateKanbanState({
    required int eventId,
    required String newState,
  }) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {'kanban_state': newState},
        ],
        'kwargs': {},
      });

      return res == true;
    } catch (e) {
      return false;
    }
  }
}
