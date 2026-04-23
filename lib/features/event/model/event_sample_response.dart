/// Event response model
class EventResponse {
  final EventValue value;

  EventResponse({required this.value});

  factory EventResponse.fromJson(Map<String, dynamic> json) {
    return EventResponse(
      value: EventValue.fromJson(json['value']),
    );
  }

  Map<String, dynamic> toJson() => {
    "value": value.toJson(),
  };
}

class EventValue {

  final DateTime dateBegin;
  final DateTime dateEnd;
  final String dateTz;
  final Company companyId;
  final Company organizerId;
  final User userId;
  final Address addressId;


  EventValue({

    required this.dateBegin,
    required this.dateEnd,
    required this.dateTz,
    required this.companyId,
    required this.organizerId,
    required this.userId,
    required this.addressId,
  });

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

  factory EventValue.fromJson(Map<String, dynamic> json) {
    return EventValue(
      dateBegin: _safeDate(json['date_begin']),
      dateEnd: _safeDate(json['date_end']),
      dateTz: json['date_tz'] ?? "",
      companyId: Company.fromJson(json['company_id']),
      organizerId: Company.fromJson(json['organizer_id']),
      userId: User.fromJson(json['user_id']),
      addressId: Address.fromJson(json['address_id']),

    );
  }

  Map<String, dynamic> toJson() => {

    "date_begin": dateBegin,
    "date_end": dateEnd,
    "date_tz": dateTz,
    "company_id": companyId.toJson(),
    "organizer_id": organizerId.toJson(),
    "user_id": userId.toJson(),
    "address_id": addressId.toJson(),
  };
}

class Stage {
  final int id;
  final String displayName;

  Stage({required this.id, required this.displayName});

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "display_name": displayName,
  };
}

class Company {
  final int id;
  final String displayName;

  Company({required this.id, required this.displayName});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "display_name": displayName,
  };
}

class User {
  final int id;
  final String displayName;

  User({required this.id, required this.displayName});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "display_name": displayName,
  };
}

class Address {
  final int id;
  final String displayName;

  Address({required this.id, required this.displayName});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "display_name": displayName,
  };
}
