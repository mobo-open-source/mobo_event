class TicketPrdModel {
  final int id;
  final String name;
  final double? price;
  final String? type;

  TicketPrdModel({
    required this.id,
    required this.name,
    this.price,
    this.type,

  });

  factory TicketPrdModel.fromOdoo(Map<String, dynamic> json) {
    return TicketPrdModel(
      id: json['id'],
      name: json['name'],
      price: (json['list_price'] as num?)?.toDouble(),
      type: json['type'],

    );
  }

  Map<String, dynamic> toOdoo() {
    return {
      'id': id,
      'name': name,
      'list_price': price,
      'type': type,
    };
  }
}
