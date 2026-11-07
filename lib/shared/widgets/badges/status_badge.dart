import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Reusable status badge (CLAUDE.md §10 — canonical formula).
///
/// No border, tinted fill, radius 18, 11/w600 text with `letterSpacing: 0.1`.
/// Colour always comes from the [StatusColors] semantic map (§1) — never from a
/// raw Material colour.
class StatusBadge extends StatelessWidget {
  final String status;
  final StatusBadgeStyle? style;

  const StatusBadge({
    super.key,
    required this.status,
    this.style,
  });

  /// Factory for transfer states.
  factory StatusBadge.transfer(String state) {
    return StatusBadge(status: state, style: _getTransferStyle(state));
  }

  /// Factory for order states.
  factory StatusBadge.order(String state) {
    return StatusBadge(status: state, style: _getOrderStyle(state));
  }

  /// Factory for invoice states.
  factory StatusBadge.invoice(String state) {
    return StatusBadge(status: state, style: _getInvoiceStyle(state));
  }

  static StatusBadgeStyle _getTransferStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return const StatusBadgeStyle(
          label: 'Draft',
          color: StatusColors.orange,
        );
      case 'waiting':
      case 'confirmed':
        return const StatusBadgeStyle(
          label: 'Waiting',
          color: StatusColors.orange,
        );
      case 'assigned':
        return const StatusBadgeStyle(
          label: 'Ready',
          color: StatusColors.blue,
        );
      case 'done':
        return const StatusBadgeStyle(
          label: 'Done',
          color: StatusColors.green,
        );
      case 'cancel':
      case 'cancelled':
        return const StatusBadgeStyle(
          label: 'Cancelled',
          color: StatusColors.red,
        );
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getOrderStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return const StatusBadgeStyle(
          label: 'Draft',
          color: StatusColors.orange,
        );
      case 'sent':
        return const StatusBadgeStyle(
          label: 'Sent',
          color: StatusColors.blue,
        );
      case 'sale':
        return const StatusBadgeStyle(
          label: 'Sale Order',
          color: StatusColors.green,
        );
      case 'done':
        return const StatusBadgeStyle(
          label: 'Done',
          color: StatusColors.green,
        );
      case 'cancel':
        return const StatusBadgeStyle(
          label: 'Cancelled',
          color: StatusColors.red,
        );
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getInvoiceStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return const StatusBadgeStyle(
          label: 'Draft',
          color: StatusColors.orange,
        );
      case 'posted':
        return const StatusBadgeStyle(
          label: 'Posted',
          color: StatusColors.green,
        );
      case 'paid':
        return const StatusBadgeStyle(
          label: 'Paid',
          color: StatusColors.green,
        );
      case 'cancel':
        return const StatusBadgeStyle(
          label: 'Cancelled',
          color: StatusColors.red,
        );
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeStyle =
        style ?? StatusBadgeStyle(label: status, color: StatusColors.grey);

    return StatusColors.buildStatusBadge(
      context,
      badgeStyle.label,
      color: badgeStyle.color,
    );
  }
}

class StatusBadgeStyle {
  final String label;
  final Color color;

  const StatusBadgeStyle({
    required this.label,
    required this.color,
  });
}
