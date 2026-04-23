
import 'package:intl/intl.dart';

class EventTicket {
  final int? id;
  final String? displayName;
  final String? name;
  final String? description;

  final bool? seatsLimited;
  final int? seatsMax;

  final int? productId;
  final String? productName;
  final double? price;
  final double? priceReduce;

  final DateTime? startSaleDatetime;
  final DateTime? endSaleDatetime;

  final bool? saleAvailable;
  final int? seatsAvailable;
  final int? seatsUsed;
  final int? seatsTaken;

  final int? limitMaxPerOrder;
  final String? color;
  final double? priceReduceTaxInc;
  final double? priceIncl;

  EventTicket({
    this.id,
    this.displayName,
    this.name,
    this.description,
    this.seatsLimited,
    this.seatsMax,
    this.productId,
    this.productName,
    this.price,
    this.priceReduce,
    this.startSaleDatetime,
    this.endSaleDatetime,
    this.saleAvailable,
    this.seatsAvailable,
    this.seatsUsed,
    this.seatsTaken,
    this.limitMaxPerOrder,
    this.color,
    this.priceReduceTaxInc,
    this.priceIncl,
  });

  static DateTime? _safeDate(dynamic v) {
    try {
      String? dateStr;

      if (v is String && v.isNotEmpty) {
        dateStr = v;
      } else if (v is List && v.isNotEmpty && v.first is String) {
        dateStr = v.first;
      }

      if (dateStr != null) {
        return DateTime.parse(dateStr.replaceAll(' ', 'T'));
      }
    } catch (e) {
      }
    return null;
  }

  factory EventTicket.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? prod = json['product_id'];

    return EventTicket(
      id: json['id'],
      displayName: json['display_name'],
      name: json['name'],
      description: json['description'] != false
          ? json['description']
          : null,

      seatsLimited: json['seats_limited'],
      seatsMax: json['seats_max'],

      productId: (prod != null && prod.isNotEmpty) ? prod[0] : null,
      productName: (prod != null && prod.length > 1) ? prod[1] : null,

      price: (json['price'] != null)
          ? (json['price'] as num).toDouble()
          : null,

      priceReduce: (json['price_reduce'] != null)
          ? (json['price_reduce'] as num).toDouble()
          : null,

      startSaleDatetime: json['start_sale_datetime'] != false
          ? _safeDate(json['start_sale_datetime'])
          : null,

      endSaleDatetime: json['end_sale_datetime'] != false
          ? _safeDate(json['end_sale_datetime'])
          : null,

      saleAvailable: json['sale_available'],
      seatsAvailable: json['seats_available'],
      seatsUsed: json['seats_used'],
      seatsTaken: json['seats_taken'],

      limitMaxPerOrder: json['limit_max_per_order'],
      color: json['color'],

      priceReduceTaxInc: (json['price_reduce_taxinc'] != null)
          ? (json['price_reduce_taxinc'] as num).toDouble()
          : null,

      priceIncl: (json['price_incl'] != null)
          ? (json['price_incl'] as num).toDouble()
          : null,
    );
  }
}

extension DateFormate on EventTicket {
  String get startSales =>
      startSaleDatetime != null
          ? DateFormat('dd MMM yyyy').format(startSaleDatetime!)
          : "No starting";

  String get endSales =>
      endSaleDatetime != null
          ? DateFormat('dd MMM yyyy').format(endSaleDatetime!)
          : "No ending";
}
