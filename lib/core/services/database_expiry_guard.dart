import 'package:flutter/widgets.dart';

import '../../features/login/pages/server_setup_screen.dart';
import '../const/keys/global_keys.dart';
import '../routing/page_transition.dart';
import '../utils/database_expiry.dart';
import 'odoo_session_manager.dart';
import 'session_service.dart';

/// Re-checks, each time the app returns to the foreground, whether the
/// signed-in account's database has expired — a subscription can lapse while
/// the app sits in the background, long after the sign-in that last checked.
///
/// Deliberately not a poller: it only runs when asked, from the app's resume
/// handler. And it only ever acts on a definite "expired"; a probe that can't
/// be read — offline, timed out, an odd answer — leaves the user exactly where
/// they are.
class DatabaseExpiryGuard {
  const DatabaseExpiryGuard._();

  /// Resumes closer together than this share one answer, so flicking between
  /// apps does not turn into a request each time.
  static const Duration minInterval = Duration(seconds: 30);

  static bool _running = false;
  static DateTime? _lastCheckedAt;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @visibleForTesting
  static bool Function() isSignedIn = _hasSession;

  /// Whether the signed-in account's database has expired.
  @visibleForTesting
  static Future<bool> Function() checkExpired = _probe;

  /// Ends the current account's session — only that one; the other saved
  /// accounts stay, exactly as when any other post-login check rejects a
  /// session.
  @visibleForTesting
  static Future<void> Function() signOut = OdooSessionManager.logout;

  @visibleForTesting
  static void reset() {
    _running = false;
    _lastCheckedAt = null;
    now = DateTime.now;
    isSignedIn = _hasSession;
    checkExpired = _probe;
    signOut = OdooSessionManager.logout;
  }

  /// Runs the check, unless nobody is signed in, one is already running, or
  /// the last one started less than [minInterval] ago ([ignoreRecentCheck]
  /// skips that last rule only).
  ///
  /// When the database has expired the account is signed out and the app lands
  /// on the server setup screen, which says why.
  static Future<void> onAppResumed({bool ignoreRecentCheck = false}) async {
    if (!isSignedIn()) return;
    if (_running) return;

    final last = _lastCheckedAt;
    if (!ignoreRecentCheck &&
        last != null &&
        now().difference(last) < minInterval) {
      return;
    }

    _running = true;
    _lastCheckedAt = now();
    try {
      if (!await checkExpired()) return;

      // A definite answer, so the user is told even if ending the session
      // hit a snag: whatever was left behind is caught by the same check on
      // the next app start.
      try {
        await signOut();
      } catch (_) {}
      _lastCheckedAt = null;
      _showSignIn();
    } catch (_) {
      // Fail open.
    } finally {
      _running = false;
    }
  }

  static bool _hasSession() => SessionService.instance.currentSession != null;

  static Future<bool> _probe() async {
    final client = await OdooSessionManager.getClient();
    if (client == null) return false;
    return DatabaseExpiry.isExpired(client);
  }

  /// Replaces whatever is on screen with the server setup screen, showing why.
  static void _showSignIn() {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    navigator.pushAndRemoveUntil(
      dynamicRoute(
        context,
        const ServerSetupScreen(
          initialError: DatabaseExpiredException.message,
        ),
      ),
      (route) => false,
    );
  }
}
