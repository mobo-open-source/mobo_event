import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';

/// What each Events role may do to each model the app mutates, transcribed from
/// Odoo's own ACLs (`event/security/ir.model.access.csv` on 17–19,
/// `ir.access.csv` on 20; `mail.activity` is full CRUD for every employee).
/// `c` create, `w` write, `u` unlink — read is not asked.
const _desk = {
  EventModels.event: '',
  EventModels.stage: '',
  EventModels.ticket: '',
  EventModels.question: '',
  EventModels.questionAnswer: 'w',
  EventModels.mail: '',
  EventModels.registration: 'cw',
  EventModels.registrationAnswer: 'cwu',
  EventModels.slot: '',
  EventModels.activity: 'cwu',
};

const _user = {
  EventModels.event: 'cw',
  EventModels.stage: '',
  EventModels.ticket: 'cwu',
  EventModels.question: 'cwu',
  EventModels.questionAnswer: 'cwu',
  EventModels.mail: 'cwu',
  EventModels.registration: 'cw',
  EventModels.registrationAnswer: 'cwu',
  EventModels.slot: 'cwu',
  EventModels.activity: 'cwu',
};

const _administrator = {
  EventModels.event: 'cwu',
  EventModels.stage: 'cwu',
  EventModels.ticket: 'cwu',
  EventModels.question: 'cwu',
  EventModels.questionAnswer: 'cwu',
  EventModels.mail: 'cwu',
  EventModels.registration: 'cwu',
  EventModels.registrationAnswer: 'cwu',
  EventModels.slot: 'cwu',
  EventModels.activity: 'cwu',
};

/// A server that answers the ORM permission API the way [version] does, from
/// a role table.
class _Server {
  _Server(this.role, this.version);

  final Map<String, String> role;
  final int version;
  final List<String> asked = [];

  Future<dynamic> call(Map<String, dynamic> params) async {
    final method = params['method'] as String;
    final model = params['model'] as String;
    asked.add('$model:$method');

    late final String op;
    if (method == 'has_access') {
      if (version < 18) throw Exception("no attribute 'has_access'");
      op = (params['args'] as List)[1] as String;
    } else if (method == 'check_access_rights') {
      if (version >= 20) throw Exception("no attribute 'check_access_rights'");
      op = (params['args'] as List)[0] as String;
    } else {
      throw StateError('unexpected $method');
    }

    // Slots do not exist before Odoo 19.
    if (model == EventModels.slot && version < 19) {
      throw Exception("KeyError: 'event.slot'");
    }

    final letters = role[model] ?? '';
    return switch (op) {
      'create' => letters.contains('c'),
      'write' => letters.contains('w'),
      'unlink' => letters.contains('u'),
      _ => true,
    };
  }
}

Future<AccessRights> _loaded(
  Map<String, String> role,
  int version, {
  int userId = 7,
}) async {
  final server = _Server(role, version);
  final rights = AccessRights(
    call: server.call,
    version: () async => '$version.0',
    userId: userId,
  );
  await rights.load();
  return rights;
}

void main() {
  for (final version in [17, 18, 19, 20]) {
    group('Odoo $version', () {
      test('Registration Desk: registrations only', () async {
        final r = await _loaded(_desk, version);

        // Events, stages, tickets, questions, communication: read-only.
        expect(r.canCreateEvent, isFalse);
        expect(r.canEditEvent, isFalse);
        expect(r.canMoveEvent, isFalse);
        expect(r.canManageStages, isFalse);
        expect(r.canAddTicket, isFalse);
        expect(r.canEditTicket, isFalse);
        expect(r.canDeleteTicket, isFalse);
        expect(r.canLinkQuestion, isFalse);
        expect(r.canCreateQuestion, isFalse);
        expect(r.canRemoveQuestion, isFalse);
        expect(r.canEditQuestion, isFalse);
        expect(r.canAddScheduler, isFalse);
        expect(r.canEditScheduler, isFalse);
        expect(r.canDeleteScheduler, isFalse);
        expect(r.canEditDocumentation, isFalse);
        expect(r.canScheduleActivity, isFalse);

        // Registrations: create, edit and mark attended — never delete.
        expect(r.canCreateAttendee, isTrue);
        expect(r.canEditAttendee, isTrue);
        expect(r.canMarkAttended, isTrue);
        expect(r.canDelete(EventModels.registration), isFalse);
      });

      test('User: builds events, but does not manage stages', () async {
        final r = await _loaded(_user, version);

        expect(r.canCreateEvent, isTrue);
        expect(r.canEditEvent, isTrue);
        expect(r.canMoveEvent, isTrue);
        expect(r.canAddTicket, isTrue);
        expect(r.canEditTicket, isTrue);
        expect(r.canDeleteTicket, isTrue);
        expect(r.canLinkQuestion, isTrue);
        expect(r.canCreateQuestion, isTrue);
        expect(r.canEditQuestion, isTrue);
        expect(r.canAddScheduler, isTrue);
        expect(r.canEditScheduler, isTrue);
        expect(r.canDeleteScheduler, isTrue);
        expect(r.canEditDocumentation, isTrue);
        expect(r.canScheduleActivity, isTrue);
        expect(r.canCreateAttendee, isTrue);

        // Stages are Administrator-only.
        expect(r.canAddStage, isFalse);
        expect(r.canRenameStage, isFalse);
        expect(r.canReorderStages, isFalse);
        expect(r.canDeleteStage, isFalse);
        expect(r.canManageStages, isFalse);
      });

      test('Administrator: everything', () async {
        final r = await _loaded(_administrator, version);

        expect(r.canAddStage, isTrue);
        expect(r.canRenameStage, isTrue);
        expect(r.canReorderStages, isTrue);
        expect(r.canDeleteStage, isTrue);
        expect(r.canManageStages, isTrue);
        expect(r.canCreateEvent, isTrue);
        expect(r.canEditEvent, isTrue);
        expect(r.canMarkAttended, isTrue);
        expect(r.canDelete(EventModels.event), isTrue);
      });
    });
  }

  group('questions follow the release', () {
    test('Odoo 19 offers Add when the user can link or create', () async {
      final desk = await _loaded(_desk, 19);
      final user = await _loaded(_user, 19);

      expect(desk.canAddQuestion(const OdooCompat(19)), isFalse);
      expect(user.canAddQuestion(const OdooCompat(19)), isTrue);
    });

    test(
      'Odoo 17/18 can only create, so linking alone is not enough',
      () async {
        // Can write the event (so could link) but not create questions.
        final linkOnly = <String, String>{..._user, EventModels.question: ''};
        final r = await _loaded(linkOnly, 18);

        expect(r.canLinkQuestion, isTrue);
        expect(r.canAddQuestion(const OdooCompat(18)), isFalse);
        expect(r.canAddQuestion(const OdooCompat(19)), isTrue);
      },
    );
  });

  group('compound rules', () {
    test(
      'editing a ticket needs the event write as well as the ticket',
      () async {
        final ticketOnly = <String, String>{..._user, EventModels.event: ''};
        final r = await _loaded(ticketOnly, 19);

        expect(r.canWrite(EventModels.ticket), isTrue);
        expect(r.canEditTicket, isFalse);
      },
    );

    test('a scheduler needs the event write as well as event.mail', () async {
      final mailOnly = <String, String>{..._user, EventModels.event: ''};
      final r = await _loaded(mailOnly, 19);

      expect(r.canAddScheduler, isFalse);
      expect(r.canEditScheduler, isFalse);
      expect(r.canDeleteScheduler, isTrue); // a direct unlink on event.mail
    });

    test('editing a question also needs to recreate its answers', () async {
      final noAnswerDelete = <String, String>{
        ..._user,
        EventModels.questionAnswer: 'cw',
      };
      final r = await _loaded(noAnswerDelete, 19);

      expect(r.canWrite(EventModels.question), isTrue);
      expect(r.canEditQuestion, isFalse);
    });

    test('scheduling an activity needs the event write', () async {
      final activityOnly = <String, String>{..._user, EventModels.event: ''};
      final r = await _loaded(activityOnly, 19);

      expect(r.canScheduleActivity, isFalse);
    });
  });

  group('activities are decided per record', () {
    test(
      'a desk user can change their own activity, not someone else\'s',
      () async {
        final r = await _loaded(_desk, 19, userId: 7);

        expect(r.canChangeActivity(assigneeId: 7), isTrue);
        expect(r.canDeleteActivity(assigneeId: 7), isTrue);
        expect(r.canChangeActivity(assigneeId: 9), isFalse);
        expect(r.canDeleteActivity(assigneeId: 9), isFalse);
        expect(r.canChangeActivity(), isFalse);
      },
    );

    test('a user who can write the event can change anyone\'s', () async {
      final r = await _loaded(_user, 19, userId: 7);

      expect(r.canChangeActivity(assigneeId: 9), isTrue);
      expect(r.canDeleteActivity(assigneeId: 9), isTrue);
    });

    test(
      'no activity access at all means no change, even on your own',
      () async {
        final none = <String, String>{..._desk, EventModels.activity: ''};
        final r = await _loaded(none, 19, userId: 7);

        expect(r.canChangeActivity(assigneeId: 7), isFalse);
        expect(r.canDeleteActivity(assigneeId: 7), isFalse);
      },
    );
  });

  group('what is asked, and when', () {
    test('slots are not asked before Odoo 19', () async {
      final server = _Server(_user, 18);
      final r = AccessRights(call: server.call, version: () async => '18.0');
      await r.load();

      expect(
        server.asked.where((q) => q.startsWith(EventModels.slot)),
        isEmpty,
      );
    });

    test('slots are asked from Odoo 19', () async {
      final server = _Server(_user, 19);
      final r = AccessRights(call: server.call, version: () async => '19.0');
      await r.load();

      expect(
        server.asked.where((q) => q.startsWith(EventModels.slot)),
        isNotEmpty,
      );
    });

    test('17 asks check_access_rights and 20 only has_access', () async {
      final v17 = _Server(_user, 17);
      await AccessRights(call: v17.call, version: () async => '17.0').load();
      expect(v17.asked.where((q) => q.endsWith(':has_access')), isEmpty);

      final v20 = _Server(_user, 20);
      await AccessRights(call: v20.call, version: () async => '20.0').load();
      expect(
        v20.asked.where((q) => q.endsWith(':check_access_rights')),
        isEmpty,
      );
    });

    test('a second load for the same account asks nothing new', () async {
      final server = _Server(_user, 19);
      final r = AccessRights(call: server.call, version: () async => '19.0');

      await r.load();
      final asked = server.asked.length;
      await r.load();

      expect(server.asked.length, asked);
    });

    test('force asks again, and picks up a role that changed', () async {
      var role = _user;
      final r = AccessRights(
        call: (params) => _Server(role, 19).call(params),
        version: () async => '19.0',
      );
      await r.load();
      expect(r.canManageStages, isFalse);

      role = _administrator;
      await r.load();
      expect(r.canManageStages, isFalse); // cached until forced

      await r.load(force: true);
      expect(r.canManageStages, isTrue);
    });

    test('concurrent loads share one probe', () async {
      final server = _Server(_user, 19);
      final r = AccessRights(call: server.call, version: () async => '19.0');

      await Future.wait([r.load(), r.load(), r.load()]);
      final once = server.asked.length;

      final again = _Server(_user, 19);
      await AccessRights(call: again.call, version: () async => '19.0').load();
      expect(once, again.asked.length);
    });
  });

  group('reset and failure', () {
    test('reset forgets the account, so nothing carries over', () async {
      final r = await _loaded(_desk, 19);
      expect(r.canEditEvent, isFalse);
      expect(r.isLoaded, isTrue);

      r.reset();

      expect(r.isLoaded, isFalse);
      // Unknown means allowed until the next account has been asked.
      expect(r.canEditEvent, isTrue);
    });

    test('reset notifies listeners, so visible buttons rebuild', () async {
      final r = await _loaded(_desk, 19);
      var notified = 0;
      r.addListener(() => notified++);

      r.reset();
      await r.load();

      expect(notified, greaterThanOrEqualTo(2));
    });

    test('an unreachable server hides nothing', () async {
      final r = AccessRights(
        call: (_) async => throw Exception('SocketException: timed out'),
        version: () async => '19.0',
      );
      await r.load();

      expect(r.isLoaded, isTrue);
      expect(r.canCreateEvent, isTrue);
      expect(r.canManageStages, isTrue);
      expect(r.canEditTicket, isTrue);
    });

    test('a question the server could not answer stays allowed while the '
        'others are still enforced', () async {
      final r = AccessRights(
        call: (params) async {
          if (params['model'] == EventModels.stage) {
            throw Exception('timeout');
          }
          return _Server(_desk, 19).call(params);
        },
        version: () async => '19.0',
      );
      await r.load();

      expect(r.canManageStages, isTrue); // unanswered
      expect(r.canEditEvent, isFalse); // answered: no
    });
  });
}
