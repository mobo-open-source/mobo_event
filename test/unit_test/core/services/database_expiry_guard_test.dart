import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/database_expiry_guard.dart';

void main() {
  late int asked;
  late int signedOut;
  late DateTime clock;

  /// Wires the guard's hooks to counters. [expired] answers the check, and
  /// may throw to stand in for a probe that failed.
  void wire({
    bool signedIn = true,
    Future<bool> Function()? expired,
    Future<void> Function()? signOut,
  }) {
    DatabaseExpiryGuard.isSignedIn = () => signedIn;
    DatabaseExpiryGuard.now = () => clock;
    DatabaseExpiryGuard.checkExpired = () {
      asked++;
      return (expired ?? () async => false)();
    };
    DatabaseExpiryGuard.signOut = () {
      signedOut++;
      return (signOut ?? () async {})();
    };
  }

  setUp(() {
    asked = 0;
    signedOut = 0;
    clock = DateTime.utc(2026, 6, 15, 12);
    DatabaseExpiryGuard.reset();
  });

  tearDown(DatabaseExpiryGuard.reset);

  test('signs out when the database has expired', () async {
    wire(expired: () async => true);

    await DatabaseExpiryGuard.onAppResumed();

    expect(asked, 1);
    expect(signedOut, 1);
  });

  test('stays signed in when the database is valid', () async {
    wire(expired: () async => false);

    await DatabaseExpiryGuard.onAppResumed();

    expect(asked, 1);
    expect(signedOut, 0);
  });

  test('stays signed in when the check throws — fail open', () async {
    wire(expired: () async => throw Exception('offline'));

    await DatabaseExpiryGuard.onAppResumed();

    expect(asked, 1);
    expect(signedOut, 0);
  });

  test('a failed check can be followed by another once the interval has '
      'passed, and a later success is acted on', () async {
    var fail = true;
    wire(
      expired: () async {
        if (fail) throw Exception('offline');
        return true;
      },
    );

    await DatabaseExpiryGuard.onAppResumed();
    expect(signedOut, 0);

    fail = false;
    clock = clock.add(DatabaseExpiryGuard.minInterval);
    await DatabaseExpiryGuard.onAppResumed();

    expect(asked, 2);
    expect(signedOut, 1);
  });

  test('does nothing when nobody is signed in', () async {
    wire(signedIn: false, expired: () async => true);

    await DatabaseExpiryGuard.onAppResumed();

    expect(asked, 0);
    expect(signedOut, 0);
  });

  group('the 30 second throttle', () {
    test('a second call within 30 s does not ask again', () async {
      wire();

      await DatabaseExpiryGuard.onAppResumed();
      clock = clock.add(const Duration(seconds: 29));
      await DatabaseExpiryGuard.onAppResumed();

      expect(asked, 1);
    });

    test('a call at 30 s asks again', () async {
      wire();

      await DatabaseExpiryGuard.onAppResumed();
      clock = clock.add(const Duration(seconds: 30));
      await DatabaseExpiryGuard.onAppResumed();

      expect(asked, 2);
    });

    test('a throttled call does not sign out either', () async {
      var expired = false;
      wire(expired: () async => expired);

      await DatabaseExpiryGuard.onAppResumed();
      expired = true;
      clock = clock.add(const Duration(seconds: 10));
      await DatabaseExpiryGuard.onAppResumed();

      expect(signedOut, 0);
    });

    test('ignoreRecentCheck bypasses it', () async {
      var expired = false;
      wire(expired: () async => expired);

      await DatabaseExpiryGuard.onAppResumed();
      expired = true;
      clock = clock.add(const Duration(seconds: 1));
      await DatabaseExpiryGuard.onAppResumed(ignoreRecentCheck: true);

      expect(asked, 2);
      expect(signedOut, 1);
    });

    test('a failed check still counts as a check', () async {
      wire(expired: () async => throw Exception('offline'));

      await DatabaseExpiryGuard.onAppResumed();
      clock = clock.add(const Duration(seconds: 5));
      await DatabaseExpiryGuard.onAppResumed();

      expect(asked, 1);
    });

    test(
      'signing out clears it, so the next account is checked at once',
      () async {
        wire(expired: () async => true);

        await DatabaseExpiryGuard.onAppResumed();
        clock = clock.add(const Duration(seconds: 1));
        await DatabaseExpiryGuard.onAppResumed();

        expect(asked, 2);
      },
    );
  });

  group('re-entrancy', () {
    test('a call made while one is running is ignored', () async {
      final answer = Completer<bool>();
      wire(expired: () => answer.future);

      final first = DatabaseExpiryGuard.onAppResumed();
      await Future<void>.delayed(Duration.zero);

      // Even with the throttle bypassed, there is still only one in flight.
      await DatabaseExpiryGuard.onAppResumed(ignoreRecentCheck: true);
      expect(asked, 1);

      answer.complete(true);
      await first;

      expect(asked, 1);
      expect(signedOut, 1);
    });

    test('the guard is free again once a run has finished', () async {
      wire(expired: () async => throw Exception('offline'));

      await DatabaseExpiryGuard.onAppResumed();
      await DatabaseExpiryGuard.onAppResumed(ignoreRecentCheck: true);

      expect(asked, 2);
    });
  });

  test('a sign-out that throws does not leave the guard stuck', () async {
    wire(
      expired: () async => true,
      signOut: () async => throw Exception('prefs unavailable'),
    );

    await DatabaseExpiryGuard.onAppResumed();
    await DatabaseExpiryGuard.onAppResumed(ignoreRecentCheck: true);

    expect(asked, 2);
    expect(signedOut, 2);
  });
}
