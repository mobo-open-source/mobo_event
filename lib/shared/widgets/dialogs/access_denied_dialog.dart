import 'package:flutter/material.dart';

import '../../../core/services/event_access_gate.dart';
import 'blocking_notice_dialog.dart';

/// Displays a blocking "Access Denied" dialog for an account that signs in
/// correctly but cannot use this app: a portal (share) user, or an internal
/// user who holds no Event role.
///
/// [denial] picks the heading and the explanation, so each case names itself
/// rather than being reported as a generic missing right — the heading is what
/// tells an administrator which of the two to go and fix. [message] overrides
/// the wording only, for callers that already hold the server's own sentence.
Future<void> showAccessDeniedDialog(
  BuildContext context, {
  AccessDenial denial = AccessDenial.portalUser,
  String? message,
  String actionLabel = 'OK',
  VoidCallback? onClose,
}) {
  return showBlockingNoticeDialog(
    context,
    title: denial.title,
    message: message ?? denial.message,
    actionLabel: actionLabel,
    onClose: onClose,
  );
}
