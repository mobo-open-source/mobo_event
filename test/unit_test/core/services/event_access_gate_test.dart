import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/exceptions/app_exceptions.dart';
import 'package:mobo_event/core/services/event_access_gate.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';

/// A fake server: answers each `callKw` from [handlers] by method name, and
/// records the order the methods were asked in.
class _FakeServer {
  _FakeServer(this.handlers);

  final Map<String, dynamic Function(Map<String, dynamic> params)> handlers;
  final List<String> asked = [];
  final List<Map<String, dynamic>> payloads = [];

  Future<dynamic> call(Map<String, dynamic> params) async {
    final method = params['method'] as String;
    asked.add(method);
    payloads.add(params);
    final handler = handlers[method];
    if (handler == null) throw StateError('no such method: $method');
    return handler(params);
  }
}

Exception _missingMethod(String name) =>
    Exception("AttributeError: 'event.event' has no attribute '$name'");

Exception _accessError() => Exception(
  "{name: odoo.exceptions.AccessError, message: You are not allowed to "
  "access 'Event' (event.event) records.}",
);

void main() {
  group('evaluateEventAccess — the "Events" role on the user form', () {
    // `has_group` answers per-record from 18 and model-level before it.
    dynamic Function(Map<String, dynamic>) hasGroup(bool answer) =>
        (params) => answer;

    for (final version in ['17.0', '18.0', '19.0', '20.0', '29.0']) {
      test('Odoo $version: Events left empty is refused even though the server '
          'lets any employee read events (website_event installed)', () async {
        final server = _FakeServer({
          'has_group': hasGroup(false),
          // What `website_event` grants base.group_user: read on event.event.
          'has_access': (_) => true,
          'check_access_rights': (_) => true,
        });

        expect(
          await evaluateEventAccess(server.call, userId: 7, version: version),
          isFalse,
        );
        // Refused on the role alone — the model is never even asked about.
        expect(server.asked, ['has_group']);
      });

      test('Odoo $version: a user holding an Events role is allowed', () async {
        final server = _FakeServer({
          'has_group': hasGroup(true),
          'has_access': (_) => true,
          'check_access_rights': (_) => true,
        });

        expect(
          await evaluateEventAccess(server.call, userId: 7, version: version),
          isTrue,
        );
      });
    }

    test('a role does not override an ACL that withholds the model', () async {
      final server = _FakeServer({
        'has_group': hasGroup(true),
        'has_access': (_) => false,
      });

      expect(
        await evaluateEventAccess(server.call, userId: 7, version: '19.0'),
        isFalse,
      );
      expect(server.asked, ['has_group', 'has_access']);
    });

    test('the role is asked the way each release expects', () async {
      final v17 = _FakeServer({'has_group': hasGroup(true)});
      await holdsEventRole(v17.call, userId: 7, version: '17.0');
      expect(v17.payloads.single['model'], 'res.users');
      expect(v17.payloads.single['args'], ['event.group_event_registration_desk']);

      for (final version in ['18.0', '19.0', '20.0']) {
        final server = _FakeServer({'has_group': hasGroup(true)});
        await holdsEventRole(server.call, userId: 7, version: version);
        expect(server.payloads.single['args'], [
          [7],
          'event.group_event_registration_desk',
        ]);
      }
    });

    test('the lowest Event group is the test, since the others imply it', () {
      expect(eventRoleGroup, 'event.group_event_registration_desk');
    });

    test('a mis-detected release falls back to the other has_group shape', () async {
      // A 17 server reported as 18: the per-record shape blows up, the
      // model-level one answers.
      final server = _FakeServer({
        'has_group': (params) {
          final args = params['args'] as List;
          if (args.first is List) throw Exception('TypeError: too many args');
          return false;
        },
      });

      expect(await holdsEventRole(server.call, userId: 7, version: '18.0'), isFalse);
      expect(server.asked, ['has_group', 'has_group']);
    });

    test('an unanswerable role check does not lock anyone out by itself', () async {
      final server = _FakeServer({
        'has_group': (_) => throw Exception('SocketException: timed out'),
        'has_access': (_) => true,
      });

      expect(
        await evaluateEventAccess(server.call, userId: 7, version: '19.0'),
        isTrue,
      );
    });

    test('an unanswerable role check still yields to a definite ACL refusal', () async {
      final server = _FakeServer({
        'has_group': (_) => throw Exception('SocketException: timed out'),
        'has_access': (_) => false,
      });

      expect(
        await evaluateEventAccess(server.call, userId: 7, version: '19.0'),
        isFalse,
      );
    });

    test('without a user id only the model check can run', () async {
      final server = _FakeServer({'has_access': (_) => true});

      expect(await evaluateEventAccess(server.call, version: '19.0'), isTrue);
      expect(server.asked, ['has_access']);
    });
  });

  group('canReadEvents — the ORM permission question per release', () {
    test('Odoo 17 asks check_access_rights and never has_access', () async {
      final server = _FakeServer({'check_access_rights': (_) => true});

      expect(await canReadEvents(server.call, version: '17.0'), isTrue);
      expect(server.asked, ['check_access_rights']);

      final payload = server.payloads.single;
      expect(payload['model'], 'event.event');
      expect(payload['args'], ['read']);
      expect(payload['kwargs'], {'raise_exception': false});
    });

    test('Odoo 17 denies a user with no Event role', () async {
      final server = _FakeServer({'check_access_rights': (_) => false});

      expect(await canReadEvents(server.call, version: '17.0'), isFalse);
    });

    for (final version in ['18.0', '19.0', '20.0', '29.0', 'saas~19.2']) {
      test('Odoo $version asks has_access on the model in general', () async {
        final server = _FakeServer({'has_access': (_) => true});

        expect(await canReadEvents(server.call, version: version), isTrue);
        expect(server.asked, ['has_access']);

        final payload = server.payloads.single;
        expect(payload['model'], 'event.event');
        // No record ids: the question is about the model, not a record.
        expect(payload['args'], [<int>[], 'read']);
      });

      test('Odoo $version denies a user with no Event role', () async {
        final server = _FakeServer({'has_access': (_) => false});

        expect(await canReadEvents(server.call, version: version), isFalse);
        // A definite answer stops the search — no second opinion is sought.
        expect(server.asked, ['has_access']);
      });
    }

    test('Odoo 20 needs no check_access_rights, which it removed', () async {
      final server = _FakeServer({
        'has_access': (_) => false,
        'check_access_rights': (_) => throw _missingMethod('check_access_rights'),
      });

      expect(await canReadEvents(server.call, version: '20.0'), isFalse);
      expect(server.asked, ['has_access']);
    });

    test('an unknown version asks has_access first', () async {
      final server = _FakeServer({'has_access': (_) => false});

      expect(await canReadEvents(server.call), isFalse);
      expect(server.asked, ['has_access']);
    });
  });

  group('canReadEvents — fallbacks', () {
    test('a mis-detected 17 server falls back to check_access_rights', () async {
      final server = _FakeServer({
        'has_access': (_) => throw _missingMethod('has_access'),
        'check_access_rights': (_) => false,
      });

      expect(await canReadEvents(server.call, version: '18.0'), isFalse);
      expect(server.asked, ['has_access', 'check_access_rights']);
    });

    test('a mis-detected 20 server falls back to has_access', () async {
      final server = _FakeServer({
        'check_access_rights': (_) => throw _missingMethod('check_access_rights'),
        'has_access': (_) => false,
      });

      expect(await canReadEvents(server.call, version: '17.0'), isFalse);
      expect(server.asked, ['check_access_rights', 'has_access']);
    });

    test('a non-boolean answer is not trusted', () async {
      final server = _FakeServer({
        'has_access': (_) => null,
        'check_access_rights': (_) => 'nope',
        'search_count': (_) => 0,
      });

      // Falls through both APIs to the probe, which can read: allowed.
      expect(await canReadEvents(server.call, version: '19.0'), isTrue);
      expect(server.asked, ['has_access', 'check_access_rights', 'search_count']);
    });

    test('the probe denies only on an explicit access error', () async {
      final server = _FakeServer({
        'has_access': (_) => throw _missingMethod('has_access'),
        'check_access_rights': (_) => throw _missingMethod('check_access_rights'),
        'search_count': (_) => throw _accessError(),
      });

      expect(await canReadEvents(server.call, version: '19.0'), isFalse);
    });

    test('an unreachable server is unanswered, not a denial', () async {
      final server = _FakeServer({
        'has_access': (_) => throw Exception('SocketException: timed out'),
        'check_access_rights': (_) => throw Exception('SocketException'),
        'search_count': (_) => throw Exception('SocketException: timed out'),
      });

      expect(await canReadEvents(server.call, version: '19.0'), isNull);
    });
  });

  group('isAccessErrorText', () {
    test('recognises the server refusing access', () {
      expect(isAccessErrorText('odoo.exceptions.AccessError'), isTrue);
      expect(isAccessErrorText('Access Error'), isTrue);
      expect(
        isAccessErrorText("You are not allowed to access 'Event' records"),
        isTrue,
      );
      expect(isAccessErrorText('You do not have access to this'), isTrue);
    });

    test('does not mistake other failures for a refusal', () {
      expect(isAccessErrorText('SocketException: connection refused'), isFalse);
      expect(isAccessErrorText('Internal Server Error'), isFalse);
      expect(isAccessErrorText('FormatException: <html>'), isFalse);
    });
  });

  group('AccessDenial wording', () {
    test('each reason names itself', () {
      expect(
        AccessDenial.values.map((d) => d.title).toSet().length,
        AccessDenial.values.length,
      );
      expect(AccessDenial.noEventAccess.title, contains('No Event Access'));
      expect(AccessDenial.portalUser.title, contains('Portal User'));
    });

    test('the portal wording is the same one the login error uses', () {
      expect(
        AccessDenial.portalUser.message,
        PortalUserException.portalUserMessage,
      );
    });

    test('the no-access message names the Events role to ask for', () {
      final message = AccessDenial.noEventAccess.message;
      expect(message, contains('Events role'));
      expect(message, contains('Registration Desk'));
      expect(message, contains('Administrator'));
      expect(message, isNot(contains('Portal')));
    });
  });

  group('OdooCompat access gates', () {
    test('are off through 17 and on from 18, including 20 and beyond', () {
      for (final gate in <bool Function(OdooCompat)>[
        (c) => c.hasHasAccess,
        (c) => c.hasGroupPerRecord,
      ]) {
        expect(gate(OdooCompat(16)), isFalse);
        expect(gate(OdooCompat(17)), isFalse);
        expect(gate(OdooCompat(18)), isTrue);
        expect(gate(OdooCompat(19)), isTrue);
        expect(gate(OdooCompat(20)), isTrue);
        expect(gate(OdooCompat(29)), isTrue);
      }
    });
  });
}
