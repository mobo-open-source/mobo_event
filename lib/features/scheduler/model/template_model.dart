class TemplateModel {
  final int id;
  final String name;

  TemplateModel({
    required this.id,
    required this.name,
  });


  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
