class AttendeeShortModel {
  final int id;
  final String name;
  final String? companyName;
  final int? eventId;
  final String? eventName;
  final String? slotName;
  final String state;
  final String? eventTicketName;
  final String barcode;

  /// What the attendee lists' Group By buckets on. The ids are null — and the
  /// names null or empty — where the field is unset on the registration (Odoo
  /// sends `false`).
  final int? eventTicketId;
  final int? slotId;
  final int? partnerId;
  final String? partnerName;
  final DateTime? createDate;

  AttendeeShortModel({
    required this.id,
    required this.name,
    this.companyName,
    this.eventId,
    this.eventName,
    this.slotName,
    this.eventTicketName,
    required this.state,
    required this.barcode,
    this.eventTicketId,
    this.slotId,
    this.partnerId,
    this.partnerName,
    this.createDate,
  });

  /// `create_date` arrives as UTC text, `2026-10-01 09:30:00`.
  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z')?.toLocal();
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  static String? _many2oneName(dynamic value) {
    if (value is List && value.length > 1) {
      return _stringOrNull(value[1]);
    }
    return null;
  }

  static int? _many2oneId(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value[0];
    }
    return null;
  }

  factory AttendeeShortModel.fromJson(Map<String, dynamic> json) {
    final event = json['event_id'];
    final slot = json['event_slot_id'];

    return AttendeeShortModel(
      id: json['id'] ?? 0,
      name: _stringOrNull(json['name']) ?? '',
      companyName: _stringOrNull(json['company_name']),
      eventId: _many2oneId(event),
      eventName: _many2oneName(event),
      slotName: _many2oneName(slot),
      eventTicketName: _many2oneName(json['event_ticket_id']),
      barcode: json['barcode'],
      state: _stringOrNull(json['state']) ?? '',
      eventTicketId: _many2oneId(json['event_ticket_id']),
      slotId: _many2oneId(slot),
      partnerId: _many2oneId(json['partner_id']),
      partnerName: _many2oneName(json['partner_id']),
      createDate: _dateTimeOrNull(json['create_date']),
    );
  }
}
