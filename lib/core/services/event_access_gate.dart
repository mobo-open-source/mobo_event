import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../exceptions/app_exceptions.dart';
import '../utils/odoo_compat.dart';

/// Why an account that signed in correctly is still refused by this app.
///
/// One source for the dialog heading and the wording, so the inline error
/// under the password field, the blocking dialog and every flow that can hit
/// them (sign-in, two-factor, add account, switch account, app start) say the
/// same thing.
enum AccessDenial {
  /// A portal or public user (`res.users.share`) — never an internal employee.
  portalUser,

  /// An internal user whose "Events" role is left empty: they hold none of the
  /// Event groups (Registration Desk, User, Administrator).
  noEventAccess,
}

extension AccessDenialText on AccessDenial {
  String get title => switch (this) {
    AccessDenial.portalUser => 'Access Denied — Portal User',
    AccessDenial.noEventAccess => 'Access Denied — No Event Access',
  };

  String get message => switch (this) {
    AccessDenial.portalUser => PortalUserException.portalUserMessage,
    AccessDenial.noEventAccess => noEventAccessMessage,
  };
}

const String noEventAccessMessage =
    'This user account has no access to Events. '
    'Please ask your administrator to set the Events role on your user '
    '(Registration Desk, User or Administrator).';

/// The lowest of Odoo's three Event groups. User implies it and Administrator
/// implies User, identically on 17, 18, 19 and 20, so holding *any* Events
/// role means holding this one — and holding none of them means not holding
/// it. The user form's "Events" field being empty is exactly this being false.
const String eventRoleGroup = 'event.group_event_registration_desk';

/// Runs one `callKw` payload against the server.
typedef EventAccessCall = Future<dynamic> Function(Map<String, dynamic> params);

/// Whether the account behind [client] may use the Event app at all.
///
/// Same place in every flow as `isEventModuleInstalled`: right after
/// authenticating, before the account is committed as the active session. A
/// module that is installed is not enough — an internal user whose "Events"
/// role is empty still signs in fine, and then meets an access error (or an
/// empty app) on every screen.
///
/// Fails open, exactly like the module check: only a confirmed refusal returns
/// false, so a dropped request never locks a legitimate user out. A real
/// refusal is asked again on every sign-in, switch and app start.
Future<bool> hasEventAccess(OdooClient client) {
  final session = client.sessionId;
  return evaluateEventAccess(
    (params) => client.callKw(params),
    userId: session?.userId,
    version: session?.serverVersion,
  );
}

/// The decision behind [hasEventAccess], with the server call injected.
///
/// Two independent questions, and either one answering "no" refuses the
/// account:
///
/// 1. Does the user hold an Events role at all? ([holdsEventRole]) This is the
///    question the user form's "Events" field answers, and it cannot be
///    replaced by the second one: `website_event` grants `base.group_user`
///    read access to `event.event`, and `pos_event` grants it to POS users, so
///    on a server with either installed a user with *no* Events role can still
///    read events.
/// 2. Will the server let them read `event.event`? ([canReadEvents]) Catches a
///    customised ACL that withholds the model from a user who does hold a role.
@visibleForTesting
Future<bool> evaluateEventAccess(
  EventAccessCall callKw, {
  int? userId,
  dynamic version,
}) async {
  if (userId != null) {
    final hasRole = await holdsEventRole(
      callKw,
      userId: userId,
      version: version,
    );
    if (hasRole == false) return false;
  }

  return await canReadEvents(callKw, version: version) != false;
}

/// Whether [userId] holds any Events role, or null when the server could not
/// be asked.
///
/// `res.users.has_group` changed shape: Odoo 18 turned it into a per-record
/// method taking `([uid], group)`, while 17 declares it `@api.model` and takes
/// `(group)` alone. The release picks the right one first, and the other is
/// still tried so a server whose version could not be read does not turn into
/// a false denial.
@visibleForTesting
Future<bool?> holdsEventRole(
  EventAccessCall callKw, {
  required int userId,
  dynamic version,
}) async {
  Future<dynamic> asRecordMethod() => callKw({
    'model': 'res.users',
    'method': 'has_group',
    'args': [
      [userId],
      eventRoleGroup,
    ],
    'kwargs': const {},
  });

  Future<dynamic> asModelMethod() => callKw({
    'model': 'res.users',
    'method': 'has_group',
    'args': [eventRoleGroup],
    'kwargs': const {},
  });

  final attempts = OdooCompat.of(version).hasGroupPerRecord
      ? [asRecordMethod, asModelMethod]
      : [asModelMethod, asRecordMethod];

  for (final attempt in attempts) {
    try {
      final result = await attempt();
      if (result is bool) return result;
    } catch (_) {
      // Fall through to the other calling convention.
    }
  }
  return null;
}

/// Whether the current user may read `event.event`, or null when the server
/// could not be asked. See [canAccessModel].
@visibleForTesting
Future<bool?> canReadEvents(EventAccessCall callKw, {dynamic version}) =>
    canAccessModel(callKw, 'event.event', 'read', version: version);

/// Whether the current user may perform [operation] (`read`, `create`,
/// `write` or `unlink`) on [model] in general, or null when the server could
/// not be asked.
///
/// Asked through the ORM's own permission API rather than by reading an error
/// message, and against the model in general (no record ids), because record
/// rules are not what decides whether an action is worth offering:
///
/// * Odoo 18 and later: `has_access(operation)` — the only option on 20.
/// * Odoo 17 and earlier: `check_access_rights(operation, raise_exception=False)`.
///
/// The other is still tried as a fallback so a server whose version could not
/// be read (or a backport that moved the method) does not turn into a false
/// denial. For `read`, a search probe backs both up; there is no harmless
/// probe for the other operations, so those stay unanswered (null) instead.
Future<bool?> canAccessModel(
  EventAccessCall callKw,
  String model,
  String operation, {
  dynamic version,
}) async {
  Future<dynamic> viaHasAccess() => callKw({
    'model': model,
    'method': 'has_access',
    // An empty id list asks about the model in general.
    'args': [const <int>[], operation],
    'kwargs': const {},
  });

  Future<dynamic> viaCheckAccessRights() => callKw({
    'model': model,
    'method': 'check_access_rights',
    'args': [operation],
    'kwargs': const {'raise_exception': false},
  });

  final attempts = OdooCompat.of(version).hasHasAccess
      ? [viaHasAccess, viaCheckAccessRights]
      : [viaCheckAccessRights, viaHasAccess];

  for (final attempt in attempts) {
    try {
      final result = await attempt();
      if (result is bool) return result;
    } catch (_) {
      // Not available on this release: fall through to the other API.
    }
  }

  return operation == 'read' ? _probeReadAccess(callKw, model) : null;
}

/// Last-resort check for a server that answers neither permission API: the
/// cheapest possible read, where only an explicit access error counts as a
/// denial, so a dropped request cannot turn into a lockout.
Future<bool?> _probeReadAccess(EventAccessCall callKw, String model) async {
  try {
    await callKw({
      'model': model,
      'method': 'search_count',
      'args': [
        [
          ['id', '=', 0],
        ],
      ],
      'kwargs': const {},
    });
    return true;
  } catch (e) {
    return isAccessErrorText(e.toString()) ? false : null;
  }
}

/// Whether [text] (an RPC error, stringified) is the server refusing access
/// rather than failing for some other reason.
///
/// `odoo.exceptions.AccessError` is what Odoo raises on every release, and it
/// travels in the error payload's `name`; the sentences are the ones Odoo 17–20
/// use for the refusal itself.
@visibleForTesting
bool isAccessErrorText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('accesserror') ||
      lower.contains('access error') ||
      lower.contains('not allowed to access') ||
      lower.contains('do not have access');
}
