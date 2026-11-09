import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobo_event/core/utils/database_expiry.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

void main() {
  /// Noon UTC, so "a date with no time" (midnight) sits exactly twelve hours
  /// either side of it — the two sides of the rounding rule.
  final now = DateTime.utc(2026, 6, 15, 12);

  bool expired(Object? value) => DatabaseExpiry.hasExpired(value, now: now);

  group('DatabaseExpiredException', () {
    test('toString is the user-facing message, with no type prefix', () {
      expect(
        const DatabaseExpiredException().toString(),
        'This database has expired. Please contact your administrator or '
        'Odoo to renew the subscription.',
      );
      expect(
        const DatabaseExpiredException().toString(),
        DatabaseExpiredException.message,
      );
    });
  });

  group('DatabaseExpiry.hasExpired', () {
    test('a past date is expired', () {
      expect(expired('2026-06-01 00:00:00'), isTrue);
      expect(expired('2020-01-01 08:30:00'), isTrue);
    });

    test('a future date is not expired', () {
      expect(expired('2026-07-01 00:00:00'), isFalse);
      expect(expired('2999-12-31 23:59:59'), isFalse);
    });

    test('a date with no time is read as midnight UTC', () {
      expect(expired('2026-06-01'), isTrue);
      expect(expired('2026-07-01'), isFalse);
    });

    test('exactly now is expired', () {
      expect(expired('2026-06-15 12:00:00'), isTrue);
    });

    group('rounding — Math.round(daysLeft) <= 0', () {
      test('11h59m left rounds to zero days, so expired', () {
        expect(expired('2026-06-15 23:59:00'), isTrue);
      });

      test('exactly 12h left rounds to one day, so not expired', () {
        expect(expired('2026-06-16 00:00:00'), isFalse);
      });

      test('12h1s left is not expired either', () {
        expect(expired('2026-06-16 00:00:01'), isFalse);
      });

      test('12h past is expired', () {
        expect(expired('2026-06-15 00:00:00'), isTrue);
      });

      test('a day and a half left is not expired', () {
        expect(expired('2026-06-17 00:00:00'), isFalse);
      });
    });

    test('the ISO "T" separator is read the same as a space', () {
      expect(expired('2026-06-01T00:00:00'), isTrue);
      expect(expired('2026-07-01T00:00:00'), isFalse);
      expect(expired('2026-06-16T00:00:00'), isFalse);
      expect(expired('2026-06-15T23:59:00'), isTrue);
    });

    test('a tail after the seconds is ignored', () {
      expect(expired('2026-06-01 00:00:00.123456'), isTrue);
      expect(expired('2026-07-01 00:00:00.999'), isFalse);
      expect(expired('2026-06-01T00:00:00Z'), isTrue);
      expect(expired('2026-07-01T00:00:00+00:00'), isFalse);
    });

    test('anything that is not an expiry date is not expired', () {
      expect(expired(null), isFalse);
      expect(expired(false), isFalse);
      expect(expired(true), isFalse);
      expect(expired(''), isFalse);
      expect(expired('never'), isFalse);
      expect(expired('false'), isFalse);
      expect(expired(20200101), isFalse);
      expect(expired(0), isFalse);
      expect(expired(<String>['2020-01-01']), isFalse);
    });

    test('a date that does not exist is not read as one that rolled over', () {
      expect(expired('2020-13-01'), isFalse);
      expect(expired('2020-02-30'), isFalse);
      expect(expired('2020-01-45'), isFalse);
    });

    test('a partial date is not an expiry date', () {
      expect(expired('2020-01'), isFalse);
      expect(expired('01-01-2020'), isFalse);
    });

    test('`now` is compared as the same instant whatever its zone', () {
      final local = now.toLocal();
      expect(
        DatabaseExpiry.hasExpired('2026-06-15 23:59:00', now: local),
        isTrue,
      );
      expect(
        DatabaseExpiry.hasExpired('2026-06-16 00:00:00', now: local),
        isFalse,
      );
    });

    test('with no `now` it uses the clock', () {
      expect(DatabaseExpiry.hasExpired('2000-01-01'), isTrue);
      expect(DatabaseExpiry.hasExpired('2999-01-01'), isFalse);
    });
  });

  group('DatabaseExpiry.check', () {
    late int sessionInfoReads;
    late int parameterReads;

    setUp(() {
      sessionInfoReads = 0;
      parameterReads = 0;
    });

    Future<bool> run({
      required Future<dynamic> Function() sessionInfo,
      Future<dynamic> Function()? parameter,
    }) {
      return DatabaseExpiry.check(
        readSessionInfo: () {
          sessionInfoReads++;
          return sessionInfo();
        },
        readParameter: () {
          parameterReads++;
          return (parameter ?? () async => null)();
        },
      );
    }

    test('expired when session info carries a past date', () async {
      final result = await run(
        sessionInfo: () async => {'expiration_date': '2020-01-01 00:00:00'},
      );

      expect(result, isTrue);
      expect(parameterReads, 0);
    });

    test('valid when session info carries a future date', () async {
      final result = await run(
        sessionInfo: () async => {'expiration_date': '2999-01-01 00:00:00'},
      );

      expect(result, isFalse);
      expect(parameterReads, 0);
    });

    test('a missing key (Community) is not expired, and the parameter is '
        'never read', () async {
      final result = await run(
        sessionInfo: () async => {'uid': 2, 'db': 'demo'},
        parameter: () async => '2020-01-01 00:00:00',
      );

      expect(result, isFalse);
      expect(parameterReads, 0);
    });

    test(
      'a false value is not expired, and the parameter is never read',
      () async {
        final result = await run(
          sessionInfo: () async => {'expiration_date': false},
          parameter: () async => '2020-01-01 00:00:00',
        );

        expect(result, isFalse);
        expect(parameterReads, 0);
      },
    );

    test('an answer that is not a map is not expired, and the parameter is '
        'never read', () async {
      for (final odd in <dynamic>[
        null,
        'oops',
        42,
        <int>[1],
      ]) {
        final result = await run(
          sessionInfo: () async => odd,
          parameter: () async => '2020-01-01 00:00:00',
        );

        expect(result, isFalse, reason: '$odd');
      }
      expect(parameterReads, 0);
    });

    test(
      'a failed session-info call falls back to the parameter: expired',
      () async {
        final result = await run(
          sessionInfo: () async => throw Exception('boom'),
          parameter: () async => '2020-01-01 00:00:00',
        );

        expect(result, isTrue);
        expect(sessionInfoReads, 1);
        expect(parameterReads, 1);
      },
    );

    test(
      'a failed session-info call falls back to the parameter: valid',
      () async {
        final result = await run(
          sessionInfo: () async => throw Exception('boom'),
          parameter: () async => '2999-01-01 00:00:00',
        );

        expect(result, isFalse);
        expect(parameterReads, 1);
      },
    );

    test(
      'a failed session-info call and an unset parameter is not expired',
      () async {
        final result = await run(
          sessionInfo: () async => throw Exception('boom'),
          parameter: () async => false,
        );

        expect(result, isFalse);
      },
    );

    test('everything failing is not expired', () async {
      final result = await run(
        sessionInfo: () async => throw Exception('boom'),
        parameter: () async => throw Exception('also boom'),
      );

      expect(result, isFalse);
      expect(sessionInfoReads, 1);
      expect(parameterReads, 1);
    });

    test('a read that throws synchronously is a failure too', () async {
      final result = await DatabaseExpiry.check(
        readSessionInfo: () => throw StateError('sync'),
        readParameter: () => throw StateError('sync'),
      );

      expect(result, isFalse);
    });
  });

  group('DatabaseExpiry.isExpired', () {
    http.Response jsonResponse(Object body) => http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': body}),
      200,
      headers: {'content-type': 'application/json'},
    );

    OdooClient clientAnswering(http.Response Function(http.Request) answer) {
      return OdooClient(
        'https://odoo.test',
        httpClient: MockClient((request) async => answer(request)),
      );
    }

    test('reads the expiry from get_session_info', () async {
      final paths = <String>[];
      final client = clientAnswering((request) {
        paths.add(request.url.path);
        return jsonResponse({'expiration_date': '2020-01-01 00:00:00'});
      });

      expect(await DatabaseExpiry.isExpired(client), isTrue);
      expect(paths, ['/web/session/get_session_info']);
    });

    test('a valid database is not expired', () async {
      final client = clientAnswering(
        (_) => jsonResponse({'expiration_date': '2999-01-01 00:00:00'}),
      );

      expect(await DatabaseExpiry.isExpired(client), isFalse);
    });

    test(
      'a failing server lets the user in, after trying the parameter',
      () async {
        final paths = <String>[];
        final client = clientAnswering((request) {
          paths.add(request.url.path);
          return http.Response('boom', 500);
        });

        expect(await DatabaseExpiry.isExpired(client), isFalse);
        expect(paths, [
          '/web/session/get_session_info',
          '/web/dataset/call_kw',
        ]);
      },
    );

    test(
      'falls back to the parameter when session info cannot be read',
      () async {
        final client = clientAnswering((request) {
          if (request.url.path == '/web/dataset/call_kw') {
            final params = jsonDecode(request.body)['params'] as Map;
            expect(params['model'], 'ir.config_parameter');
            expect(params['method'], 'get_param');
            expect(params['args'], ['database.expiration_date']);
            return jsonResponse('2020-01-01 00:00:00');
          }
          return http.Response('not json', 200);
        });

        expect(await DatabaseExpiry.isExpired(client), isTrue);
      },
    );

    testWidgets('gives up after the probe timeout and lets the user in', (
      tester,
    ) async {
      final client = OdooClient(
        'https://odoo.test',
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );

      bool? result;
      final pending = DatabaseExpiry.isExpired(client).then((v) => result = v);

      await tester.pump(
        DatabaseExpiry.probeTimeout - const Duration(seconds: 1),
      );
      expect(result, isNull, reason: 'still waiting inside the timeout');

      await tester.pump(const Duration(seconds: 2));
      await pending;
      expect(result, isFalse);
    });
  });
}
