import 'package:odoo_rpc/odoo_rpc.dart';

/// Whether the given client's server has the `event` module installed.
///
/// This is the same check [AppEntry] already runs once a session is
/// established, extracted so the add-account, switch-account and OTP flows
/// can run it too — right after authenticating a *new* account and before
/// that account is committed as the active session. A server without the
/// Event module is otherwise a dead end the user only discovers after the
/// account has already replaced whatever was previously signed in.
Future<bool> isEventModuleInstalled(OdooClient client) async {
  try {
    final count = await client.callKw({
      'model': 'ir.module.module',
      'method': 'search_count',
      'args': [
        [
          ['name', '=', 'event'],
          ['state', '=', 'installed'],
        ],
      ],
      'kwargs': {},
    });

    return (count as num) > 0;
  } catch (_) {
    // A probe that couldn't run is not the same as a confirmed-missing
    // module — fail open here and let the normal post-login checks (which
    // already run on every app start) catch a genuinely unusable server.
    return true;
  }
}
