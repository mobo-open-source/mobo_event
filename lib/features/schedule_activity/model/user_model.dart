class UserModel {
  final int id;
  final String name;

  UserModel({
    required this.id,
    required this.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }

  /// Records are the same user when their ids match, so a picker recognises
  /// the selected one among freshly loaded options.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
