class EventTypeModel {
  final int id;
  final String displayName;
  final String name;

  final bool hasSeatsLimitation;
  final int seatsMax;
  final String defaultTimezone;

  final bool websiteMenu;
  final bool communityMenu;
  final bool boothMenu;
  final bool exhibitorMenu;
  final bool websiteTrack;
  final bool websiteTrackProposal;

  EventTypeModel({
    required this.id,
    required this.displayName,
    required this.name,
    required this.hasSeatsLimitation,
    required this.seatsMax,
    required this.defaultTimezone,
    required this.websiteMenu,
    required this.communityMenu,
    required this.boothMenu,
    required this.exhibitorMenu,
    required this.websiteTrack,
    required this.websiteTrackProposal,
  });

  factory EventTypeModel.fromJson(Map<String, dynamic> json) {
    return EventTypeModel(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? '',
      name: json['name'] ?? '',

      hasSeatsLimitation: json['has_seats_limitation'] ?? false,
      seatsMax: json['seats_max'] ?? 0,

      defaultTimezone: json['default_timezone'] ?? '',

      websiteMenu: json['website_menu'] ?? false,
      communityMenu: json['community_menu'] ?? false,
      boothMenu: json['booth_menu'] ?? false,
      exhibitorMenu: json['exhibitor_menu'] ?? false,
      websiteTrack: json['website_track'] ?? false,
      websiteTrackProposal: json['website_track_proposal'] ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'name': name,

      'has_seats_limitation': hasSeatsLimitation,
      'seats_max': seatsMax,
      'default_timezone': defaultTimezone,

      'website_menu': websiteMenu,
      'community_menu': communityMenu,
      'booth_menu': boothMenu,
      'exhibitor_menu': exhibitorMenu,
      'website_track': websiteTrack,
      'website_track_proposal': websiteTrackProposal,
    };
  }
}
