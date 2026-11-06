/// Centralized application exceptions for consistent error handling.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  AppException(this.message, {this.code, this.cause});
  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class ServerException extends AppException {
  ServerException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class AuthException extends AppException {
  AuthException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

/// Raised when credentials authenticate correctly but belong to a *portal*
/// (share) user rather than an internal one.
///
/// Odoo happily issues a session to a portal user — the password is right, so
/// nothing about the login itself fails. Every model then refuses them at the
/// access-rights layer, which would otherwise surface as a stream of
/// unexplained empty screens deep inside the app. Rejecting at the
/// credentials screen is both clearer and cheaper.
///
/// Deliberately an [AuthException]: it is a reason the sign-in cannot stand,
/// and any generic `catch` that already handles auth failures should keep
/// treating it as one.
class PortalUserException extends AuthException {
  PortalUserException([String? message]) : super(message ?? portalUserMessage);

  /// Single source of truth for the wording, so the inline error under the
  /// password field and the dialog above it cannot drift apart.
  static const String portalUserMessage =
      'Portal users cannot use this app. '
      'Please log in with an internal user account.';
}

class ValidationException extends AppException {
  ValidationException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class UnknownException extends AppException {
  UnknownException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}
