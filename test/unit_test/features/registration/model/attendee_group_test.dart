import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';
import 'package:mobo_event/features/registration/model/attendee_group.dart';
import 'package:mobo_event/features/registration/model/attendee_short_model.dart';

AttendeeShortModel attendee(
  int id, {
  String state = 'open',
  int? eventId,
  String? eventName,
  int? ticketId,
  String? ticketName,
  int? slotId,
  String? slotName,
  int? partnerId,
  String? partnerName,
  DateTime? createDate,
}) => AttendeeShortModel(
  id: id,
  name: 'Attendee $id',
  state: state,
  barcode: 'b$id',
  eventId: eventId,
  eventName: eventName,
  eventTicketId: ticketId,
  eventTicketName: ticketName,
  slotId: slotId,
  slotName: slotName,
  partnerId: partnerId,
  partnerName: partnerName,
  createDate: createDate,
);

List<String> labels(List<AttendeeGroup> groups) =>
    groups.map((g) => g.label).toList();

List<List<int>> ids(List<AttendeeGroup> groups) =>
    groups.map((g) => g.attendees.map((a) => a.id).toList()).toList();

void main() {
  group('groupAttendees', () {
    test('no attendees give no groups', () {
      expect(groupAttendees(const [], AttendeeGroupBy.status), isEmpty);
    });

    test('status groups follow the order Odoo defines, with its labels', () {
      final groups = groupAttendees([
        attendee(1, state: 'done'),
        attendee(2, state: 'draft'),
        attendee(3, state: 'open'),
        attendee(4, state: 'cancel'),
        attendee(5, state: 'done'),
      ], AttendeeGroupBy.status);
      expect(labels(groups), [
        'Unconfirmed',
        'Cancelled',
        'Registered',
        'Attended',
      ]);
      expect(ids(groups).last, [1, 5]);
    });

    test('only states that have an attendee become groups', () {
      final groups = groupAttendees([
        attendee(1, state: 'open'),
      ], AttendeeGroupBy.status);
      expect(labels(groups), ['Registered']);
    });

    test('event groups sort by name', () {
      final groups = groupAttendees([
        attendee(1, eventId: 2, eventName: 'Summit'),
        attendee(2, eventId: 1, eventName: 'Expo'),
        attendee(3, eventId: 2, eventName: 'Summit'),
      ], AttendeeGroupBy.event);
      expect(labels(groups), ['Expo', 'Summit']);
      expect(ids(groups), [
        [2],
        [1, 3],
      ]);
    });

    test('ticket groups put attendees without one last', () {
      final groups = groupAttendees([
        attendee(1),
        attendee(2, ticketId: 5, ticketName: 'VIP'),
        attendee(3, ticketId: 4, ticketName: 'Standard'),
      ], AttendeeGroupBy.ticket);
      expect(labels(groups), ['Standard', 'VIP', 'No Ticket']);
    });

    test('partner groups put attendees without one last', () {
      final groups = groupAttendees([
        attendee(1),
        attendee(2, partnerId: 3, partnerName: 'zed'),
        attendee(3, partnerId: 2, partnerName: 'Amal'),
      ], AttendeeGroupBy.partner);
      expect(labels(groups), ['Amal', 'zed', 'No Partner']);
    });

    test('slot groups follow the slots\' creation order, not their names', () {
      final groups = groupAttendees([
        attendee(1, slotId: 20, slotName: 'Oct 20, 9:00'),
        attendee(2, slotId: 10, slotName: 'Dec 1, 9:00'),
        attendee(3),
      ], AttendeeGroupBy.slot);
      // "Dec" sorts before "Oct" as text; the earlier slot goes first.
      expect(labels(groups), ['Dec 1, 9:00', 'Oct 20, 9:00', 'No Slot']);
    });

    test('registration date groups by month, oldest first, across years', () {
      final groups = groupAttendees([
        attendee(1, createDate: DateTime(2027, 1, 5)),
        attendee(2, createDate: DateTime(2026, 11, 30)),
        attendee(3, createDate: DateTime(2026, 11, 2)),
        attendee(4),
      ], AttendeeGroupBy.registrationDate);
      expect(labels(groups), [
        'November 2026',
        'January 2027',
        'No Date',
      ]);
      expect(ids(groups).first, [2, 3]);
    });

    test('every attendee lands in exactly one group', () {
      final all = [
        for (var i = 1; i <= 24; i++)
          attendee(
            i,
            state: ['draft', 'open', 'done'][i % 3],
            eventId: i % 2 == 0 ? null : i % 4,
            eventName: i % 2 == 0 ? null : 'Event ${i % 4}',
          ),
      ];
      for (final by in AttendeeGroupBy.values) {
        final groups = groupAttendees(all, by);
        expect(
          groups.expand((g) => g.attendees).map((a) => a.id).toList()..sort(),
          all.map((a) => a.id).toList(),
          reason: '$by',
        );
        expect(groups.map((g) => g.key).toSet(), hasLength(groups.length));
      }
    });
  });

  group('AttendeeGroupBy.availableOn', () {
    test('the per-event list has no Event option', () {
      expect(
        AttendeeGroupBy.availableOn(const OdooCompat(18), singleEvent: true),
        isNot(contains(AttendeeGroupBy.event)),
      );
      expect(
        AttendeeGroupBy.availableOn(const OdooCompat(18), singleEvent: false),
        contains(AttendeeGroupBy.event),
      );
    });

    test('Slot exists from Odoo 19, where events got time slots', () {
      for (final major in [17, 18]) {
        expect(
          AttendeeGroupBy.availableOn(OdooCompat(major), singleEvent: false),
          isNot(contains(AttendeeGroupBy.slot)),
          reason: 'Odoo $major',
        );
      }
      for (final major in [19, 20, 29]) {
        expect(
          AttendeeGroupBy.availableOn(OdooCompat(major), singleEvent: false),
          contains(AttendeeGroupBy.slot),
          reason: 'Odoo $major',
        );
      }
    });

    test('the menu follows Odoo\'s order', () {
      expect(
        AttendeeGroupBy.availableOn(const OdooCompat(19), singleEvent: false),
        [
          AttendeeGroupBy.partner,
          AttendeeGroupBy.event,
          AttendeeGroupBy.slot,
          AttendeeGroupBy.ticket,
          AttendeeGroupBy.status,
          AttendeeGroupBy.registrationDate,
        ],
      );
    });
  });

  group('AttendeeShortModel.fromJson', () {
    test('reads the fields the groupings bucket on', () {
      final a = AttendeeShortModel.fromJson({
        'id': 1,
        'name': 'Maya',
        'barcode': 'x',
        'state': 'open',
        'event_id': [3, 'Summit'],
        'event_ticket_id': [4, 'VIP'],
        'event_slot_id': [5, 'Slot A'],
        'partner_id': [6, 'Maya Co'],
        'create_date': '2026-10-01 09:30:00',
      });
      expect(a.eventTicketId, 4);
      expect(a.slotId, 5);
      expect(a.partnerId, 6);
      expect(a.partnerName, 'Maya Co');
      // UTC text, read as a moment in time.
      expect(a.createDate, DateTime.utc(2026, 10, 1, 9, 30).toLocal());
    });

    test('Odoo sends false for an unset field', () {
      final a = AttendeeShortModel.fromJson({
        'id': 1,
        'name': 'Maya',
        'barcode': 'x',
        'state': 'open',
        'event_id': [3, 'Summit'],
        'event_ticket_id': false,
        'partner_id': false,
        'create_date': false,
      });
      expect(a.eventTicketId, isNull);
      expect(a.eventTicketName, isNull);
      expect(a.slotId, isNull);
      expect(a.partnerId, isNull);
      expect(a.createDate, isNull);
    });
  });
}
