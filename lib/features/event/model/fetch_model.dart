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
}
