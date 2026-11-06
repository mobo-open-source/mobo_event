class ActivityTypeModel {
  final int id;
  final String name;

  ActivityTypeModel({
    required this.id,
    required this.name,
  });

  factory ActivityTypeModel.fromJson(Map<String, dynamic> json) {
    return ActivityTypeModel(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }

  /// Records are the same activity type when their ids match, so a picker
  /// recognises the selected one among freshly loaded options.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ActivityTypeModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
