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
  /// Fetch event details. [fields] limits the read to those columns; null
  /// reads them all (see [EventDetailedModel.readFields]).
  ///
  /// A `read` by id, not a `search_read`: the search leaves out archived
  /// events, which Home lists under its Archived filter, so opening one
  /// failed with an empty result.
  Future<EventDetailedModel> gettingEventDetails(
    int id, {
    List<String>? fields,
  }) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'read',
        'args': [
          [id],
          if (fields != null) fields,
        ],
        'kwargs': {},
      });

      if (response is! List || response.isEmpty) {
        throw Exception('This event no longer exists');
      }
      final event = EventDetailedModel.fromJson(response.first);

      return event;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch event tickets. [fields] limits the read to those columns; null
  /// reads them all (see [EventTicket.readFields]).
  Future<List<EventTicket>> getEventTickets(
    int eventId, {
    List<String>? fields,
  }) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event.ticket',
        'method': 'search_read',
        'args': [
          [
            ['event_id', '=', eventId],
          ],
        ],
        'kwargs': {if (fields != null) 'fields': fields},
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

  /// Delete event ticket
  Future<bool> deleteEventTicket(int ticketId) async {
    try {
      if (ticketId == 0) {
        return false;
      }
      await OdooSessionManager.callKwWithCompany({
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

  /// Fetch event short details
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
        // FetchModel only reads id and display_name; without a field list
        // search_read returns every field, contact images included.
        'kwargs': {
          'domain': finalDomain,
          'fields': ['display_name'],
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  /// Fetch event short details
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
        // FetchModel only reads id and display_name; without a field list
        // search_read returns every field, contact images included.
        'kwargs': {
          'domain': finalDomain,
          'limit': limit,
          'fields': ['display_name'],
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  /// Fetch event short details
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
        // FetchModel only reads id and display_name; without a field list
        // search_read returns every field, contact images included.
        'kwargs': {
          'domain': finalDomain,
          'fields': ['display_name'],
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  /// Fetch event short details
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

  /// Fetch event short details
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
    } catch (_) {
      rethrow;
    }
  }

  /// Fetch event slot details
  Future<List<EventSlotModel>> fetchEventSlotDetails(int eventId) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.slot',
        'method': 'search_read',
        'args': [],
        // event.slot only exists on Odoo 19. Without a field list
        // search_read also pulls registration_ids and the seat computes.
        'kwargs': {
          'domain': [
            ['event_id', '=', eventId],
          ],
          'fields': [
            'display_name',
            'start_datetime',
            'end_datetime',
            'color',
            'date_tz',
            'seats_taken',
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

  /// Delete event slot
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

  /// Create event slots
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

  /// Fetch event short details by onchange
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

  /// Create event
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

  /// Fetch model fields
  Future<Map<String, dynamic>> getModelFields(String model) async {
    final fields = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [],
      'kwargs': {},
    });

    return Map<String, dynamic>.from(fields);
  }

  /// Symbol of the active company's currency (what Odoo prices tickets in),
  /// or null when it can't be read.
  Future<String?> getCompanyCurrencySymbol() async {
    final session = await OdooSessionManager.getCurrentSession();
    final companyId = session?.companyId;
    if (companyId == null) return null;

    final companies = await OdooSessionManager.callKwWithCompany({
      'model': 'res.company',
      'method': 'read',
      'args': [
        [companyId],
        ['currency_id'],
      ],
      'kwargs': {},
    });
    final currency = (companies as List).isNotEmpty
        ? companies.first['currency_id']
        : null;
    if (currency is! List || currency.isEmpty) return null;

    final currencies = await OdooSessionManager.callKwWithCompany({
      'model': 'res.currency',
      'method': 'read',
      'args': [
        [currency.first],
        ['symbol'],
      ],
      'kwargs': {},
    });
    final symbol = (currencies as List).isNotEmpty
        ? currencies.first['symbol']
        : null;
    return symbol is String && symbol.isNotEmpty ? symbol : null;
  }
}
