import 'package:mobo_event/features/ticket/model/ticket_prd.dart';

import '../../../core/services/odoo_session_manager.dart';

class TicketServices {
  Future fetchTicketProduct({String? search, int limit = 3}) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();

      final version = session!.odooSession.serverVersion;

      String odooVersion = version;

      final trackingField = (odooVersion == '18' || odooVersion == '19')
          ? 'service_tracking'
          : 'detailed_type';

      final domain = [
        [trackingField, '=', 'event'],
      ];
      if (search != null && search.isNotEmpty) {
        domain.add(['name', 'ilike', search]);
      }

      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain},
      });

      final res = response as List;
      final eventProduct = res
          .map((single) => TicketPrdModel.fromOdoo(single))
          .toList();
      return eventProduct;
    } catch (e) {
      rethrow;
    }
  }

  Future editTicket({
    required int ticketId,
    required int eventId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {
            'event_ticket_ids': [
              [1, ticketId, payload],
            ],
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<int> createTicket({
    required int eventId,
    int? productId,
    String? name,
    double? price,
    DateTime? saleStart,
    DateTime? saleEnd,
    int? seatsMax,
    int? seatsLimit,
  }) async {
    String formatOdooDateTime(DateTime dt) {
      final local = dt.toLocal();
      return "${local.year.toString().padLeft(4, '0')}-"
          "${local.month.toString().padLeft(2, '0')}-"
          "${local.day.toString().padLeft(2, '0')} "
          "${local.hour.toString().padLeft(2, '0')}:"
          "${local.minute.toString().padLeft(2, '0')}:"
          "${local.second.toString().padLeft(2, '0')}";
    }

    try {
      final Map<String, dynamic> data = {'event_id': eventId};

      if (productId != null) data['product_id'] = productId;
      if (name != null && name.isNotEmpty) data['name'] = name;
      if (price != null) data['price'] = price;

      if (saleStart != null) {
        data['start_sale_datetime'] = formatOdooDateTime(saleStart);
      }
      if (saleEnd != null) {
        data['end_sale_datetime'] = formatOdooDateTime(saleEnd);
      }

      if (seatsMax != null) data['seats_max'] = seatsMax;
      if (seatsLimit != null) data['limit_max_per_order'] = seatsLimit;

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.event.ticket',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return result;
    } catch (e) {
      rethrow;
    }
  }
}
