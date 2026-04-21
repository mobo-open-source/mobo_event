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
import '../../event/model/fetch_model.dart';

class RegistrationServices {
  Future addAttendeesByQr(String qrCode) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'register_attendee',
        'args': [],
        'kwargs': {'barcode': qrCode, 'event_id': false},
      });

      final attendee = AttendeeModel.fromJson(response);

      return attendee;
    } catch (e) {
      rethrow;
    }
  }

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

      return AttendeeModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }

  Future actionDone(int id) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.registration',
        'method': 'action_set_done',
        'args': [id],
        'kwargs': {},
      });
    } catch (e) {
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
        } catch (e) {
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
    } catch (e) {
      return null;
    }
  }

  Future onChangeNew(int? eventId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();

      final version = session!.odooSession.serverVersion;

      String odooVersion = version;

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
            if (odooVersion == '19')
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
            if (odooVersion == '19') 'is_multi_slots': {},
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
    } catch (e) {
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
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
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
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => FetchModel.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
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
          'context': {'is_registration_desk_view': true},
        },
      });

      final res = response as List;

      final fetched = res.map((item) => EventQuestion.fromJson(item)).toList();

      return fetched;
    } catch (e, st) {
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
    } catch (e) {
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
    } catch (e) {
      rethrow;
    }
  }

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
    } catch (e) {
      rethrow;
    }
  }
}
