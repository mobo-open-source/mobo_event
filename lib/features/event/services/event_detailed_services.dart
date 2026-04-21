import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/model/event_sample_response.dart';
import 'package:mobo_event/features/event/model/event_slot.dart';
import 'package:mobo_event/features/event/model/event_type_model.dart';
import 'package:mobo_event/features/event/model/fetch_model.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';

import '../../../core/services/odoo_session_manager.dart';
import '../../ticket/model/event_ticket_model.dart';

class EventDetailedServices {
  Future<EventDetailedModel> gettingEventDetails(int id) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {},
      });

      final res = response[0];
      final event = EventDetailedModel.fromJson(res);

      return event;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EventTicket>> getEventTickets(int eventId) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event.ticket',
        'method': 'search_read',
        'args': [
          [
            ['event_id', '=', eventId],
          ],
        ],
        'kwargs': {},
      });

      final respons = res as List;
      final ticket = respons
          .map((single) => EventTicket.fromJson(single))
          .toList();
      return ticket;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteEventTicket(int ticketId) async {
    try {
      if (ticketId == 0) {
        return false;
      }
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event.ticket',
        'method': 'unlink',
        'args': [
          [ticketId],
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FetchModel>> getTypeHeadSearchListTags({
    required String model,
    String? search,
    List domain = const [],
  }) async {
    try {
      final List finalDomain = List.from(domain);

      if (search != null && search.isNotEmpty) {
        finalDomain.add(['name', 'ilike', search]);
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': finalDomain},
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
      rethrow;
    }
  }

  Future<List<FetchModel>> getTypeHeadSearchList({
    required String model,
    String? search,
    int limit = 3,
    List domain = const [],
  }) async {
    try {
      final List finalDomain = List.from(domain);

      if (search != null && search.isNotEmpty) {
        finalDomain.add(['name', 'ilike', search]);
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': finalDomain, 'limit': limit},
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
      rethrow;
    }
  }

  Future<List<FetchModel>> getTypeHeadSearchTagList({
    required String model,
    String? search,
    List domain = const [],
  }) async {
    try {
      final List finalDomain = List.from(domain);

      if (search != null && search.isNotEmpty) {
        finalDomain.add(['name', 'ilike', search]);
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': finalDomain},
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
      rethrow;
    }
  }

  editEventDetails({
    required int eventId,
    required Map<String, dynamic> vals,
  }) async {
    try {
      if (vals.isEmpty) return true;

      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          vals,
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<EventTypeModel> eventTemplate(int id) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.type',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', id],
          ],
        },
      });

      final res = response[0];

      final template = EventTypeModel.fromJson(res);

      return template;
    } catch (e, st) {
      rethrow;
    }
  }

  Future<List<EventSlotModel>> fetchEventSlotDetails(int eventId) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.slot',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['event_id', '=', eventId],
          ],
        },
      });

      final result = response as List;
      final slotDetails = result
          .map((item) => EventSlotModel.fromJson(item))
          .toList();
      return slotDetails;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteSlot(int id) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.slot',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future createEventSlots(List<Map<String, dynamic>> slots) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.slot',
        'method': 'create',
        'args': [slots],
        'kwargs': {},
      });
    } catch (e) {
      rethrow;
    }
  }

  Future onChangeEvent() async {
    try {
      final selectedCompany = await OdooSessionManager.getSelectedCompanyId();
      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'event.event',
          'method': 'onchange',
          'args': [
            [],
            {},
            [],
            {
              'stage_id': {
                'fields': {'display_name': {}},
              },
              'is_published': {},
              'seats_taken': {},
              'website_url': {},
              'active': {},
              'company_id': {
                'fields': {'display_name': {}},
              },
              'kanban_state': {},
              'write_date': {},
              'name': {},
              'website_menu': {},

              'community_menu': {},
              'date_begin': {},
              'date_end': {},
              'date_tz': {},

              'lang': {},
              'event_type_id': {
                'fields': {'display_name': {}},
              },
              'tag_ids': {
                'fields': {'display_name': {}, 'color': {}},
              },
              'organizer_id': {
                'fields': {'display_name': {}},
              },
              'user_id': {
                'fields': {'display_name': {}},
              },
              'website_id': {
                'fields': {'display_name': {}},
              },
              'website_published': {},

              'seats_limited': {},
              'seats_max': {},
              'address_id': {
                'fields': {'display_name': {}},
              },

              'badge_format': {},
              'badge_image': {},
              'ticket_instructions': {},
              'note': {},
              'display_name': {},
            },
          ],
          'kwargs': {},
        },
        companyId: selectedCompany,
        allowedCompanyIds: [selectedCompany!],
      );

      final event = EventResponse.fromJson(result);

      return event;
    } catch (e) {
      rethrow;
    }
  }

  Future<int?> createEvent({required Map<String, dynamic> vals}) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      });

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getModelFields(String model) async {
    final fields = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [],
      'kwargs': {},
    });

    return Map<String, dynamic>.from(fields);
  }
}
