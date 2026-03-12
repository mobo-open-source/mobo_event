import 'package:intl/intl.dart';

class ActivitiesModel {
  final int id;
  final String? name;
  final String? duedate;
  final List<dynamic> activityType;
  final String? activityIcon;
  final String? note;
  final List<dynamic> userId;
  final String state;

  ActivitiesModel({
    required this.id,
    this.name,
    this.duedate,
    required this.activityType,
    this.activityIcon,
    this.note,
    required this.userId,
    required this.state,
  });

  factory ActivitiesModel.fromJson(Map<String, dynamic> json) {
    return ActivitiesModel(
      id: json['id'],
      name: json['summary'] != false ? json['summary'] : '',
      duedate: json['date_deadline'],
      activityType: json['activity_type_id'] ?? [],
      activityIcon: json['icon'],
      note: json['note'] != false ? json['note'] : '',
      userId: json['user_id'] ?? [],
      state: json['state'] ?? 'planned',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'summary': name,
    'date_deadline': duedate,
    'activity_type_id': activityType,
    'icon': activityIcon,
    'note': note,
    'user_id': userId,
    'state': state,
  };

  String get formattedDueDate {
    if (duedate == null || duedate!.isEmpty) return 'No due date';
    try {
      final dt = DateTime.parse(duedate!);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return duedate!;
    }
  }

  ActivitiesModel copyWith({
    int? id,
    String? name,
    String? duedate,
    List<dynamic>? activityType,
    String? activityIcon,
    String? note,
    List<dynamic>? userId,
    String? state,
  }) {
    return ActivitiesModel(
      id: id ?? this.id,
      name: name ?? this.name,
      duedate: duedate ?? this.duedate,
      activityType: activityType ?? this.activityType,
      activityIcon: activityIcon ?? this.activityIcon,
      note: note ?? this.note,
      userId: userId ?? this.userId,
      state: state ?? this.state,
    );
  }
}
