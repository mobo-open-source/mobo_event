import 'package:flutter/material.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';

import '../../../core/services/odoo_session_manager.dart';
import '../model/activity_type.dart';
import '../model/user_model.dart';

class EventActivityServices {
  Future<List<ActivitiesModel>> fetchActivities(
    List<dynamic> activityIds,
  ) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', activityIds],
          ],
        ],
        'kwargs': {},
      });

      final response = res as List;
      final activityList = response
          .map((single) => ActivitiesModel.fromJson(single))
          .toList();

      return activityList;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAsDone(int activityId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'action_done',
        'args': [
          [activityId],
        ],
        'kwargs': {},
      });
    } catch (e) {}
  }

  Future<void> removeActivity(int activityId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'unlink',
        'args': [
          [activityId],
        ],
        'kwargs': {},
      });
    } catch (e) {}
  }

  Future<List<ActivityTypeModel>> fetchActivityTypes({
    String? search,
    int limit = 3,
  }) async {
    final domain = [
      '|',
      ['res_model', '=', false],
      ['res_model', '=', 'event.event'],
    ];

    if (search != null && search.isNotEmpty) {
      domain.add(['name', 'ilike', search]);
    }

    final res = await OdooSessionManager.callKwWithCompany({
      'model': 'mail.activity.type',
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': ['id', 'name'],
        'limit': limit,
        'order': 'sequence asc',
      },
    });

    return (res as List).map((e) => ActivityTypeModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> fetchUsers({String? search, int limit = 3}) async {
    final domain = [];
    if (search != null && search.isNotEmpty) {
      domain.add(['name', 'ilike', search]);
    }

    final res = await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': ['id', 'name'],
        'limit': limit,
        'order': 'name asc',
        'context': {'active_model': 'event.event'},
      },
    });

    return (res as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<int> createActivity({
    required int resId,
    required String model,
    required int typeId,
    required int userId,
    required String summary,
    required String note,
    required String deadline,
  }) async {
    try {
      final client = await OdooSessionManager.getClient();

      final res = await client!.callKw({
        'model': 'mail.activity.schedule',
        'method': 'create',
        'args': [
          {
            'res_model': model,
            'activity_type_id': typeId,
            'activity_user_id': userId,
            'summary': summary,
            'note': note,
            'date_deadline': deadline,
          },
        ],
        'kwargs': {
          'context': {
            'active_model': 'event.event',
            'active_ids': [resId],
            'active_id': resId,
          },
        },
      });

      await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity.schedule',
        'method': 'action_schedule_activities',
        'args': [
          [res],
        ],
        'kwargs': {
          'context': {
            'active_model': model,
            'active_ids': [resId],
            'active_id': resId,
          },
        },
      });

      return res as int;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateActivity({
    required int activityId,
    required int typeId,
    required int userId,
    required String summary,
    required String note,
    required String deadline,
  }) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'write',
        'args': [
          [activityId],
          {
            'activity_type_id': typeId,
            'user_id': userId,
            'summary': summary,
            'note': note,
            'date_deadline': deadline,
          },
        ],
      });
    } catch (e) {
      rethrow;
    }
  }
}
