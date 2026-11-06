import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';
import 'package:mobo_event/core/utils/odoo_version.dart';

void main() {
  group('OdooVersion.majorOf', () {
    test('reads the major out of every shape Odoo reports', () {
      expect(OdooVersion.majorOf(20), 20);
      expect(OdooVersion.majorOf('20'), 20);
      expect(OdooVersion.majorOf('20.0'), 20);
      expect(OdooVersion.majorOf('20.0+e'), 20);
      expect(OdooVersion.majorOf('saas~19.2'), 19);
      expect(OdooVersion.majorOf([20, 0, 0, 'final', 0, '']), 20);
      expect(OdooVersion.majorOf('29.0'), 29);
    });

    test('answers null for anything that carries no version', () {
      expect(OdooVersion.majorOf(null), isNull);
      expect(OdooVersion.majorOf(''), isNull);
      expect(OdooVersion.majorOf('null'), isNull);
      expect(OdooVersion.majorOf(false), isNull);
      expect(OdooVersion.majorOf([]), isNull);
    });

    test('isAtLeast is a range check, not an exact match', () {
      // The regression this guards: `version == '19'` is false on 20 and 29.
      expect(OdooVersion.isAtLeast('20.0', 19), isTrue);
      expect(OdooVersion.isAtLeast('29.0', 19), isTrue);
      expect(OdooVersion.isAtLeast('18.0', 19), isFalse);
      expect(OdooVersion.isAtLeast(null, 19), isFalse);
    });

    test('20 is inside the checked range and 29 is only past it', () {
      expect(OdooVersion.maxSupported, greaterThanOrEqualTo(20));
      expect(OdooCompat(20).isUntested, isFalse);
      expect(OdooCompat(29).isUntested, isTrue);
    });
  });

  group('OdooCompat feature gates', () {
    const expectations = <int, Map<String, Object>>{
      16: {
        'slots': false,
        'reusable': false,
        'questionField': 'event_id',
        'tracking': 'detailed_type',
        'attend': 'action_set_done',
        'mobile': true,
        'userPhone': false,
        'userAction': true,
      },
      17: {
        'slots': false,
        'reusable': false,
        'questionField': 'event_id',
        'tracking': 'detailed_type',
        'attend': 'action_set_done',
        'mobile': true,
        'userPhone': false,
        'userAction': true,
      },
      18: {
        'slots': false,
        'reusable': false,
        'questionField': 'event_id',
        'tracking': 'service_tracking',
        'attend': 'action_set_done',
        'mobile': true,
        'userPhone': false,
        'userAction': true,
      },
      19: {
        'slots': true,
        'reusable': true,
        'questionField': 'event_ids',
        'tracking': 'service_tracking',
        'attend': 'action_set_done',
        'mobile': false,
        'userPhone': true,
        'userAction': true,
      },
      20: {
        'slots': true,
        'reusable': true,
        'questionField': 'event_ids',
        'tracking': 'service_tracking',
        'attend': 'action_attend_event',
        'mobile': false,
        'userPhone': true,
        'userAction': false,
      },
      // Nothing is known about 29, so it must take the newest branch we have.
      29: {
        'slots': true,
        'reusable': true,
        'questionField': 'event_ids',
        'tracking': 'service_tracking',
        'attend': 'action_attend_event',
        'mobile': false,
        'userPhone': true,
        'userAction': false,
      },
    };

    expectations.forEach((major, want) {
      test('Odoo $major', () {
        final compat = OdooCompat(major);
        expect(compat.hasEventSlots, want['slots'], reason: 'hasEventSlots');
        expect(compat.hasReusableQuestions, want['reusable']);
        expect(compat.questionEventField, want['questionField']);
        expect(compat.eventProductTrackingField, want['tracking']);
        expect(compat.attendRegistrationMethod, want['attend']);
        expect(compat.hasMobileField, want['mobile']);
        expect(compat.userPhoneIsSelfWritable, want['userPhone']);
        expect(compat.userActionIsSelfWritable, want['userAction']);
        expect(compat.hasCancelledKanbanState, want['slots']);
        expect(compat.hasEventBoundaryMailTriggers, want['slots']);
      });
    });

    test('every release from 21 to 29 behaves like 20', () {
      final newest = OdooCompat(20);
      for (var major = 21; major <= 29; major++) {
        final compat = OdooCompat(major);
        expect(compat.hasEventSlots, newest.hasEventSlots, reason: '$major');
        expect(compat.questionEventField, newest.questionEventField);
        expect(compat.eventProductTrackingField, newest.eventProductTrackingField);
        expect(compat.attendRegistrationMethod, newest.attendRegistrationMethod);
        expect(compat.userSelfWritableFields, newest.userSelfWritableFields);
        expect(compat.hasCancelledKanbanState, newest.hasCancelledKanbanState);
        expect(
          compat.hasEventBoundaryMailTriggers,
          newest.hasEventBoundaryMailTriggers,
        );
      }
    });
  });

  group('OdooCompat.of', () {
    test('accepts the version strings a session actually stores', () {
      expect(OdooCompat.of('20').major, 20);
      expect(OdooCompat.of('20.0').major, 20);
      expect(OdooCompat.of('saas~19.2').major, 19);
      expect(OdooCompat.of(29).major, 29);
    });

    test('an unknown version opts out of newer behaviour', () {
      // HomeProvider.version is '' until the session has been read.
      for (final unknown in ['', null, 'null', false]) {
        final compat = OdooCompat.of(unknown);
        expect(compat.major, OdooVersion.fallbackMajor, reason: '$unknown');
        expect(compat.hasReusableQuestions, isFalse);
        expect(compat.hasCancelledKanbanState, isFalse);
      }
    });

    test('a 20 or 29 server keeps the features the old 19 check gated', () {
      // `version.contains('19')` used to hide all of these on 20 and 29.
      for (final version in ['20', '20.0', '29', '29.0']) {
        final compat = OdooCompat.of(version);
        expect(compat.hasReusableQuestions, isTrue, reason: version);
        expect(compat.hasCancelledKanbanState, isTrue, reason: version);
        expect(compat.hasEventBoundaryMailTriggers, isTrue, reason: version);
        expect(compat.hasEventSlots, isTrue, reason: version);
      }
    });
  });

  group('OdooCompat.userSelfWritableFields', () {
    test('keeps action_id through 19 and drops it on 20', () {
      expect(OdooCompat(19).userSelfWritableFields, contains('action_id'));
      expect(OdooCompat(20).userSelfWritableFields, isNot(contains('action_id')));
    });

    test('phone is self-writable from 19, company_id on every release', () {
      expect(OdooCompat(18).userSelfWritableFields, isNot(contains('phone')));
      expect(OdooCompat(19).userSelfWritableFields, contains('phone'));
      expect(OdooCompat(20).userSelfWritableFields, contains('phone'));
      for (final major in [16, 17, 18, 19, 20, 29]) {
        expect(OdooCompat(major).userSelfWritableFields, contains('company_id'));
      }
    });
  });
}
