
class EventRegistration {
  final int? id;
  final bool active;
  final String state;

  final String? name;
  final String? email;
  final String? phone;
  final String? companyName;

  final OdooRef? visitor;
  final OdooRef? event;
  final OdooRef? slot;
  final OdooRef? ticket;
  final OdooRef? partner;

  final OdooRef? utmCampaign;
  final OdooRef? utmMedium;
  final OdooRef? utmSource;

  final String? barcode;
  final DateTime? createDate;
  final DateTime? dateClosed;

  final String saleStatus;
  final bool isMultiSlots;
  final String displayName;

  EventRegistration({
    this.id,
    required this.active,
    required this.state,
    this.name,
    this.email,
    this.phone,
    this.companyName,
    this.visitor,
    this.event,
    this.slot,
    this.ticket,
    this.partner,
    this.utmCampaign,
    this.utmMedium,
    this.utmSource,
    this.barcode,
    this.createDate,
    this.dateClosed,
    required this.saleStatus,
    required this.isMultiSlots,
    required this.displayName,
  });

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || value == false) return null;
      return DateTime.tryParse(value.toString());
    }

    OdooRef? parseRef(dynamic value) {
      if (value == null || value == false) return null;
      return OdooRef(
        id: value['id'],
        displayName: value['display_name'] ?? '',
      );
    }

    String? parseString(dynamic value) {
      if (value == null || value == false) return null;
      return value.toString();
    }

    return EventRegistration(
      id: json['id'],
      active: json['active'] ?? false,
      state: json['state']!=false?json['state']:'',

      name: parseString(json['name']),
      email: parseString(json['email']),
      phone: parseString(json['phone']),
      companyName: parseString(json['company_name']),

      visitor: parseRef(json['visitor_id']),
      event: parseRef(json['event_id']),
      slot: parseRef(json['event_slot_id']),
      ticket: parseRef(json['event_ticket_id']),
      partner: parseRef(json['partner_id']),

      utmCampaign: parseRef(json['utm_campaign_id']),
      utmMedium: parseRef(json['utm_medium_id']),
      utmSource: parseRef(json['utm_source_id']),

      barcode: parseString(json['barcode']),
      createDate: parseDate(json['create_date']),
      dateClosed: parseDate(json['date_closed']),

      saleStatus: json['sale_status'] ?? '',
      isMultiSlots: json['is_multi_slots'] ?? false,
      displayName: json['display_name'] ?? '',
    );
  }
}

class RegistrationAnswer {
  final int id;
  final int eventId;
  final int questionId;
  final String questionName;
  final String questionType;
  final String? valueText;

  RegistrationAnswer({
    required this.id,
    required this.eventId,
    required this.questionId,
    required this.questionName,
    required this.questionType,
    this.valueText,
  });

  factory RegistrationAnswer.fromJson(Map<String, dynamic> json) {
    return RegistrationAnswer(
      id: json['id'],
      eventId: json['event_id']['id'],
      questionId: json['question_id']['id'],
      questionName: json['question_id']['display_name'],
      questionType: json['question_type'],
      valueText: json['value_text_box'],
    );
  }
}
class OdooRef {
  final int id;
  final String displayName;

  OdooRef({
    required this.id,
    required this.displayName,
  });

  factory OdooRef.fromJson(dynamic json) {
    if (json == false || json == null) return null as OdooRef;

    return OdooRef(
      id: json['id'],
      displayName: json['display_name'] ?? '',
    );
  }
}
