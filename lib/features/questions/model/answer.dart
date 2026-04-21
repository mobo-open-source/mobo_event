class EventAnswer {
  final int id;
  final String name;

  EventAnswer({
    required this.id,
    required this.name,
  });

  factory EventAnswer.fromJson(Map<String, dynamic> json) {
    return EventAnswer(
      id: json['id'],
      name: json['display_name']!=false? json['display_name']:'',
    );
  }
}
