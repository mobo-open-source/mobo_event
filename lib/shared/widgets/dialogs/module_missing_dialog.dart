import 'package:flutter/material.dart';

import 'blocking_notice_dialog.dart';

/// Displays a blocking dialog for a server that doesn't have the required
/// "Event" module installed.
Future<void> showModuleMissingDialog(
  BuildContext context, {
  String actionLabel = 'Back to Login',
  VoidCallback? onClose,
}) {
  return showBlockingNoticeDialog(
    context,
    title: 'Module Missing',
    message:
        'The required "Event" module is not installed on this server. '
        'Please contact your administrator to enable it.',
    actionLabel: actionLabel,
    onClose: onClose,
  );
}
