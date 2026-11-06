import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/model/event_short.dart';

EventShort event(
  int id, {
  DateTime? start,
  int stageId = 1,
  String stage = 'Draft',
  int? userId,
  String userName = '',
  int templateId = 0,
  String templateName = '',
  int venueId = 0,
  String venueName = '',
}) => EventShort(
  id: id,
  name: 'Event $id',
  start: start ?? DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 2),
  location: '',
  attended: 0,
  maxSeats: 0,
  organizerId: 0,
  organizerName: '',
  stageId: stageId,
  stage: stage,
  kanbanState: 'normal',
  userId: userId,
  userName: userName,
  templateId: templateId,
  templateName: templateName,
  venueId: venueId,
  venueName: venueName,
);

EventStage stage(int id, String name, int sequence) => EventStage(
  id: id,
  name: name,
  displayName: name,
  sequence: sequence,
  fold: false,
  pipeEnd: false,
);

List<String> labels(List<EventGroup> groups) =>
    groups.map((g) => g.label).toList();

List<List<int>> ids(List<EventGroup> groups) =>
    groups.map((g) => g.events.map((e) => e.id).toList()).toList();

void main() {
  group('groupEvents', () {
    test('no events give no groups', () {
      expect(groupEvents(const [], EventGroupBy.stage), isEmpty);
    });

    test('stage groups follow the stage order, not arrival order', () {
      final stages = [
        stage(1, 'New', 1),
        stage(2, 'Booked', 2),
        stage(3, 'Ended', 3),
      ];
      final groups = groupEvents(
        [
          event(1, stageId: 3, stage: 'Ended'),
          event(2, stageId: 1, stage: 'New'),
          event(3, stageId: 3, stage: 'Ended'),
          event(4, stageId: 2, stage: 'Booked'),
        ],
        EventGroupBy.stage,
        stages: stages,
      );
      expect(labels(groups), ['New', 'Booked', 'Ended']);
      // Events keep the order they arrived in inside a group.
      expect(ids(groups), [
        [2],
        [4],
        [1, 3],
      ]);
    });

    test('only stages that have an event become groups', () {
      final groups = groupEvents(
        [event(1, stageId: 2, stage: 'Booked')],
        EventGroupBy.stage,
        stages: [stage(1, 'New', 1), stage(2, 'Booked', 2)],
      );
      expect(labels(groups), ['Booked']);
    });

    test('a stage missing from the stage list still gets a group, last', () {
      final groups = groupEvents(
        [
          event(1, stageId: 9, stage: 'Archived stage'),
          event(2, stageId: 1, stage: 'New'),
        ],
        EventGroupBy.stage,
        stages: [stage(1, 'New', 1)],
      );
      expect(labels(groups), ['New', 'Archived stage']);
    });

    test('responsible groups sort by name with Unassigned last', () {
      final groups = groupEvents([
        event(1),
        event(2, userId: 7, userName: 'zoe'),
        event(3, userId: 5, userName: 'Adam'),
        event(4, userId: 7, userName: 'zoe'),
      ], EventGroupBy.responsible);
      expect(labels(groups), ['Adam', 'zoe', 'Unassigned']);
      expect(ids(groups), [
        [3],
        [2, 4],
        [1],
      ]);
    });

    test('a group carries the record a card dropped on it is written to', () {
      final groups = groupEvents(
        [
          event(1),
          event(2, userId: 7, userName: 'Maya'),
          event(3, venueId: 4, venueName: 'Hall'),
        ],
        EventGroupBy.responsible,
      );
      expect(groups.map((g) => g.recordId), [7, 0]);
      expect(
        groupEvents([event(1, stageId: 3, stage: 'Ended')], EventGroupBy.stage)
            .single
            .recordId,
        3,
      );
      expect(
        groupEvents(
          [event(1, venueId: 4, venueName: 'Hall'), event(2)],
          EventGroupBy.venue,
        ).map((g) => g.recordId),
        [4, 0],
      );
    });

    test('two records sharing a name stay separate groups', () {
      final groups = groupEvents([
        event(1, venueId: 1, venueName: 'Hall'),
        event(2, venueId: 2, venueName: 'Hall'),
      ], EventGroupBy.venue);
      expect(groups, hasLength(2));
    });

    test('an event with no venue is grouped as Online, last', () {
      final groups = groupEvents([
        event(1),
        event(2, venueId: 3, venueName: 'Convention Centre'),
      ], EventGroupBy.venue);
      expect(labels(groups), ['Convention Centre', 'Online']);
    });

    test('template groups put events without one under No Template', () {
      final groups = groupEvents([
        event(1),
        event(2, templateId: 1, templateName: 'Conference'),
      ], EventGroupBy.template);
      expect(labels(groups), ['Conference', 'No Template']);
    });

    test('start date groups by month, oldest first, across years', () {
      final groups = groupEvents([
        event(1, start: DateTime(2027, 1, 5)),
        event(2, start: DateTime(2026, 11, 30)),
        event(3, start: DateTime(2026, 11, 2)),
        event(4, start: DateTime(2026, 2, 14)),
      ], EventGroupBy.startDate);
      expect(labels(groups), [
        'February 2026',
        'November 2026',
        'January 2027',
      ]);
      expect(ids(groups)[1], [2, 3]);
    });

    test('every event lands in exactly one group', () {
      final events = [
        for (var i = 1; i <= 30; i++)
          event(
            i,
            userId: i % 4 == 0 ? null : i % 4,
            userName: i % 4 == 0 ? '' : 'User ${i % 4}',
          ),
      ];
      for (final by in EventGroupBy.values) {
        final groups = groupEvents(events, by);
        expect(
          groups.expand((g) => g.events).map((e) => e.id).toList()..sort(),
          events.map((e) => e.id).toList(),
          reason: '$by',
        );
      }
    });

    test('group keys differ between groupings and between groups', () {
      final events = [event(1), event(2, stageId: 2, stage: 'Booked')];
      final byStage = groupEvents(events, EventGroupBy.stage);
      final byVenue = groupEvents(events, EventGroupBy.venue);
      expect(byStage.map((g) => g.key).toSet(), hasLength(2));
      expect(
        byStage.map((g) => g.key).toSet().intersection(
          byVenue.map((g) => g.key).toSet(),
        ),
        isEmpty,
      );
    });
  });

  group('EventGroupBy', () {
    test('only groupings of records can have a card dropped on them', () {
      expect(EventGroupBy.stage.field, 'stage_id');
      expect(EventGroupBy.responsible.field, 'user_id');
      expect(EventGroupBy.template.field, 'event_type_id');
      expect(EventGroupBy.venue.field, 'address_id');
      expect(EventGroupBy.startDate.field, isNull);
      expect(EventGroupBy.startDate.isDraggable, false);
      expect(EventGroupBy.venue.isDraggable, true);
    });
  });

  group('EventGroupBy.availableOn', () {
    test('Odoo 17 has no Venue group-by, 18 and later do', () {
      expect(
        EventGroupBy.availableOn(const OdooCompat(17)),
        isNot(contains(EventGroupBy.venue)),
      );
      for (final major in [18, 19, 20, 29]) {
        expect(
          EventGroupBy.availableOn(OdooCompat(major)),
          contains(EventGroupBy.venue),
          reason: 'Odoo $major',
        );
      }
    });

    test('the other four are offered on every release', () {
      for (final major in [17, 18, 19, 20]) {
        expect(
          EventGroupBy.availableOn(OdooCompat(major)),
          containsAll([
            EventGroupBy.stage,
            EventGroupBy.responsible,
            EventGroupBy.template,
            EventGroupBy.startDate,
          ]),
        );
      }
    });
  });

  group('EventShort.fromJson', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 1,
      'display_name': 'Fair',
      'date_begin': '2026-10-01 09:00:00',
      'date_end': '2026-10-02 09:00:00',
      ...extra,
    };

    test('reads the responsible user, template and venue', () {
      final e = EventShort.fromJson(
        json({
          'user_id': [7, 'Maya'],
          'event_type_id': [3, 'Conference'],
          'address_id': [9, 'Hall A'],
        }),
      );
      expect(e.userName, 'Maya');
      expect(e.templateId, 3);
      expect(e.templateName, 'Conference');
      expect(e.venueId, 9);
      expect(e.venueName, 'Hall A');
    });

    test('Odoo sends false for an unset many2one', () {
      final e = EventShort.fromJson(
        json({'user_id': false, 'event_type_id': false, 'address_id': false}),
      );
      expect(e.userName, '');
      expect(e.templateId, 0);
      expect(e.templateName, '');
      expect(e.venueId, 0);
      expect(e.venueName, '');
    });

    test('copyWith keeps them, so a kanban move does not regroup the event', () {
      final e = EventShort.fromJson(
        json({
          'user_id': [7, 'Maya'],
          'event_type_id': [3, 'Conference'],
          'address_id': [9, 'Hall A'],
        }),
      ).copyWith(stageId: 4, stage: 'Booked');
      expect(e.userName, 'Maya');
      expect(e.templateName, 'Conference');
      expect(e.venueName, 'Hall A');
      expect(e.stage, 'Booked');
    });
  });
}
