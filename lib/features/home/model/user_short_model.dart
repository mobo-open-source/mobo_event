import 'dart:typed_data';

class UserShortModel {
  final int? userId;
  final Uint8List? image;
  final String? name;

  UserShortModel({this.userId, this.image, this.name});

  factory UserShortModel.fromJson(Map<String, dynamic> json) {
    return UserShortModel(
      userId: json['user_id'],
      image: json['image'] != null
          ? Uint8List.fromList(List<int>.from(json['image']))
          : null,
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'image': image, 'name': name};
  }
}
