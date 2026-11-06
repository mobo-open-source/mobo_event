import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:mobo_event/core/utils/odoo_binary.dart';

class EventShort {
  final int id;
  final String name;
  final DateTime start;
  final DateTime end;
  final String location;
  final int attended;
  final int maxSeats;
  final int organizerId;
  final String organizerName;
  final int stageId;
  final String stage;
  final String kanbanState;
  final String? activityState;
  final int? userId;

  /// Responsible user's name, template and venue — what the list's Group By
  /// buckets on. Empty (and the id 0, like [userId]) when the field is unset on
  /// the event: Odoo sends `false`. Zero rather than null so [copyWith] can
  /// clear them when a card is dropped on a "none" column.
  final String userName;
  final int templateId;
  final String templateName;
  final int venueId;
  final String venueName;
  final Uint8List? image;
  final Uint8List? eventImage;
  final List<dynamic>? activityIds;
  final List<dynamic>? activityType;
  final String? activityTypeIcon;
  final String? activitySummary;
  final String? timeZone;
  EventShort({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.location,
    required this.attended,
    required this.maxSeats,
    required this.organizerId,
    required this.organizerName,
    required this.stageId,
    required this.stage,
    required this.kanbanState,
    this.activityState,
    this.userId,
    this.userName = '',
    this.templateId = 0,
    this.templateName = '',
    this.venueId = 0,
    this.venueName = '',
    this.image,
    this.eventImage,
    this.activityIds,
    this.activityType,
    this.activityTypeIcon,
    this.activitySummary,
    this.timeZone,
  });

  static String _safeString(dynamic v) => v is String ? v : '';
  static String? _safeNullableString(dynamic v) => v is String ? v : null;
  static int _safeInt(dynamic v) => v is int ? v : 0;
  /// A binary field is base64 text through Odoo 19 and a `{content, size}`
  /// object from 20 — see [OdooBinary].
  static Uint8List? _safeImage(dynamic v) => OdooBinary.bytes(v);

  /// A many2one comes back as `[id, name]`, or `false` when unset.
  static int _relationId(dynamic v) =>
      v is List && v.isNotEmpty && v.first is int ? v.first as int : 0;
  static String _relationName(dynamic v) =>
      v is List && v.length > 1 && v[1] is String ? v[1] as String : '';

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
    } catch (_) {}
    return DateTime.now();
  }

  factory EventShort.fromJson(Map<String, dynamic> json) {
    return EventShort(
      activityType: json['activity_type_id'] != false
          ? json['activity_type_id']
          : [],
      activityIds: json['activity_ids'] != false ? json['activity_ids'] : 0,
      activityTypeIcon: json['activity_type_icon'] != false
          ? json['activity_type_icon']
          : '',
      activitySummary: json['activity_summary'] != false
          ? json['activity_summary']
          : '',
      id: _safeInt(json['id']),
      name: _safeString(json['display_name']),
      start: _safeDate(json['date_begin']),
      end: _safeDate(json['date_end']),
      // Odoo 20 renamed event.event.address_inline to contact_address_inline.
      location: _safeString(
        json['contact_address_inline'] ??
            json['address_inline'] ??
            json['address_name'],
      ),
      attended: _safeInt(json['seats_taken']),
      maxSeats: _safeInt(json['seats_max']),

      organizerId: json['organizer_id'] is List
          ? _safeInt(json['organizer_id'][0])
          : 0,
      organizerName: json['organizer_id'] is List
          ? _safeString(json['organizer_id'][1])
          : '',

      stageId: json['stage_id'] is List ? _safeInt(json['stage_id'][0]) : 0,
      stage: json['stage_id'] is List ? _safeString(json['stage_id'][1]) : '',
      eventImage: _safeImage(
        json['image_1024'] != false ? json['image_1024'] : null,
      ),

      kanbanState: _safeString(json['kanban_state']),
      activityState: _safeNullableString(json['activity_state']),

      userId: json['user_id'] is List
          ? _safeInt(json['user_id'][0])
          : _safeInt(json['user_id']),
      userName: _relationName(json['user_id']),
      templateId: _relationId(json['event_type_id']),
      templateName: _relationName(json['event_type_id']),
      venueId: _relationId(json['address_id']),
      venueName: _relationName(json['address_id']),

      timeZone: json['date_tz'],
    );
  }

  EventShort copyWith({
    int? id,
    String? name,
    DateTime? start,
    DateTime? end,
    String? location,
    int? attended,
    int? maxSeats,
    int? organizerId,
    String? organizerName,
    int? stageId,
    String? stage,
    String? kanbanState,
    String? activityState,
    int? userId,
    String? userName,
    int? templateId,
    String? templateName,
    int? venueId,
    String? venueName,
    String? timeZone,
    Uint8List? image,
    List<dynamic>? activityIds,
    List<dynamic>? activityType,
    String? activityTypeIcon,
    String? activitySummary,
    Uint8List? eventImage,
  }) {
    return EventShort(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      attended: attended ?? this.attended,
      maxSeats: maxSeats ?? this.maxSeats,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      stageId: stageId ?? this.stageId,
      stage: stage ?? this.stage,
      kanbanState: kanbanState ?? this.kanbanState,
      activityState: activityState ?? this.activityState,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      timeZone: timeZone ?? this.timeZone,
      image: image ?? this.image,
      eventImage: eventImage ?? this.eventImage,
      activityIds: activityIds ?? this.activityIds,
      activitySummary: activitySummary ?? this.activitySummary,
      activityType: activityType ?? this.activityType,
      activityTypeIcon: activityTypeIcon ?? this.activityTypeIcon,
    );
  }
}

extension EventShortFormat on EventShort {
  String get monthShort => DateFormat('MMMM').format(start);
  String get day => DateFormat('dd').format(start);
  String get timeRange => DateFormat('hh:mm a').format(start);
  String get fullDate => DateFormat('dd MMM yyyy').format(start);

  String get attendedText =>
      maxSeats == 0 ? "$attended / ∞" : "$attended / $maxSeats";

  bool get hasActivity => activityState != null;
}
