
import '../../../core/services/odoo_session_manager.dart';

class DocumentationServices {


  /// Build payload for updating document information
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
    /// Check if image has changed
    if (imageChanged) {
      vals['badge_image'] =
          (backgroundBase64 == null || backgroundBase64.isEmpty)
          ? false
          : backgroundBase64;
    }

    return vals;
  }


  /// Update document information
  static Future<bool> update(int eventId, Map<String, dynamic> vals) async {
    try {
      if (vals.isEmpty) return true;

      /// Update document information via Odoo RPC
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
