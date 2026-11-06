import 'dart:async';
import 'dart:io';

import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/database_expiry.dart';

/// Why an authentication attempt failed, derived from the raw exception the
/// login or add-account call threw.
///
/// [LoginProvider.login] classifies its own failures inline because
/// [OdooSessionManager.loginAndSaveSession] hands it a [LoginStatus] rather
/// than an exception. The add-account paths call
/// [OdooSessionManager.authenticate] instead, which throws the raw
/// [OdooException] straight through — its `toString()` is the entire Odoo
/// error map, server traceback included. This classifies that exception so
/// both flows can show the user the same short sentence.
enum AuthFailure {
  /// The server rejected the username/password pair.
  invalidCredentials,

  /// The account is protected by TOTP/email OTP and needs a second factor.
  twoFactorRequired,

  /// The credentials were right, but the database's subscription has expired.
  databaseExpired,

  /// The request never reached the server, or timed out on the way.
  network,

  /// The server answered, but with something this app cannot use.
  server,

  /// Nothing matched — the caller's own fallback wording applies.
  unknown,
}

/// Classifies [error] into the reason an authentication attempt failed.
AuthFailure classifyAuthFailure(Object error) {
  // By type, and ahead of every text match below: the expiry message says
  // "database", which the string matching would read as a wrong database.
  if (error is DatabaseExpiredException) return AuthFailure.databaseExpired;

  // Checked before anything else: a 2FA-protected account fails inside the
  // RPC client's own response parsing, so the exception is a plain TypeError
  // with no Odoo error payload to match on.
  if (isTwoFactorError(error)) return AuthFailure.twoFactorRequired;

  if (error is NoInternetException ||
      error is ServerUnreachableException ||
      error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is TlsException) {
    return AuthFailure.network;
  }

  final msg = error.toString().toLowerCase();

  if (msg.contains('access denied') ||
      msg.contains('accessdenied') ||
      msg.contains('wrong login/password') ||
      msg.contains('invalid login') ||
      msg.contains('authentication failed')) {
    return AuthFailure.invalidCredentials;
  }

  // A server answering http where https was asked for (or the reverse) comes
  // back as a redirect, which is a server-side answer rather than a network
  // failure — and the fix is the protocol, not the credentials.
  if (error is HttpException ||
      msg.contains('redirect') ||
      msg.contains('301') ||
      msg.contains('302')) {
    return AuthFailure.server;
  }

  if (msg.contains('invalid database') || msg.contains('database')) {
    return AuthFailure.server;
  }

  if (msg.contains('<html') ||
      msg.contains('<!doctype') ||
      msg.contains('returned html')) {
    return AuthFailure.server;
  }

  if (msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('no route to host') ||
      msg.contains('timed out') ||
      msg.contains('timeout')) {
    return AuthFailure.network;
  }

  return AuthFailure.unknown;
}

/// True when [error] is the parse failure the RPC client raises for an
/// account protected by two-factor authentication.
///
/// Odoo answers `/web/session/authenticate` for such an account with a body
/// that carries no session info, and `OdooClient.authenticate` trips over the
/// missing map while reading it. The extra exclusions keep an HTML error page
/// or a gateway timeout — which produce their own null-typed failures — from
/// being mistaken for a 2FA prompt.
bool isTwoFactorError(Object error) {
  final msg = error.toString().toLowerCase();

  final isNullTypeParseFailure =
      (msg.contains("type 'null'") &&
          (msg.contains('map<string') || msg.contains('subtype'))) &&
      !msg.contains('html') &&
      !msg.contains('502') &&
      !msg.contains('timeout');

  return isNullTypeParseFailure ||
      msg.contains('two factor') ||
      msg.contains('two-factor') ||
      msg.contains('2fa') ||
      msg.contains('totp') ||
      msg.contains('token_expired');
}

/// A short, user-facing sentence describing [error], worded the same way the
/// sign-in screen words the equivalent failure.
///
/// [fallback] is returned for [AuthFailure.unknown] — the only case where the
/// calling flow ("sign in" vs "add account") changes what reads correctly.
String authFailureMessage(
  Object error, {
  String fallback =
      'Login failed. Please check your credentials and server settings.',
}) {
  switch (classifyAuthFailure(error)) {
    case AuthFailure.invalidCredentials:
      return 'Incorrect email or password. Please check your login credentials.';

    case AuthFailure.twoFactorRequired:
      return 'This account is protected by two-factor authentication.';

    case AuthFailure.databaseExpired:
      return DatabaseExpiredException.message;

    case AuthFailure.network:
      return _networkMessage(error);

    case AuthFailure.server:
      final msg = error.toString().toLowerCase();
      if (msg.contains('<html') ||
          msg.contains('<!doctype') ||
          msg.contains('returned html')) {
        return 'Invalid server response. Please verify this is an Odoo server '
            'and that the URL is correct. Check if HTTPS should be HTTP.';
      }
      if (error is HttpException ||
          msg.contains('redirect') ||
          msg.contains('301') ||
          msg.contains('302')) {
        return 'Server redirected the request. Try switching between HTTP and '
            'HTTPS.';
      }
      return 'Database access failed. Please verify the selected database is '
          'correct.';

    case AuthFailure.unknown:
      return fallback;
  }
}

String _networkMessage(Object error) {
  if (error is NoInternetException) {
    return 'No internet connection. Please check your network settings.';
  }
  if (error is ServerUnreachableException) {
    return 'Cannot reach the server. Please verify the server URL is correct.';
  }
  if (error is HandshakeException || error is TlsException) {
    return 'Secure connection failed. Try switching between HTTP and HTTPS, '
        'or contact your administrator.';
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('failed host lookup') ||
      msg.contains('host lookup failed')) {
    return 'Server not found. Please check the server URL for typos and '
        'verify your DNS settings.';
  }
  if (msg.contains('connection refused')) {
    return 'Server is not responding. Please verify the server URL is correct.';
  }
  if (msg.contains('timed out') || msg.contains('timeout')) {
    return 'Connection timed out. The server may be slow or unreachable. '
        'Please try again.';
  }
  return 'Network error occurred. Please check your internet connection and '
      'server URL.';
}
