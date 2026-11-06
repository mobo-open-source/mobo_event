import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/utils/odoo_binary.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/home/model/event_short.dart';

void main() {
  // A 1x1 transparent PNG, the smallest realistic payload.
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  group('OdooBinary.base64', () {
    test('Odoo 17-19: the field is the base64 text itself', () {
      expect(OdooBinary.base64(png), png);
    });

    test('Odoo 20: the field is a {content, size} object', () {
      expect(OdooBinary.base64({'content': png, 'size': 68}), png);
      expect(
        OdooBinary.base64({'filename': 'me.png', 'content': png, 'size': 68}),
        png,
      );
    });

    test('an empty field is null on every release', () {
      expect(OdooBinary.base64(false), isNull);
      expect(OdooBinary.base64(null), isNull);
      expect(OdooBinary.base64(''), isNull);
      expect(OdooBinary.base64('   '), isNull);
      expect(OdooBinary.base64('false'), isNull);
    });

    test('an object with no content is not an image', () {
      // What a server sends when it reports only the size.
      expect(OdooBinary.base64({'size': 68, 'checksum': 'abc'}), isNull);
      expect(OdooBinary.base64({'content': false, 'size': 0}), isNull);
      expect(OdooBinary.base64({}), isNull);
    });

    test('anything else is ignored rather than stringified', () {
      expect(OdooBinary.base64(12), isNull);
      expect(OdooBinary.base64([png]), isNull);
    });
  });

  group('OdooBinary.bytes', () {
    test('decodes both shapes to the same bytes', () {
      final expected = base64Decode(png);
      expect(OdooBinary.bytes(png), expected);
      expect(OdooBinary.bytes({'content': png, 'size': 68}), expected);
    });

    test('invalid base64 is null, not an exception', () {
      expect(OdooBinary.bytes('not base64 !!'), isNull);
      expect(OdooBinary.bytes({'content': '%%%'}), isNull);
    });

    test('empty is null', () {
      expect(OdooBinary.bytes(false), isNull);
      expect(OdooBinary.bytes(null), isNull);
    });
  });

  group('models parse an Odoo 20 binary field', () {
    test('EventShort event cover', () {
      final event = EventShort.fromJson({
        'activity_type_id': false,
        'activity_ids': [],
        'activity_type_icon': false,
        'activity_summary': false,
        'id': 7,
        'display_name': 'Conference',
        'date_begin': '2026-10-01 09:00:00',
        'date_end': '2026-10-02 17:00:00',
        'image_1024': {'content': png, 'size': 68},
      });
      expect(event.eventImage, base64Decode(png));
    });

    test('EventDetailedModel cover and badge image', () {
      final event = EventDetailedModel.fromJson({
        'id': 7,
        'display_name': 'Conference',
        'date_begin': '2026-10-01 09:00:00',
        'date_end': '2026-10-02 17:00:00',
        'seats_taken': 0,
        'website_id': false,
        'company_id': false,
        'image_1024': {'content': png, 'size': 68},
        'badge_image': {'content': png, 'size': 68},
      });
      expect(event.image, base64Decode(png));
      expect(event.badgeImage, base64Decode(png));
    });

    test('the Odoo 19 text form still works', () {
      final event = EventDetailedModel.fromJson({
        'id': 7,
        'display_name': 'Conference',
        'date_begin': '2026-10-01 09:00:00',
        'date_end': '2026-10-02 17:00:00',
        'seats_taken': 0,
        'website_id': false,
        'company_id': false,
        'image_1024': png,
      });
      expect(event.image, base64Decode(png));
    });
  });
}
