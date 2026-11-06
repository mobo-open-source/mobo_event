class FetchModel {
  final int id;
  final String? name;
  FetchModel({required this.id, this.name});

  factory FetchModel.fromJson(Map<String, dynamic> json) {
    return FetchModel(
      id: json['id'] as int,
      name: json['display_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  /// Compared by record id, so a picker recognises the value it was handed
  /// among options it loaded itself (a separate object for the same record).
  @override
  bool operator ==(Object other) => other is FetchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
