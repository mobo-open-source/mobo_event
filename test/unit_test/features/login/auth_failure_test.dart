import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/utils/database_expiry.dart';
import 'package:mobo_event/features/login/utils/auth_failure.dart';

void main() {
  group('an expired database', () {
    const expired = DatabaseExpiredException();

    test('is classified by type, not by the text of its message', () {
      expect(classifyAuthFailure(expired), AuthFailure.databaseExpired);
    });

    test('maps to the expired message', () {
      expect(
        authFailureMessage(expired),
        'This database has expired. Please contact your administrator or '
        'Odoo to renew the subscription.',
      );
    });

    test('is not mislabelled as a wrong database', () {
      // The message contains "database", which the text matching below the
      // type test reads as an unusable server.
      expect(classifyAuthFailure(expired), isNot(AuthFailure.server));
      expect(authFailureMessage(expired), isNot(contains('access failed')));
      expect(
        authFailureMessage(expired),
        isNot(contains('verify the selected')),
      );
    });

    test('ignores the caller\'s fallback wording', () {
      expect(
        authFailureMessage(expired, fallback: 'Failed to switch account.'),
        DatabaseExpiredException.message,
      );
    });

    test('is not mistaken for the other auth failures', () {
      expect(
        classifyAuthFailure(expired),
        isNot(AuthFailure.twoFactorRequired),
      );
      expect(
        classifyAuthFailure(expired),
        isNot(AuthFailure.invalidCredentials),
      );
      expect(classifyAuthFailure(expired), isNot(AuthFailure.network));
    });
  });

  group('text matching still applies to everything else', () {
    test('a plain "invalid database" error is still a server failure', () {
      expect(
        classifyAuthFailure(Exception('invalid database')),
        AuthFailure.server,
      );
      expect(
        authFailureMessage(Exception('invalid database')),
        startsWith('Database access failed.'),
      );
    });

    test('wrong credentials are still wrong credentials', () {
      expect(
        classifyAuthFailure(Exception('Access Denied')),
        AuthFailure.invalidCredentials,
      );
    });
  });
}
