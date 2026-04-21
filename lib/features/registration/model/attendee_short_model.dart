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
  });

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
    );
  }
}
