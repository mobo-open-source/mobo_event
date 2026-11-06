import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/odoo_session_manager.dart';
import 'package:mobo_event/core/utils/odoo_binary.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/home/model/user_short_model.dart';

class HomeServices {
  /// getting all stages
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
    } catch (_) {
      rethrow;
    }
  }

  /// getting events details
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

            return UserShortModel(
              userId: data['id'],
              name: data['name'],
              // Base64 text through Odoo 19, a {content, size} object on 20.
              image: OdooBinary.bytes(data['image_1920']),
            );
          } catch (_) {
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
    } catch (_) {
      rethrow;
    }
  }

  /// Moves an event to a different stage (kanban column drag, or any other
  /// stage change) by writing `stage_id` directly.
  Future<bool> updateEventStage({
    required int eventId,
    required int stageId,
  }) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {'stage_id': stageId},
        ],
        'kwargs': {},
      });

      return res == true;
    } catch (_) {
      rethrow;
    }
  }

  /// Moves an event to another group of a grouped board by writing the field
  /// that grouping is on (`user_id`, `event_type_id`, `address_id`) — what
  /// Odoo's own kanban does when a card is dropped on a column. [id] 0 is the
  /// "none" column: the field is cleared.
  Future<bool> updateEventRelation({
    required int eventId,
    required String field,
    required int id,
  }) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {field: id == 0 ? false : id},
        ],
        'kwargs': {},
      });

      return res == true;
    } catch (_) {
      rethrow;
    }
  }

  /// Renames a stage (kanban column header's "⋮" action).
  Future<bool> renameStage({required int stageId, required String name}) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'write',
        'args': [
          [stageId],
          {'name': name},
        ],
        'kwargs': {},
      });
      return res == true;
    } catch (_) {
      rethrow;
    }
  }

  /// Persists one stage's new column position (kanban column drag).
  Future<bool> updateStageSequence({
    required int stageId,
    required int sequence,
  }) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'write',
        'args': [
          [stageId],
          {'sequence': sequence},
        ],
        'kwargs': {},
      });
      return res == true;
    } catch (_) {
      rethrow;
    }
  }

  /// Deletes a stage (kanban column's "Delete" action). Odoo refuses to
  /// unlink a stage that events still reference, so a blocked delete
  /// surfaces the server's own ValidationError as-is.
  Future<bool> deleteStage(int stageId) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'unlink',
        'args': [
          [stageId],
        ],
        'kwargs': {},
      });
      return res == true;
    } catch (_) {
      rethrow;
    }
  }

  /// Creates a new event.stage, appended after the current last one so it
  /// shows up as the last kanban column (mirrors Odoo's own "Add a column").
  Future<EventStage> createStage(String name, int sequence) async {
    try {
      final id = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'create',
        'args': [
          {'name': name, 'sequence': sequence},
        ],
        'kwargs': {},
      });

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.stage',
        'method': 'read',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return EventStage.fromJson((res as List).first);
    } catch (_) {
      rethrow;
    }
  }

  /// updating kanban state
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
    } catch (_) {
      // Not swallowed: a refusal (no write access on the event) has to reach
      // the caller, which otherwise reports "State changed" over a write that
      // never happened.
      rethrow;
    }
  }
}
