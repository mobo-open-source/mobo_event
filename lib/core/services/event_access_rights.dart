import 'package:flutter/foundation.dart';

import '../utils/odoo_compat.dart';
import 'event_access_gate.dart';
import 'odoo_session_manager.dart';

/// The Odoo models this app creates, edits or deletes, in one place so the UI
/// and the permission probe cannot drift apart.
class EventModels {
  const EventModels._();

  static const event = 'event.event';
  static const stage = 'event.stage';
  static const ticket = 'event.event.ticket';
  static const question = 'event.question';
  static const questionAnswer = 'event.question.answer';
  static const mail = 'event.mail';
  static const registration = 'event.registration';
  static const registrationAnswer = 'event.registration.answer';
  static const slot = 'event.slot';
  static const activity = 'mail.activity';
}

/// The write operations the UI gates on. `read` is not among them: an account
/// that cannot read events is refused at sign-in ([hasEventAccess]).
enum AccessOp {
  create('create'),
  write('write'),
  unlink('unlink');

  const AccessOp(this.odooName);

  /// The name Odoo's permission API knows the operation by.
  final String odooName;
}

/// What the signed-in user may do to each model the app mutates, so every
/// create, edit and delete affordance can be hidden from an account the
/// server would refuse anyway.
///
/// The answers come from the server's own ACLs (`has_access` on Odoo 18+,
/// `check_access_rights` on 17 — see [canAccessModel]), not from a table of
/// group names. The roles differ across the app's whole range — a Registration
/// Desk user may only edit registrations, a User may also create and edit
/// events, tickets, questions and schedulers, only an Administrator may delete
/// events or manage stages — and a customised ACL is honoured the same way.
///
/// Anything the server could not answer is treated as allowed, exactly like
/// the sign-in gate: an unanswered probe must not strip a legitimate user of a
/// button. The server still refuses a genuinely forbidden write, and the app
/// reports that as an access error.
///
/// The cache belongs to one account. It is dropped by [reset] on sign-out and
/// account switch, and [load] also rebuilds it whenever the active account
/// differs from the one it was built for.
class AccessRights extends ChangeNotifier {
  AccessRights({
    EventAccessCall? call,
    Future<dynamic> Function()? version,
    int? userId,
  }) : _callOverride = call,
       _versionOverride = version,
       _userId = userId;

  /// The app-wide instance the providers and widgets share.
  static final AccessRights instance = AccessRights();

  final EventAccessCall? _callOverride;
  final Future<dynamic> Function()? _versionOverride;

  /// `'model:operation'` → the server's answer. Absent = not answered.
  final Map<String, bool> _answers = {};

  /// The signed-in user, for the per-record activity rule.
  int? _userId;

  String? _loadedFor;
  Future<void>? _loading;
  bool _loaded = false;

  /// True once [load] has finished for the current account, whether or not the
  /// server answered every question.
  bool get isLoaded => _loaded;

  bool can(String model, AccessOp op) =>
      _answers['$model:${op.odooName}'] ?? true;

  bool canCreate(String model) => can(model, AccessOp.create);
  bool canWrite(String model) => can(model, AccessOp.write);
  bool canDelete(String model) => can(model, AccessOp.unlink);

  /// Whether the user may create, edit or delete at all on [model].
  bool canModify(String model) =>
      canCreate(model) || canWrite(model) || canDelete(model);

  // Each getter is one thing a user can do in the app, with every permission
  // that action needs on the server. Screens ask these, never the models
  // directly, so a rule that spans models (a ticket is edited through an
  // `event.event` write *and* a `event.event.ticket` write) lives here once.

  bool get canCreateEvent => canCreate(EventModels.event);
  bool get canEditEvent => canWrite(EventModels.event);

  /// Moving a card between stages, and changing its kanban status, are both a
  /// write on the event.
  bool get canMoveEvent => canWrite(EventModels.event);

  // Stages — only Administrators hold any of these on the server.
  bool get canAddStage => canCreate(EventModels.stage);
  bool get canRenameStage => canWrite(EventModels.stage);
  bool get canReorderStages => canWrite(EventModels.stage);
  bool get canDeleteStage => canDelete(EventModels.stage);
  bool get canManageStages =>
      canAddStage || canRenameStage || canReorderStages || canDeleteStage;

  // Slots (Odoo 19+)
  bool get canAddSlot => canCreate(EventModels.slot);
  bool get canDeleteSlot => canDelete(EventModels.slot);

  bool get canAddTicket => canCreate(EventModels.ticket);

  /// An existing ticket is saved through the event's `event_ticket_ids`.
  bool get canEditTicket =>
      canWrite(EventModels.ticket) && canWrite(EventModels.event);
  bool get canDeleteTicket => canDelete(EventModels.ticket);

  /// Linking a reusable question (Odoo 19+) or removing one from the event is
  /// a write on the event's `question_ids`.
  bool get canLinkQuestion => canWrite(EventModels.event);
  bool get canRemoveQuestion => canWrite(EventModels.event);

  /// A new question is created, then linked to the event.
  bool get canCreateQuestion =>
      canCreate(EventModels.question) && canWrite(EventModels.event);

  /// Whether the Add affordance is offered at all. Odoo 19 picks from reusable
  /// questions (linking one) or creates a new one; through 18 a question can
  /// only be created for the event.
  bool canAddQuestion(OdooCompat compat) => compat.hasReusableQuestions
      ? canLinkQuestion || canCreateQuestion
      : canCreateQuestion;

  /// Saving a question clears and recreates its answers.
  bool get canEditQuestion =>
      canWrite(EventModels.question) &&
      canCreate(EventModels.questionAnswer) &&
      canDelete(EventModels.questionAnswer);

  // Communication (mail schedulers), also attached through the event.
  bool get canAddScheduler =>
      canCreate(EventModels.mail) && canWrite(EventModels.event);
  bool get canEditScheduler =>
      canWrite(EventModels.mail) && canWrite(EventModels.event);
  bool get canDeleteScheduler => canDelete(EventModels.mail);

  // Activities. Odoo (17–20, `mail.activity._check_access`) lets a user
  // schedule one only on a document they can write, and change or remove an
  // existing one when it is theirs (the access rule) *or* they can write the
  // document. The second half is per record, so those two take the activity's
  // assignee.
  bool get canScheduleActivity =>
      canCreate(EventModels.activity) && canWrite(EventModels.event);

  bool canChangeActivity({int? assigneeId}) =>
      canWrite(EventModels.activity) &&
      (canWrite(EventModels.event) || _isMe(assigneeId));

  bool canDeleteActivity({int? assigneeId}) =>
      canDelete(EventModels.activity) &&
      (canWrite(EventModels.event) || _isMe(assigneeId));

  bool _isMe(int? userId) => userId != null && userId == _userId;

  bool get canEditDocumentation => canWrite(EventModels.event);

  // Registrations. Scanning a QR, tapping an attendee and "Continue" on a
  // ticket all mark the registration attended — a write.
  bool get canCreateAttendee => canCreate(EventModels.registration);
  bool get canEditAttendee => canWrite(EventModels.registration);
  bool get canMarkAttended => canWrite(EventModels.registration);

  /// Which operations each model is asked about — only what the UI can act on,
  /// to keep the number of round trips down. Slots exist from Odoo 19 only.
  Map<String, List<AccessOp>> _questions(OdooCompat compat) => {
    EventModels.event: AccessOp.values,
    EventModels.stage: AccessOp.values,
    EventModels.ticket: AccessOp.values,
    EventModels.question: AccessOp.values,
    EventModels.questionAnswer: AccessOp.values,
    EventModels.mail: AccessOp.values,
    EventModels.registration: AccessOp.values,
    EventModels.registrationAnswer: const [AccessOp.create, AccessOp.write],
    if (compat.hasEventSlots) EventModels.slot: AccessOp.values,
    EventModels.activity: const [
      AccessOp.create,
      AccessOp.write,
      AccessOp.unlink,
    ],
  };

  /// Asks the server what the current account may do. Concurrent callers share
  /// one probe; a call for an account that already has answers is a no-op
  /// unless [force] is set.
  Future<void> load({bool force = false}) {
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final future = _load(force: force);
    _loading = future;
    return future.whenComplete(() => _loading = null);
  }

  Future<void> _load({required bool force}) async {
    try {
      final identity = await _identity();
      if (!force && _loaded && identity == _loadedFor) return;
      if (_callOverride == null) {
        _userId = (await OdooSessionManager.getCurrentSession())?.userId;
      }

      final version = await _version();
      final call = _callOverride ?? _defaultCall;
      final questions = _questions(OdooCompat.of(version));

      final fresh = <String, bool>{};
      await Future.wait([
        for (final entry in questions.entries)
          for (final op in entry.value)
            () async {
              final answer = await canAccessModel(
                call,
                entry.key,
                op.odooName,
                version: version,
              );
              if (answer != null) fresh['${entry.key}:${op.odooName}'] = answer;
            }(),
      ]);

      _answers
        ..clear()
        ..addAll(fresh);
      _loadedFor = identity;
      _loaded = true;
    } catch (_) {
      // Nothing answered: everything stays allowed (see class docs).
      _answers.clear();
      _loaded = true;
    }
    notifyListeners();
  }

  /// Forgets the current account's answers. Call on sign-out and on every
  /// account switch, so one account's rights never show on the next.
  void reset() {
    _answers.clear();
    _loadedFor = null;
    _loaded = false;
    if (_callOverride == null) _userId = null;
    notifyListeners();
  }

  Future<String?> _identity() async {
    if (_callOverride != null) return 'test';
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return null;
    return '${session.serverUrl}|${session.database}|${session.userId}';
  }

  Future<dynamic> _version() async {
    final override = _versionOverride;
    if (override != null) return override();
    final session = await OdooSessionManager.getCurrentSession();
    return session?.version ?? session?.odooSession.serverVersion;
  }

  Future<dynamic> _defaultCall(Map<String, dynamic> params) async {
    final client = await OdooSessionManager.getClientEnsured();
    return client.callKw(params);
  }
}
