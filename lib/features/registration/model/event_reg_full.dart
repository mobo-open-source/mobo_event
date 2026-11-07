class RegistrationFullModel {
  final int id;
  final bool active;
  final String state;
  final String name;
  final String email;
  final String phone;
  final SimpleRef? visitorId;
  final String? companyName;
  final SimpleRef? eventId;
  final SimpleRef? eventSlotId;
  final SimpleRef? eventTicketId;
  final SimpleRef? campaign;
  final SimpleRef? medium;
  final SimpleRef? source;
  final String barcode;
  final SimpleRef? partnerId;
  final DateTime? createDate;
  final DateTime? dateClosed;
  final String saleStatus;
  final bool isMultiSlots;
  final String displayName;
  final List<RegistrationAnswer> registrationAnswers;

  RegistrationFullModel({
    required this.id,
    required this.active,
    required this.state,
    required this.name,
    required this.email,
    required this.phone,
    this.visitorId,
    this.companyName,
    this.eventId,
    this.eventSlotId,
    this.eventTicketId,
    this.campaign,
    this.medium,
    this.source,
    required this.barcode,
    this.partnerId,
    this.createDate,
    this.dateClosed,
    required this.saleStatus,
    required this.isMultiSlots,
    required this.displayName,
    required this.registrationAnswers,
  });

  factory RegistrationFullModel.fromJson(Map<String, dynamic> json) {
    return RegistrationFullModel(
      id: _int(json['id']),
      active: _bool(json['active']),
      state: _string(json['state']),
      name: _string(json['display_name']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      visitorId: _ref(json['visitor_id']),
      companyName: _nullableString(json['company_name']),
      eventId: _ref(json['event_id']),
      campaign: _ref(json['utm_campaign_id']),
      medium: _ref(json['utm_medium_id']),
      source: _ref(json['utm_source_id']),

      eventSlotId: _ref(json['event_slot_id']),
      eventTicketId: _ref(json['event_ticket_id']),
      barcode: _string(json['barcode']),
      partnerId: _ref(json['partner_id']),
      createDate: _parseDate(json['create_date']),
      dateClosed: _parseDate(json['date_closed']),
      saleStatus: _string(json['sale_status']),
      isMultiSlots: _bool(json['is_multi_slots']),
      displayName: _string(json['display_name']),
      registrationAnswers: _parseAnswers(json['registration_answer_ids']),
    );
  }

  static List<RegistrationAnswer> _parseAnswers(dynamic value) {
    if (value == null || value == false) return [];

    if (value is List) {
      return value.map((e) {

        if (e is Map<String, dynamic>) {
          return RegistrationAnswer.fromJson(e);
        }

        if (e is int) {
          return RegistrationAnswer(
            id: e,
            question: null,
            questionType: '',
          );
        }

        return RegistrationAnswer(
          id: 0,
          question: null,
          questionType: '',
        );
      }).toList();
    }

    return [];
  }

  static String _string(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  static String? _nullableString(dynamic value) {
    if (value == null || value == false) return null;
    return value.toString();
  }

  static bool _bool(dynamic value) {
    if (value == null || value == false) return false;
    return value == true;
  }

  static int _int(dynamic value) {
    if (value == null || value == false) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static SimpleRef? _ref(dynamic value) {
    if (value == null || value == false) return null;

    if (value is Map<String, dynamic>) {
      return SimpleRef.fromJson(value);
    }

    if (value is int) {
      return SimpleRef(id: value, displayName: '');
    }

    if (value is List && value.length >= 2) {
      return SimpleRef(
        id: value[0],
        displayName: value[1]?.toString() ?? '',
      );
    }

    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value == false) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
class SimpleRef {
  final int id;
  final String displayName;

  SimpleRef({
    required this.id,
    required this.displayName,
  });

  factory SimpleRef.fromJson(Map<String, dynamic> json) {
    return SimpleRef(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? '',
    );
  }
}
class RegistrationAnswer {
  final int id;
  final SimpleRef? question;
  final String questionType;
  final dynamic valueAnswerId;
  final dynamic valueTextBox;

  RegistrationAnswer({
    required this.id,
    this.question,
    required this.questionType,
    this.valueAnswerId,
    this.valueTextBox,
  });

  factory RegistrationAnswer.fromJson(Map<String, dynamic> json) {
    return RegistrationAnswer(
      id: json['id'] ?? 0,
      question: RegistrationFullModel._ref(json['question_id']),
      questionType: json['question_type'] ?? '',
      valueAnswerId:
      json['value_answer_id'] == false ? null : json['value_answer_id'],
      valueTextBox:
      json['value_text_box'] == false ? null : json['value_text_box'],
    );
  }

  /// helper getter for UI
  String get answerText {
    if (valueAnswerId is List && valueAnswerId.length >= 2) {
      return valueAnswerId[1].toString();
    }
    if (valueTextBox != null) {
      return valueTextBox.toString();
    }
    return '';
  }

  String get questionText {
    return question?.displayName ?? '';
  }
}

