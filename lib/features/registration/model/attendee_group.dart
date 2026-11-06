import 'package:intl/intl.dart';

import '../../../core/utils/odoo_compat.dart';
import '../../../shared/widgets/filters/filter_group_by_sheet.dart';
import '../../../shared/widgets/groups/group_section.dart';
import 'attendee_short_model.dart';

/// What the attendee lists can be grouped by — the entries of Odoo's own
/// registration search view "Group By" menu: Partner, Event, Slot (Odoo 19+),
/// Ticket Type, Status and Registration Date.
enum AttendeeGroupBy implements GroupByChoice {
  partner('Partner', 'Group attendees by who registered them'),
  event('Event', 'Group attendees by the event they registered for'),
  slot('Slot', 'Group attendees by their time slot'),
  ticket('Ticket Type', 'Group attendees by their ticket type'),
  status('Status', 'Group attendees by their registration status'),
  registrationDate(
    'Registration Date',
    'Group attendees by the month they registered',
  );

  const AttendeeGroupBy(this.label, this.description);

  @override
  final String label;
  @override
  final String description;

  /// The options to offer on the connected server, in menu order.
  ///
  /// [singleEvent] is the per-event list: every attendee there has the same
  /// event, so Odoo's own event-scoped action drops that option from the menu.
  static List<AttendeeGroupBy> availableOn(
    OdooCompat compat, {
    required bool singleEvent,
  }) => values.where((option) {
    if (option == event) return !singleEvent;
    if (option == slot) return compat.hasEventSlots;
    return true;
  }).toList();
}

/// One group of attendees: a collapsible tile in the attendee lists.
class AttendeeGroup extends GroupSection<AttendeeShortModel> {
  const AttendeeGroup({
    required super.key,
    required super.label,
    required List<AttendeeShortModel> attendees,
  }) : super(items: attendees);

  List<AttendeeShortModel> get attendees => items;
}

/// The registration states in the order Odoo's selection defines them, with
/// the label it shows. A group follows this order, not the alphabet.
const _stateOrder = ['draft', 'cancel', 'open', 'done'];
const _stateLabels = {
  'draft': 'Unconfirmed',
  'cancel': 'Cancelled',
  'open': 'Registered',
  'done': 'Attended',
};

/// Partitions [attendees] into the groups a list shows for [by], the way
/// Odoo's grouped list view does: only groups that have a record, records
/// keeping the order they arrived in, and the "none" bucket (an unset many2one)
/// last.
List<AttendeeGroup> groupAttendees(
  List<AttendeeShortModel> attendees,
  AttendeeGroupBy by,
) {
  // Insertion-ordered, so a group's attendees stay in the order they came in.
  final buckets = <String, List<AttendeeShortModel>>{};
  final labels = <String, String>{};
  // Where a group sorts. Groups with the same rank fall back to their label.
  final ranks = <String, int>{};
  final unsetKeys = <String>{};

  void add(
    AttendeeShortModel attendee, {
    required String key,
    required String label,
    int rank = 0,
    bool unset = false,
  }) {
    buckets.putIfAbsent(key, () => []).add(attendee);
    labels[key] = label;
    ranks[key] = rank;
    if (unset) unsetKeys.add(key);
  }

  bool blank(String? name) => name == null || name.isEmpty;

  for (final attendee in attendees) {
    switch (by) {
      case AttendeeGroupBy.partner:
        final unset = blank(attendee.partnerName);
        add(
          attendee,
          key: 'partner:${attendee.partnerId ?? 0}',
          label: unset ? 'No Partner' : attendee.partnerName!,
          unset: unset,
        );
      case AttendeeGroupBy.event:
        final unset = blank(attendee.eventName);
        add(
          attendee,
          key: 'event:${attendee.eventId ?? 0}',
          label: unset ? 'No Event' : attendee.eventName!,
          unset: unset,
        );
      case AttendeeGroupBy.slot:
        final unset = blank(attendee.slotName);
        add(
          attendee,
          key: 'slot:${attendee.slotId ?? 0}',
          label: unset ? 'No Slot' : attendee.slotName!,
          // A slot's name is a locale-formatted date, which doesn't sort as one;
          // slots are created in date order, so their ids do.
          rank: attendee.slotId ?? 0,
          unset: unset,
        );
      case AttendeeGroupBy.ticket:
        final unset = blank(attendee.eventTicketName);
        add(
          attendee,
          key: 'ticket:${attendee.eventTicketId ?? 0}',
          label: unset ? 'No Ticket' : attendee.eventTicketName!,
          unset: unset,
        );
      case AttendeeGroupBy.status:
        final known = _stateOrder.indexOf(attendee.state);
        add(
          attendee,
          key: 'status:${attendee.state}',
          label:
              _stateLabels[attendee.state] ??
              (attendee.state.isEmpty ? 'No Status' : attendee.state),
          rank: known == -1 ? _stateOrder.length : known,
          unset: attendee.state.isEmpty,
        );
      case AttendeeGroupBy.registrationDate:
        // Odoo groups a date by period, not by the exact moment.
        final date = attendee.createDate;
        add(
          attendee,
          key: date == null
              ? 'registrationDate:none'
              : 'registrationDate:${date.year}-${date.month}',
          label: date == null ? 'No Date' : DateFormat('MMMM yyyy').format(date),
          rank: date == null ? 0 : date.year * 12 + date.month,
          unset: date == null,
        );
    }
  }

  final keys = buckets.keys.toList()
    ..sort((a, b) {
      // The "none" bucket goes last whatever else is ranked.
      final unsetA = unsetKeys.contains(a);
      final unsetB = unsetKeys.contains(b);
      if (unsetA != unsetB) return unsetA ? 1 : -1;
      final byRank = ranks[a]!.compareTo(ranks[b]!);
      if (byRank != 0) return byRank;
      return labels[a]!.toLowerCase().compareTo(labels[b]!.toLowerCase());
    });

  return [
    for (final key in keys)
      AttendeeGroup(key: key, label: labels[key]!, attendees: buckets[key]!),
  ];
}
