import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobo_event/features/questions/model/event_question.dart';
import 'package:mobo_event/features/registration/model/attendee_model.dart';
import 'package:mobo_event/features/registration/model/attendee_short_model.dart';
import 'package:mobo_event/features/registration/model/event_reg_full.dart';
import 'package:mobo_event/features/registration/model/event_registration.dart'
    hide RegistrationAnswer;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/odoo_session_manager.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../event/model/fetch_model.dart';

class RegistrationServices {
  /// Add attendee by qr
  Future addAttendeesByQr(String qrCode) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'register_attendee',
        'args': [],
        'kwargs': {'barcode': qrCode, 'event_id': false},
      });

      return _parseScannedAttendee(response);
    } catch (_) {
      rethrow;
    }
  }

  /// Add attendee by qr
  Future<AttendeeModel> addAttendeesByQrByEvent(
    String qrCode,
    int eventId,
  ) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'register_attendee',
        'args': [qrCode, eventId],
        'kwargs': {},
      });

      return _parseScannedAttendee(response);
    } catch (_) {
      rethrow;
    }
  }

  /// Odoo answers an unknown/invalid code with `{'error': ...}` (no id/name).
  AttendeeModel _parseScannedAttendee(dynamic response) {
    if (response is! Map || response['error'] != null || response['id'] is! int) {
      final error = response is Map ? response['error'] : null;
      throw Exception(
        error == 'already_registered'
            ? 'Ticket already registered'
            : 'Invalid ticket',
      );
    }
    return AttendeeModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get attendees by event
  Future getAttendeesByEvent({
    required int limit,
    required int offset,
    required int eventId,
    String search = '',
    List<dynamic> filter = const [],
  }) async {
    try {
      final List domain = [
        ['event_id', '=', eventId],
      ];
      if (search.isNotEmpty) {
        domain.addAll([
          '|',
          '|',
          ['name', 'ilike', search],
          ['email', 'ilike', search],
          ['company_name', 'ilike', search],
        ]);
      }
      if (filter.isNotEmpty) {
        if (filter.contains('Unconfirmed or Registered')) {
          domain.addAll([
            "|",
            ["state", "=", "draft"],
            ["state", "=", "open"],
          ]);
        }
        if (filter.contains('Ongoing Events')) {
          domain.add(["event_id.is_ongoing", "=", true]);
        }
        if (filter.contains('Taken')) {
          domain.add([
            "state",
            "in",
            ["open", "done"],
          ]);
        }
        if (filter.contains('Unconfirmed')) {
          domain.add(["state", "=", "draft"]);
        }
        if (filter.contains('Registered')) {
          domain.add(["state", "=", "open"]);
        }
        if (filter.contains('Attended')) {
          domain.add(["state", "=", "done"]);
        }
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain, 'limit': limit, 'offset': offset},
      });
      final res = response as List;
      final attendees = res
          .map((items) => AttendeeShortModel.fromJson(items))
          .toList();
      return attendees;
    } catch (_) {
      rethrow;
    }
  }

  /// Get attendees count by event
  Future<int> gettingAttendeesCountByEvent({
    String search = '',
    List<dynamic> filter = const [],
    required int eventId,
  }) async {
    try {
      final List domain = [
        ['event_id', '=', eventId],
      ];
      if (search.isNotEmpty) {
        domain.addAll([
          '|',
          '|',
          ['name', 'ilike', search],
          ['email', 'ilike', search],
          ['company_name', 'ilike', search],
        ]);
      }
      if (filter.isNotEmpty) {
        if (filter.contains('Unconfirmed or Registered')) {
          domain.addAll([
            "|",
            ["state", "=", "draft"],
            ["state", "=", "open"],
          ]);
        }

        if (filter.contains('Ongoing Events')) {
          domain.add(["event_id.is_ongoing", "=", true]);
        }
        if (filter.contains('Taken')) {
          domain.add([
            "state",
            "in",
            ["open", "done"],
          ]);
        }
        if (filter.contains('Unconfirmed')) {
          domain.add(["state", "=", "draft"]);
        }
        if (filter.contains('Registered')) {
          domain.add(["state", "=", "open"]);
        }
        if (filter.contains('Attended')) {
          domain.add(["state", "=", "done"]);
        }
      }

      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return count as int;
    } catch (_) {
      rethrow;
    }
  }

  /// Every attendee matching [search] and [filter] — of one event when
  /// [eventId] is given — for a grouped list, which has to see all of them to
  /// know its groups and their counts (a page of 40 would split a group across
  /// pages). Only the fields the cards and the groupings read are asked for:
  /// without them Odoo returns every field of every registration.
  Future<List<AttendeeShortModel>> getAllAttendees({
    int? eventId,
    String search = '',
    List<String> filter = const [],
  }) async {
    try {
      final List domain = [
        if (eventId != null) ['event_id', '=', eventId],
      ];
      if (search.isNotEmpty) {
        domain.addAll([
          '|',
          '|',
          ['name', 'ilike', search],
          ['email', 'ilike', search],
          ['company_name', 'ilike', search],
        ]);
      }
      if (filter.contains('Unconfirmed or Registered')) {
        domain.addAll([
          "|",
          ["state", "=", "draft"],
          ["state", "=", "open"],
        ]);
      }
      if (filter.contains('Ongoing Events')) {
        domain.add(["event_id.is_ongoing", "=", true]);
      }
      if (filter.contains('Taken')) {
        domain.add([
          "state",
          "in",
          ["open", "done"],
        ]);
      }
      if (filter.contains('Unconfirmed')) {
        domain.add(["state", "=", "draft"]);
      }
      if (filter.contains('Registered')) {
        domain.add(["state", "=", "open"]);
      }
      if (filter.contains('Attended')) {
        domain.add(["state", "=", "done"]);
      }

      // `event_slot_id` is an Odoo 19 field; older servers don't know it.
      final compat = await OdooCompat.current();
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': [
            'name',
            'company_name',
            'event_id',
            'event_ticket_id',
            'barcode',
            'state',
            'partner_id',
            'create_date',
            if (compat.hasEventSlots) 'event_slot_id',
          ],
        },
      });

      return (response as List)
          .map((items) => AttendeeShortModel.fromJson(items))
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  /// Get attendees by pagination
  Future getAttendeesByPagination({
    required int limit,
    required int offset,
    String search = '',
    List<String> filter = const [],
  }) async {
    try {
      final List domain = [];

      if (search.isNotEmpty) {
        domain.addAll([
          '|',
          '|',
          ['name', 'ilike', search],
          ['email', 'ilike', search],
          ['company_name', 'ilike', search],
        ]);
      }

      if (filter.isNotEmpty) {
        if (filter.contains('Ongoing Events')) {
          domain.add(["event_id.is_ongoing", "=", true]);
        }
        if (filter.contains('Taken')) {
          domain.add([
            "state",
            "in",
            ["open", "done"],
          ]);
        }

        if (filter.contains('Unconfirmed')) {
          domain.add(["state", "=", "draft"]);
        }
        if (filter.contains('Registered')) {
          domain.add(["state", "=", "open"]);
        }
        if (filter.contains('Attended')) {
          domain.add(["state", "=", "done"]);
        }
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain, 'limit': limit, 'offset': offset},
      });

      final res = response as List;
      final attendees = res
          .map((items) => AttendeeShortModel.fromJson(items))
          .toList();
      return attendees;
    } catch (_) {
      rethrow;
    }
  }

  /// Get attendees count
  Future<int> gettingAttendeesCount({
    String search = '',
    List<String> filter = const [],
  }) async {
    try {
      final List domain = [];
      if (search.isNotEmpty) {
        domain.addAll([
          '|',
          '|',
          ['name', 'ilike', search],
          ['email', 'ilike', search],
          ['company_name', 'ilike', search],
        ]);
      }
      if (filter.isNotEmpty) {
        if (filter.contains('Ongoing Events')) {
          domain.add(["event_id.is_ongoing", "=", true]);
        }
        if (filter.contains('Taken')) {
          domain.add([
            "state",
            "in",
            ["open", "done"],
          ]);
        }
        if (filter.contains('Unconfirmed')) {
          domain.add(["state", "=", "draft"]);
        }
        if (filter.contains('Registered')) {
          domain.add(["state", "=", "open"]);
        }
        if (filter.contains('Attended')) {
          domain.add(["state", "=", "done"]);
        }
      }
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return count as int;
    } catch (_) {
      rethrow;
    }
  }

  /// Marks a registration as attended — the same button Odoo shows, which is
  /// a different server method from Odoo 20 on (see [OdooCompat]).
  Future actionDone(int id) async {
    try {
      final compat = await OdooCompat.current();
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': compat.attendRegistrationMethod,
        'args': [id],
        'kwargs': {},
      });
    } catch (_) {
      rethrow;
    }
  }

  bool _isPdf(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  ///download the badge

  Future<File?> downloadBadge(int registrationId) async {
    try {
      const int maxRetry = 3;
      const timeout = Duration(minutes: 5);

      final session = await OdooSessionManager.getCurrentSession();
      final baseUrl = session!.serverUrl;
      final sessionId = session.sessionId;

      final url =
          "$baseUrl/report/pdf/event.action_report_event_registration_badge/$registrationId";

      http.Response? response;

      for (int attempt = 1; attempt <= maxRetry; attempt++) {
        try {
          response = await http
              .get(Uri.parse(url), headers: {'Cookie': 'session_id=$sessionId'})
              .timeout(timeout);

          if (response.statusCode == 200 && _isPdf(response.bodyBytes)) {
            break;
          }
        } catch (_) {
          if (attempt == maxRetry) rethrow;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }

      if (response == null ||
          response.statusCode != 200 ||
          !_isPdf(response.bodyBytes)) {
        throw Exception('Failed to download badge PDF');
      }

      final bytes = response.bodyBytes;

      final dir = await getApplicationDocumentsDirectory();

      final now = DateTime.now();
      final timestamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
          "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";

      final file = File("${dir.path}/badge_${registrationId}_$timestamp.pdf");
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future onChangeNew(int? eventId) async {
    try {
      final compat = await OdooCompat.current();

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'onchange',
        'args': [
          [],
          {},
          [],
          {
            'active': {},
            'state': {},
            'name': {},
            'email': {},
            'phone': {},
            'visitor_id': {
              'fields': {'display_name': {}},
            },
            'company_name': {},
            'event_id': {
              'fields': {'display_name': {}},
              'context': {'name_with_seats_availability': true},
            },
            if (compat.hasEventSlots)
              'event_slot_id': {
                'fields': {'display_name': {}},
                'context': {'name_with_seats_availability': true},
              },
            'event_ticket_id': {
              'fields': {'display_name': {}},
              'context': {'name_with_seats_availability': true},
            },
            'barcode': {},
            'partner_id': {
              'fields': {'display_name': {}},
            },
            'create_date': {},
            'date_closed': {},

            'utm_campaign_id': {
              'fields': {'display_name': {}},
            },
            'utm_medium_id': {
              'fields': {'display_name': {}},
            },
            'utm_source_id': {
              'fields': {'display_name': {}},
            },

            'registration_answer_ids': {
              'fields': {
                'event_id': {'fields': {}},
                'question_id': {
                  'fields': {'display_name': {}},
                },
                'question_type': {},
                'value_answer_id': {
                  'fields': {'display_name': {}},
                },
                'value_text_box': {},
              },
              'limit': 40,
            },
            if (compat.hasEventSlots) 'is_multi_slots': {},
            'display_name': {},
          },
        ],
        if (eventId != null)
          'kwargs': {
            'context': {
              'active_id': eventId,
              'active_ids': [eventId],
              'default_event_id': eventId,
            },
          },
      });
      final registration = EventRegistration.fromJson(result['value']);
      return registration;
    } catch (_) {
      rethrow;
    }
  }

  Future onchangeEventChanged({required int eventId}) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'event.registration',
      'method': 'onchange',
      'args': [
        [],
        {'event_id': eventId, 'event_slot_id': false, 'is_multi_slots': false},
        ['event_id'],
        {'event_id': {}, 'event_slot_id': {}, 'is_multi_slots': {}},
      ],
      'kwargs': {},
    });

    return result['value']?['is_multi_slots'] == true;
  }

  Future<List<FetchModel>> getTypeHeadSearchList({
    required String model,
    String? search,
    int limit = 5,
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
        'kwargs': {
          'domain': finalDomain,
          'limit': limit,
          // FetchModel only reads id and display_name. Reading every field
          // also pulls relations the user may not be allowed to see — a
          // visitor's page history (website.track) is restricted to website
          // designers, so the Visitor picker failed for event users.
          'fields': ['display_name'],
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  Future<List<FetchModel>> getTypeHeadSearchSlotList({
    required String model,
    String? search,
    int limit = 5,
    List domain = const [],
  }) async {
    try {
      final List finalDomain = List.from(domain);

      if (search != null && search.isNotEmpty) {
        finalDomain.add(['display_name', 'ilike', search]);
      }
      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': finalDomain,
          'limit': limit,
          // FetchModel only reads id and display_name. Reading every field
          // also pulls relations the user may not be allowed to see — a
          // visitor's page history (website.track) is restricted to website
          // designers, so the Visitor picker failed for event users.
          'fields': ['display_name'],
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  Future<List<EventQuestion>> getTypeHeadQuestionSearchList({
    required String model,
    String? search,
    int limit = 5,
    List domain = const [],
  }) async {
    try {
      final List finalDomain = List.from(domain);

      if (search != null && search.isNotEmpty) {
        finalDomain.add(['title', 'ilike', search]);
      }
      final response = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': finalDomain,
          'limit': limit,
          // FetchModel only reads id and display_name. Reading every field
          // also pulls relations the user may not be allowed to see — a
          // visitor's page history (website.track) is restricted to website
          // designers, so the Visitor picker failed for event users.
          'fields': ['display_name'],
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => EventQuestion.fromJson(item)).toList();

      return fetched;
    } catch (_) {
      rethrow;
    }
  }

  Future<int?> createAttendees({required Map<String, dynamic> vals}) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'create',
        'args': [vals],
        'kwargs': {},
      });
      return result;
    } catch (_) {
      rethrow;
    }
  }

  Future getSelectedAttendeeDetails(int id) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {},
      });

      final res = result[0];

      List<int> answerIds =
          (res['registration_answer_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [];

      List<RegistrationAnswer> answers = [];
      if (answerIds.isNotEmpty) {
        final answerResult = await OdooSessionManager.callKwWithCompany({
          'model': 'event.registration.answer',
          'method': 'read',
          'args': [answerIds],
          'kwargs': {
            'fields': [
              'question_id',
              'question_type',
              'value_answer_id',
              'value_text_box',
            ],
          },
        });
        answers = (answerResult as List)
            .map((e) => RegistrationAnswer.fromJson(e))
            .toList();
      }

      final selectedAttendee = RegistrationFullModel.fromJson(res);
      final fullModel = RegistrationFullModel(
        id: selectedAttendee.id,
        active: selectedAttendee.active,
        state: selectedAttendee.state,
        name: selectedAttendee.name,
        email: selectedAttendee.email,
        phone: selectedAttendee.phone,
        visitorId: selectedAttendee.visitorId,
        companyName: selectedAttendee.companyName,
        eventId: selectedAttendee.eventId,
        eventSlotId: selectedAttendee.eventSlotId,
        eventTicketId: selectedAttendee.eventTicketId,
        campaign: selectedAttendee.campaign,
        medium: selectedAttendee.medium,
        source: selectedAttendee.source,
        barcode: selectedAttendee.barcode,
        partnerId: selectedAttendee.partnerId,
        createDate: selectedAttendee.createDate,
        dateClosed: selectedAttendee.dateClosed,
        saleStatus: selectedAttendee.saleStatus,
        isMultiSlots: selectedAttendee.isMultiSlots,
        displayName: selectedAttendee.displayName,
        registrationAnswers: answers,
      );
      return fullModel;
    } catch (_) {
      rethrow;
    }
  }

  ///edit attendee
  Future<bool> editAttendee({
    required int attendeeId,
    required Map<String, dynamic> vals,
  }) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'write',
        'args': [
          [attendeeId],
          vals,
        ],
        'kwargs': {},
      });
      return result;
    } catch (_) {
      rethrow;
    }
  }
}
