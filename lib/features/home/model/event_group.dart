import 'package:intl/intl.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';
import 'package:mobo_event/features/home/model/event_short.dart';

import '../../../shared/widgets/filters/filter_group_by_sheet.dart';
import '../../../shared/widgets/groups/group_section.dart';

/// What the Home list and board can be grouped by — the entries of Odoo's own
/// event search view "Group By" menu (Responsible, Template, Stage, Start Date
/// and, from Odoo 18, Venue).
enum EventGroupBy implements GroupByChoice {
  stage('Stage', 'Group events by their current stage', 'stage_id'),
  responsible(
    'Responsible',
    'Group events by who is responsible',
    'user_id',
  ),
  template(
    'Template',
    'Group events by their event template',
    'event_type_id',
  ),
  startDate('Start Date', 'Group events by the month they start', null),
  venue('Venue', 'Group events by where they take place', 'address_id');

  const EventGroupBy(this.label, this.description, this.field);

  @override
  final String label;
  @override
  final String description;

  /// The `event.event` many2one a card is written to when it is dropped on a
  /// column of this grouping — Odoo's own kanban does the same. Null where the
  /// groups aren't records (a month), so cards there stay put.
  final String? field;

  /// Whether a card can be moved between this grouping's groups.
  bool get isDraggable => field != null;

  /// Whether the connected server's event search view offers this option.
  bool isAvailableOn(OdooCompat compat) =>
      this != venue || compat.hasVenueGroupBy;

  /// The options to offer on the connected server, in menu order.
  static List<EventGroupBy> availableOn(OdooCompat compat) =>
      values.where((option) => option.isAvailableOn(compat)).toList();
}

/// One group of events: a collapsible tile in the List view, a column on the
/// board.
class EventGroup extends GroupSection<EventShort> {
  const EventGroup({
    required super.key,
    required super.label,
    required List<EventShort> events,
    this.recordId = 0,
  }) : super(items: events);

  /// The record a card dropped here is written to — the stage, user,
  /// template or venue — or 0 for the "none" group (and for a month).
  final int recordId;

  List<EventShort> get events => items;
}

/// Partitions [events] into the groups the list shows for [by], the way Odoo's
/// grouped list view does: only groups that have a record, records keeping the
/// order they arrived in, and the "none" bucket (an unset many2one) last.
///
/// [stages] is `HomeProvider.orderedStages`; stage groups follow it.
List<EventGroup> groupEvents(
  List<EventShort> events,
  EventGroupBy by, {
  List<EventStage> stages = const [],
}) {
  // Insertion-ordered, so a group's events stay in the order they came in.
  final buckets = <String, List<EventShort>>{};
  final labels = <String, String>{};
  final recordIds = <String, int>{};
  // Where a group sorts. Groups with the same rank fall back to their label.
  final ranks = <String, int>{};
  final unsetKeys = <String>{};

  void add(
    EventShort event, {
    required String key,
    required String label,
    int recordId = 0,
    int rank = 0,
    bool unset = false,
  }) {
    buckets.putIfAbsent(key, () => []).add(event);
    labels[key] = label;
    recordIds[key] = recordId;
    ranks[key] = rank;
    if (unset) unsetKeys.add(key);
  }

  final stageRank = {
    for (var i = 0; i < stages.length; i++) stages[i].id: i,
  };

  for (final event in events) {
    switch (by) {
      case EventGroupBy.stage:
        final known = stageRank.containsKey(event.stageId);
        add(
          event,
          key: 'stage:${event.stageId}',
          label: event.stage.isEmpty ? 'No Stage' : event.stage,
          recordId: event.stageId,
          rank: known ? stageRank[event.stageId]! : stageRank.length,
          unset: event.stage.isEmpty && !known,
        );
      case EventGroupBy.responsible:
        final unset = event.userName.isEmpty;
        add(
          event,
          key: 'responsible:${event.userId ?? 0}',
          label: unset ? 'Unassigned' : event.userName,
          recordId: event.userId ?? 0,
          unset: unset,
        );
      case EventGroupBy.template:
        final unset = event.templateName.isEmpty;
        add(
          event,
          key: 'template:${event.templateId}',
          label: unset ? 'No Template' : event.templateName,
          recordId: event.templateId,
          unset: unset,
        );
      case EventGroupBy.startDate:
        // Odoo groups a date by month, not by the exact day.
        add(
          event,
          key: 'startDate:${event.start.year}-${event.start.month}',
          label: DateFormat('MMMM yyyy').format(event.start),
          rank: event.start.year * 12 + event.start.month,
        );
      case EventGroupBy.venue:
        // An event with no venue is an online one (the same test the "Online"
        // filter and the card's "Online Event" use).
        final unset = event.venueName.isEmpty;
        add(
          event,
          key: 'venue:${event.venueId}',
          label: unset ? 'Online' : event.venueName,
          recordId: event.venueId,
          unset: unset,
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
      EventGroup(
        key: key,
        label: labels[key]!,
        events: buckets[key]!,
        recordId: recordIds[key]!,
      ),
  ];
}
