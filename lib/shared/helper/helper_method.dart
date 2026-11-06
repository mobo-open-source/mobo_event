import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_theme.dart';

IconData getKanbanIcon(String? state) {
  switch (state) {
    case 'done':
      return Icons.circle;
    case 'normal':
      return Icons.circle;
    case 'blocked':
      return Icons.warning;
    case 'cancel':
      return Icons.cancel;
    default:
      return Icons.help_outline;
  }
}

/// Short label for the kanban-state status capsule (event_short_card).
String getKanbanLabel(String? state) {
  switch (state) {
    case 'done':
      return 'Ready';
    case 'normal':
      return 'In Progress';
    case 'blocked':
      return 'Blocked';
    case 'cancel':
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}

Color getKanbanColor(String kanbanState) {
  switch (kanbanState.toLowerCase()) {
    // "In Progress" — CLAUDE.md §1's semantic table calls this one out by
    // name: blue for "in-progress/proposal", not the grey fallback.
    case 'normal':
      return StatusColors.blue;
    case 'done':
      return StatusColors.green;
    case 'blocked':
      return StatusColors.orange;
    case 'cancel':
      return StatusColors.red;
    default:
      return StatusColors.grey;
  }
}

Widget getIcont(String? iconName, String? iconstate) {
  // Nothing scheduled yet: the calendar is the way in to schedule something,
  // so it carries the brand colour rather than a disabled-looking grey.
  if (iconName == null || iconName == 'false' || iconstate == null) {
    return const HugeIcon(
      icon: HugeIcons.strokeRoundedCalendar03,
      color: AppTheme.primaryColor,
      size: 20,
    );
  }

  final name = iconName.toLowerCase();

  switch (name) {
    case 'fa-check':
      return Icon(Icons.check, size: 20, color: getColor(iconstate));

    case 'fa-phone':
      return Icon(Icons.phone, size: 20, color: getColor(iconstate));

    case 'fa-users':
      return Icon(Icons.people_outline, size: 20, color: getColor(iconstate));

    case 'fa-envelope':
      return Icon(Icons.email, size: 20, color: getColor(iconstate));

    default:
      return HugeIcon(
        icon: HugeIcons.strokeRoundedCalendar03,
        size: 20,
        color: getColor(iconstate),
      );
  }
}

Color getColor(String? kanbanState) {
  if (kanbanState == null) {
    // Was the page background (#F3F3F3) used as an icon tint — nearly
    // invisible on the light-mode surface it sits on. The other unknown/
    // fallback branch below already uses the right neutral for this.
    return StatusColors.grey;
  }
  switch (kanbanState.toLowerCase()) {
    case 'today':
      return StatusColors.orange;
    case 'planned':
      return StatusColors.green;
    case 'overdue':
      return StatusColors.red;
    case 'cancel':
      return StatusColors.red;
    default:
      return StatusColors.grey;
  }
}

String cleanedError(String error) {
  final errorMessage = error
      .toString()
      .replaceFirst("Exception: ", "")
      .split("message:")
      .last
      .split(",")
      .first
      .trim();
  // Raw Dart type/null errors mean an unexpected server payload; don't show them.
  if (errorMessage.contains('is not a subtype of type') ||
      errorMessage.contains('Null check operator') ||
      errorMessage.startsWith('NoSuchMethodError')) {
    return 'Something went wrong. Please check the details and try again.';
  }
  return errorMessage;
}
