import 'package:odoo_rpc/odoo_rpc.dart';

/// Raised when credentials authenticate correctly but the Odoo database behind
/// them has passed its subscription's expiry date.
///
/// Odoo issues a session regardless — the password is right — so, like
/// [PortalUserException], nothing about the login itself fails and the user
/// would otherwise meet an expired database as unexplained errors deep inside
/// the app. Rejecting it where the session is established is both clearer and
/// cheaper.
///
/// Deliberately not an `AppException`: the wording below is shown to the user
/// verbatim, and `AppException.toString()` would prefix it with the type name.
class DatabaseExpiredException implements Exception {
  const DatabaseExpiredException();

  /// Single source of truth for the wording, so the inline error, the OTP
  /// screen and the snackbars cannot drift apart.
  static const String message =
      'This database has expired. Please contact your administrator or Odoo '
      'to renew the subscription.';

  @override
  String toString() => message;
}

/// Reads the database's subscription expiry from the server and decides
/// whether it has passed.
///
/// Enterprise's `web_enterprise` adds `expiration_date` to the session info of
/// internal users; Community never sends it, so a Community database is never
/// "expired". The server only reveals it to an *authenticated* user, which is
/// why this cannot run when the database is picked and instead runs right
/// after the password (or OTP) is accepted.
///
/// Every failure here reads as "not expired": only a definite answer may lock
/// anyone out. A flaky connection must never be what ends a valid session.
class DatabaseExpiry {
  const DatabaseExpiry._();

  /// The key `web_enterprise` adds to `get_session_info`.
  static const String sessionInfoKey = 'expiration_date';

  /// The system parameter the same value is stored in.
  static const String parameterKey = 'database.expiration_date';

  /// How long the probe may take before the user is let in.
  static const Duration probeTimeout = Duration(seconds: 10);

  /// `YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS`, optionally with a `T` separator
  /// and any tail (fractional seconds, a zone suffix).
  static final RegExp _format = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2}))?',
  );

  /// Whether [value] — a raw `expiration_date` — names a moment that has
  /// passed, by the Odoo web client's own rule: expired when
  /// `Math.round(daysLeft) <= 0`, with `daysLeft` the time until expiry in
  /// days. So an expiry less than twelve hours away already counts as expired,
  /// and exactly twelve hours away does not.
  ///
  /// The date is read as UTC, with a missing time as midnight. Anything that
  /// is not a string in that format — `null`, `false`, `''`, a date Odoo
  /// would never send — is not an expiry date, so it is not expired.
  static bool hasExpired(Object? value, {DateTime? now}) {
    if (value is! String) return false;

    final match = _format.firstMatch(value);
    if (match == null) return false;

    int part(int group) => int.parse(match.group(group) ?? '0');

    final year = part(1);
    final month = part(2);
    final day = part(3);
    final expiry = DateTime.utc(year, month, day, part(4), part(5), part(6));

    // `DateTime.utc` rolls an impossible date over (month 13, day 40) rather
    // than refusing it. That would turn garbage into a confident answer.
    if (expiry.year != year || expiry.month != month || expiry.day != day) {
      return false;
    }

    final untilExpiry = expiry.difference((now ?? DateTime.now()).toUtc());
    final daysLeft = untilExpiry.inMicroseconds / Duration.microsecondsPerDay;
    return daysLeft.round() <= 0;
  }

  /// The testable core of [isExpired]: [readSessionInfo] answers the
  /// `get_session_info` call and [readParameter] reads
  /// `ir.config_parameter.get_param('database.expiration_date')`.
  ///
  /// The parameter is consulted only when the session-info call itself
  /// *failed*. A server that answered without the key — Community — is
  /// answering "no expiry", and asking again would only cost a request that a
  /// non-admin user is not allowed to make.
  static Future<bool> check({
    required Future<dynamic> Function() readSessionInfo,
    required Future<dynamic> Function() readParameter,
  }) async {
    try {
      dynamic sessionInfo;
      try {
        sessionInfo = await readSessionInfo();
      } catch (_) {
        return hasExpired(await readParameter());
      }

      if (sessionInfo is! Map) return false;
      return hasExpired(sessionInfo[sessionInfoKey]);
    } catch (_) {
      return false;
    }
  }

  /// Whether the database behind [client] — which must already be
  /// authenticated — has expired. Gives up after [probeTimeout].
  static Future<bool> isExpired(OdooClient client) {
    return check(
      readSessionInfo: () =>
          client.callRPC('/web/session/get_session_info', 'call', {}),
      readParameter: () => client.callKw({
        'model': 'ir.config_parameter',
        'method': 'get_param',
        'args': [parameterKey],
        'kwargs': {},
      }),
    ).timeout(probeTimeout, onTimeout: () => false);
  }
}
