class AttendeeModel {
  final int id;
  final String name;
   String? slotName;
  final String ticketName;
  final int eventId;
  final String eventDisplayName;
  final List<dynamic> registrationAnswers;
  final String companyName;
  final String status;

  AttendeeModel({
    required this.id,
    required this.name,
     this.slotName,
    required this.ticketName,
    required this.eventId,
    required this.eventDisplayName,
    required this.registrationAnswers,
    required this.companyName,
    required this.status,
  });

  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      id: json['id'],
      name: json['name'],
      slotName: json['slot_name']!=false?json['slot_name']:'',
      ticketName: json['ticket_name']!=false? json['ticket_name']:"",
      eventId: json['event_id']!= false ?json['event_id']:0,
      eventDisplayName: json['event_display_name']!=false?json['event_display_name']:'',
      registrationAnswers: json['registration_answers']!=false? json['registration_answers'] : [],
      companyName: json['company_name']!=false? json['company_name']:'',
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slot_name': slotName,
      'ticket_name': ticketName,
      'event_id': eventId,
      'event_display_name': eventDisplayName,
      'registration_answers': registrationAnswers,
      'company_name': companyName,
      'status': status,
    };
  }
}
