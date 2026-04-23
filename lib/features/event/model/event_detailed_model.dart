import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';


/// Model class for event details
class EventDetailedModel {
  final int id;
  final String name;
  final DateTime start;
  final DateTime end;
  final DateTime startWithTimezone;
  final DateTime endWithTimezone;
  final String location;
  final int attended;
  final int maxSeats;
  final int slotCount;
  final int seatsAvailable;
  final int organizerId;
  final String organizerName;
  final int stageId;
  final String stage;
  final String kanbanState;
  final String? activityState;
  final int? userId;
  final String? username;
  final String? language;
  final bool isMultiSlots;
  final bool seatsLimited;
  final bool websiteMenu;
  final bool? boothMenu;
  final bool? websiteTrack;
  final bool? websiteTrackProposal;
  final bool? exhibitoryMenu;
  final Uint8List? image;
  final List<dynamic>? activityIds;
  final List<dynamic>? addressIds;
  final List<dynamic>? websiteIds;
  final List<dynamic>? activityType;
  final String? activityTypeIcon;
  final String? activitySummary;
  final bool isPublished;
  final bool websitePublished;
  final String websiteUrl;
  final String websiteAbsoluteUrl;
  final String visibility;
  final String template;
  final int? templateId;
  final String timezone;
  final String venueName;
  final String venueAddress;
  final String country;
  final String badgeFormat;
  final Uint8List? badgeImage;
  final String? ticketInstructions;
  final String? note;
  final String? onlineUrl;
  final List<dynamic>? company;
  final List<dynamic>? website;
  final List<dynamic>? tagIds;
  final int seatTaken;



  EventDetailedModel({

    this.username,
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
    required this.websiteIds,
    required this.websiteMenu,
     this.boothMenu,
     this.websiteTrack,
     this.websiteTrackProposal,
     this.exhibitoryMenu,
    this.templateId,
    this.website,
    this.onlineUrl,
    required this.startWithTimezone,
    required this.endWithTimezone,
    required this.seatTaken,

    required this.kanbanState,
    this.activityState,
    this.userId,
    this.image,
    this.activityIds,
    this.addressIds,
    this.company,
    required this.slotCount,
    required this.seatsAvailable,

    this.activityType,
    this.activityTypeIcon,
    this.activitySummary,
    this.language,
    required this.isMultiSlots,
    required this.seatsLimited,
    required this.badgeFormat,
    this.badgeImage,
    this.ticketInstructions,
    this.note,
    this.tagIds,



    required this.isPublished,
    required this.websitePublished,
    required this.websiteUrl,
    required this.websiteAbsoluteUrl,
    required this.visibility,
    required this.template,
    required this.timezone,
    required this.venueName,
    required this.venueAddress,
    required this.country,
  });

  static String _safeString(dynamic v) {
    if (v == null|| v== false) return '';

    String s = v.toString();


    s = s.replaceAll(RegExp(r'<[^>]*>'), '');

    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return s.trim();
  }

  static String? _safeNullableString(dynamic v) => v is String ? v : null;
  static int _safeInt(dynamic v) => v is int ? v : 0;
  static bool _safeBool(dynamic v) => v is bool ? v : false;
  static bool? _safeBoolweb(dynamic v) => v is bool ? v : null;




  static Uint8List? _safeImage(dynamic v) {
    if (v is String && v.isNotEmpty) {
      try {
        return base64Decode(v);
      } catch (e) {
      }
    }
    return null;
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

  factory EventDetailedModel.fromJson(Map<String, dynamic> json) {
    return EventDetailedModel(
      id: _safeInt(json['id']),
      slotCount: _safeInt(json['event_slot_count']),
      seatsAvailable: _safeInt(json['seats_available']),
      websiteMenu: _safeBool(json['website_menu']),
      boothMenu: _safeBoolweb(json['booth_menu']),
      websiteTrack: _safeBoolweb(json['website_track']),
      websiteTrackProposal: _safeBoolweb(json['website_track_proposal']),
      exhibitoryMenu: _safeBoolweb(json['exhibitor_menu']),
      name: _safeString(json['display_name'] ?? json['name']),
      start: _safeDate(json['date_begin']),
      end: _safeDate(json['date_end']),
      location: _safeString(json['address_name'] ),
      attended: _safeInt(json['seats_taken']),
      maxSeats: _safeInt(json['seats_max']),
      organizerId: json['organizer_id'] is List ? _safeInt(json['organizer_id'][0]) : 0,
      organizerName: json['organizer_id'] is List ? _safeString(json['organizer_id'][1]) : '',
      stageId: json['stage_id'] is List ? _safeInt(json['stage_id'][0]) : 0,
      websiteIds: json['website_id']!=false?json['website_id']:[],
      stage: json['stage_id'] is List ? _safeString(json['stage_id'][1]) : '',
      kanbanState: _safeString(json['kanban_state']),
      activityState: _safeNullableString(json['activity_state']),
      userId: json['user_id'] is List ? _safeInt(json['user_id'][0]) : null,
      username: json['user_id'] is List ? json['user_id'][1] : null,
      activityIds: json['activity_ids'] is List ? json['activity_ids'] : [],
      activityType: json['activity_type_id'] is List ? json['activity_type_id'] : [],
      activityTypeIcon: _safeNullableString(json['activity_type_icon']),
      activitySummary: _safeNullableString(json['activity_summary']),
      isPublished: _safeBool(json['is_published']),
      websitePublished: _safeBool(json['website_published']),
      websiteUrl: _safeString(json['website_url']),
      websiteAbsoluteUrl: _safeString(json['website_absolute_url']),
      seatTaken: json['seats_taken'],

      visibility: _safeString(json['website_visibility']),
      template: json['event_type_id'] is List ? json['event_type_id'][1] : '',
      timezone: _safeString(json['date_tz']),
      venueName: _safeString(json['address_name']),
      venueAddress: _safeString(json['address_inline']),
      country: json['country_id'] is List ? json['country_id'][1] : '',
      image: _safeImage(json['image_1024']!= false ?json['image_1024']:null ),
      language: json['lang'] is String ? json['lang'] : null,
      isMultiSlots: _safeBool(json['is_multi_slots']),
      seatsLimited: _safeBool(json['seats_limited']),
      badgeFormat: _safeString(json['badge_format']),
      badgeImage: _safeImage(json['badge_image']),
      ticketInstructions: _safeString(json['ticket_instructions']),
      note: _safeString(json['note']),
      onlineUrl: _safeString(json['event_url']),
      addressIds: json['address_id'] is List ? json['address_id'] : [],
      company: json['company_id'] !=false ? json['company_id'] : [],
      templateId: json['event_type_id'] is List ? json['event_type_id'][0] : 0,
      website: json['website_id'] !=false ? json['website_id'] : [],
      tagIds: json['tag_ids'] is List ? json['tag_ids'] : [],
      startWithTimezone: DateTime.parse(json['date_begin']),
      endWithTimezone: DateTime.parse(json['date_end']),




    );
  }
}
extension EventDetailedModelFormat on EventDetailedModel {
  String get monthShort => DateFormat('MMM').format(start);
  String get day => DateFormat('dd').format(start);
  String get startTime => DateFormat('hh:mm a').format(start);
  String get endTime => DateFormat('hh:mm a').format(end);
  String get startFullDate => DateFormat('dd MMM yyyy').format(start);
  String get endFullDate => DateFormat('dd MMM yyyy').format(end);

  String get attendedText =>
      maxSeats == 0 ? "$attended / ∞" : "$attended / $maxSeats";

  bool get hasActivity => activityState != null;
}
