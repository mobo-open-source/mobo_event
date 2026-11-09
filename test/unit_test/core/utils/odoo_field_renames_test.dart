import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';

/// Odoo 20 renamed a few fields the app reads. Models are parsed from
/// `search_read` rows with no field list, so the server answers with whichever
/// name it has and a model that only knows the old one silently shows blank.
void main() {
  group('event.event venue address', () {
    Map<String, dynamic> shortRow(Map<String, dynamic> extra) => {
      'activity_type_id': false,
      'activity_ids': [],
      'activity_type_icon': false,
      'activity_summary': false,
      'id': 7,
      'display_name': 'Conference',
      'date_begin': '2026-10-01 09:00:00',
      'date_end': '2026-10-02 17:00:00',
      ...extra,
    };

    test('Odoo 20 reports contact_address_inline', () {
      final event = EventShort.fromJson(
        shortRow({'contact_address_inline': 'Main St 1, Springfield'}),
      );
      expect(event.location, 'Main St 1, Springfield');
    });

    test('Odoo 17-19 report address_inline', () {
      final event = EventShort.fromJson(
        shortRow({'address_inline': 'Main St 1, Springfield'}),
      );
      expect(event.location, 'Main St 1, Springfield');
    });

    test('an online event (no venue) still has an empty location', () {
      final event = EventShort.fromJson(
        shortRow({'contact_address_inline': false}),
      );
      expect(event.location, '');
    });

    test('the detail screen reads the same renamed field', () {
      Map<String, dynamic> detailRow(Map<String, dynamic> extra) => {
        'id': 7,
        'display_name': 'Conference',
        'date_begin': '2026-10-01 09:00:00',
        'date_end': '2026-10-02 17:00:00',
        'seats_taken': 0,
        'website_id': false,
        'company_id': false,
        ...extra,
      };

      final event = EventDetailedModel.fromJson(
        detailRow({'contact_address_inline': 'Main St 1, Springfield'}),
      );
      expect(event.venueAddress, 'Main St 1, Springfield');

      final legacy = EventDetailedModel.fromJson(
        detailRow({'address_inline': 'Main St 1, Springfield'}),
      );
      expect(legacy.venueAddress, 'Main St 1, Springfield');
    });
  });

  group('event.event.ticket tax-included prices', () {
    test('Odoo 20 reports total_price_* (event_product)', () {
      final ticket = EventTicket.fromJson({
        'id': 1,
        'name': 'Standard',
        'total_price_reduce_taxinc': 115.0,
        'total_price_incl': 120,
      });
      expect(ticket.priceReduceTaxInc, 115.0);
      expect(ticket.priceIncl, 120.0);
    });

    test('Odoo 17-19 report price_reduce_taxinc / price_incl', () {
      final ticket = EventTicket.fromJson({
        'id': 1,
        'name': 'Standard',
        'price_reduce_taxinc': 115.0,
        'price_incl': 120,
      });
      expect(ticket.priceReduceTaxInc, 115.0);
      expect(ticket.priceIncl, 120.0);
    });

    test('no price fields at all (no product module) stays null', () {
      final ticket = EventTicket.fromJson({'id': 1, 'name': 'Free'});
      expect(ticket.priceReduceTaxInc, isNull);
      expect(ticket.priceIncl, isNull);
    });

    test('a false value is treated as absent, not cast', () {
      final ticket = EventTicket.fromJson({
        'id': 1,
        'name': 'Free',
        'total_price_incl': false,
      });
      expect(ticket.priceIncl, isNull);
    });
  });
}
