/// Event slot model
class EventSlotModel {
  final int id;
  final String displayName;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final int color;
  final String dateTz;

  EventSlotModel({
    required this.displayName,
    required this.startDatetime,
    required this.endDatetime,
    required this.color,
    required this.dateTz,
    required this.id
  });


  factory EventSlotModel.fromJson(Map<String, dynamic> json) {
    return EventSlotModel(
      displayName: json['display_name'] ?? '',
      startDatetime: _safeDate (json['start_datetime']),
      endDatetime: _safeDate(json['end_datetime']),
      color: json['color'] ?? 0,
      dateTz: json['date_tz'] ?? '',
      id: json['id']
    );
  }


  static DateTime _safeDate(dynamic v) {
    try {
      String? dateStr;
      if (v is String && v.isNotEmpty) {
        dateStr = v;
      } else if (v is List && v.isNotEmpty && v.first is String) {
        dateStr = v.first;
      }
      if (dateStr != null) {
        String cleaned = dateStr.split('.').first.replaceAll(' ', 'T');
        if (!cleaned.endsWith('Z') && !cleaned.contains('+')) {
          cleaned = '${cleaned}Z';
        }

        return DateTime.parse(cleaned).toLocal();
      }
    } catch (e) {
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'start_datetime': startDatetime.toIso8601String(),
      'end_datetime': endDatetime.toIso8601String(),
      'color': color,
      'date_tz': dateTz,
    };
  }
}
