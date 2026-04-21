import '../../../core/services/odoo_session_manager.dart';

class DocumentationServices {
  static Map<String, dynamic> buildUpdatePayload({
    String? badge,
    String? notes,
    String? backgroundBase64,
    required bool imageChanged,
    String? ticketInstruction,
  }) {
    final Map<String, dynamic> vals = {};

    if (badge != null) {
      vals['badge_format'] = badge;
    }

    if (notes != null) {
      vals['note'] = notes.trim().isEmpty ? false : notes.trim();
    }

    if (ticketInstruction != null) {
      vals['ticket_instructions'] = ticketInstruction.trim().isEmpty
          ? false
          : ticketInstruction.trim();
    }
    if (imageChanged) {
      vals['badge_image'] =
          (backgroundBase64 == null || backgroundBase64.isEmpty)
          ? false
          : backgroundBase64;
    }

    return vals;
  }

  static Future<bool> update(int eventId, Map<String, dynamic> vals) async {
    try {
      if (vals.isEmpty) return true;

      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          vals,
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
