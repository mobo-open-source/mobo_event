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

  /// Records are the same template when their ids match, so a picker
  /// recognises the selected one among freshly loaded options.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TemplateModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
