import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import '../service/mock_home_services.dart';

void main() {
  late MockHomeServices mockHomeServices;
  late HomeProvider homeProvider;

  /// The rights the fake server grants; tests change it before loading.
  late bool stageRights;
  late AccessRights access;

  setUp(() {
    mockHomeServices = MockHomeServices();
    stageRights = true;
    // An isolated instance, so no test touches the app-wide singleton or a
    // real session.
    access = AccessRights(
      call: (params) async {
        if (params['model'] == EventModels.stage) return stageRights;
        return true;
      },
      version: () async => '19.0',
    );
    homeProvider = HomeProvider(services: mockHomeServices, access: access);
  });
  test('Initial values are correct', () {
    expect(homeProvider.stageList, []);
    expect(homeProvider.eventList, []);
    expect(homeProvider.isStageLoading, false);
    expect(homeProvider.isEventLoading, false);
    expect(homeProvider.loading, false);
  });
  test("set loading  true ", () {
    homeProvider.setLoading(true);
    expect(homeProvider.loading, true);
  });
  test("set loading false ", () {
    homeProvider.setLoading(false);
    expect(homeProvider.loading, false);
  });
  test('clear the provider', () {
    homeProvider.stageList = [
      EventStage(
        id: 1,
        name: 'fake',
        displayName: "fake",
        sequence: 0,
        fold: true,
        pipeEnd: true,
      ),
    ];

    expect(homeProvider.stageList.isNotEmpty, true);
    homeProvider.clearProvider();
    expect(homeProvider.stageList.isEmpty, true);
    expect(homeProvider.isStageLoading, true);
    expect(homeProvider.isEventLoading, true);
  });
  test("set active filter", () {
    expect(homeProvider.activeFilters.isEmpty, true);
    homeProvider.setActiveFilters(['active filter']);
    expect(homeProvider.activeFilters, ['active filter']);
    expect(homeProvider.activeFilters.isNotEmpty, true);
    expect(homeProvider.activeFilters.isEmpty, false);
  });
  group('group by', () {
    EventShort event(int id, int stageId, String stage) => EventShort(
      id: id,
      name: 'e$id',
      start: DateTime(2026),
      end: DateTime(2026),
      location: '',
      attended: 0,
      maxSeats: 0,
      organizerId: 0,
      organizerName: '',
      stageId: stageId,
      stage: stage,
      kanbanState: 'normal',
    );

    EventStage stage(int id, String name, int sequence) => EventStage(
      id: id,
      name: name,
      displayName: name,
      sequence: sequence,
      fold: false,
      pipeEnd: false,
    );

    test('starts ungrouped', () {
      expect(homeProvider.groupBy, isNull);
      expect(homeProvider.isGrouped, false);
      expect(homeProvider.groupedEvents, isEmpty);
    });

    test('setGroupBy notifies once per real change', () {
      var notified = 0;
      homeProvider.addListener(() => notified++);
      homeProvider.setGroupBy(EventGroupBy.stage);
      homeProvider.setGroupBy(EventGroupBy.stage);
      expect(notified, 1);
      expect(homeProvider.isGrouped, true);
      homeProvider.setGroupBy(null);
      expect(notified, 2);
      expect(homeProvider.isGrouped, false);
    });

    test('groups the loaded events, stages in their own order', () {
      homeProvider.stageList = [stage(2, 'Booked', 2), stage(1, 'New', 1)];
      homeProvider.eventList = [
        event(1, 2, 'Booked'),
        event(2, 1, 'New'),
        event(3, 2, 'Booked'),
      ];
      homeProvider.setGroupBy(EventGroupBy.stage);
      final groups = homeProvider.groupedEvents;
      expect(groups.map((g) => g.label), ['New', 'Booked']);
      expect(groups.map((g) => g.events.length), [1, 2]);
    });

    test('a kanban move shows up in the grouping straight away', () async {
      homeProvider.stageList = [stage(1, 'New', 1), stage(2, 'Booked', 2)];
      homeProvider.eventList = [event(1, 1, 'New')];
      homeProvider.setGroupBy(EventGroupBy.stage);
      when(
        () => mockHomeServices.updateEventStage(
          eventId: any(named: 'eventId'),
          stageId: any(named: 'stageId'),
        ),
      ).thenAnswer((_) async => true);
      await homeProvider.moveEventToStage(1, 2);
      expect(homeProvider.groupedEvents.map((g) => g.label), ['Booked']);
    });

    group('moving a card to another group', () {
      EventShort owned(int id, int userId, String name, {List<int>? image}) =>
          EventShort(
            id: id,
            name: 'e$id',
            start: DateTime(2026),
            end: DateTime(2026),
            location: 'Hall $userId',
            attended: 0,
            maxSeats: 0,
            organizerId: 0,
            organizerName: '',
            stageId: 1,
            stage: 'New',
            kanbanState: 'normal',
            userId: userId,
            userName: name,
            image: image == null ? null : Uint8List.fromList(image),
          );

      void answer(bool ok) => when(
        () => mockHomeServices.updateEventRelation(
          eventId: any(named: 'eventId'),
          field: any(named: 'field'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => ok);

      EventGroup groupOf(int userId) => homeProvider.groupedEvents.firstWhere(
        (g) => g.recordId == userId,
      );

      setUp(() {
        homeProvider.eventList = [
          owned(1, 7, 'Maya', image: [1]),
          owned(2, 9, 'Noor', image: [2]),
        ];
        homeProvider.setGroupBy(EventGroupBy.responsible);
      });

      test('writes the field the grouping is on and regroups at once', () async {
        answer(true);
        await homeProvider.moveEventToGroup(1, groupOf(9));

        verify(
          () => mockHomeServices.updateEventRelation(
            eventId: 1,
            field: 'user_id',
            id: 9,
          ),
        ).called(1);
        final moved = homeProvider.eventList.firstWhere((e) => e.id == 1);
        expect(moved.userId, 9);
        expect(moved.userName, 'Noor');
        // The new responsible's photo, not the old one's.
        expect(moved.image, Uint8List.fromList([2]));
        expect(homeProvider.groupedEvents.map((g) => g.label), ['Noor']);
      });

      test('the none column clears the field', () async {
        answer(true);
        homeProvider.eventList.add(
          EventShort(
            id: 3,
            name: 'e3',
            start: DateTime(2026),
            end: DateTime(2026),
            location: '',
            attended: 0,
            maxSeats: 0,
            organizerId: 0,
            organizerName: '',
            stageId: 1,
            stage: 'New',
            kanbanState: 'normal',
          ),
        );
        await homeProvider.moveEventToGroup(1, groupOf(0));

        verify(
          () => mockHomeServices.updateEventRelation(
            eventId: 1,
            field: 'user_id',
            id: 0,
          ),
        ).called(1);
        final moved = homeProvider.eventList.firstWhere((e) => e.id == 1);
        expect(moved.userName, '');
        expect(moved.image, isEmpty);
      });

      test('rolls back when the server refuses', () async {
        answer(false);
        await expectLater(
          homeProvider.moveEventToGroup(1, groupOf(9)),
          throwsException,
        );
        final back = homeProvider.eventList.firstWhere((e) => e.id == 1);
        expect(back.userId, 7);
        expect(back.userName, 'Maya');
        expect(back.image, Uint8List.fromList([1]));
      });

      test('rolls back when the request fails', () async {
        when(
          () => mockHomeServices.updateEventRelation(
            eventId: any(named: 'eventId'),
            field: any(named: 'field'),
            id: any(named: 'id'),
          ),
        ).thenThrow(Exception('access denied'));
        await expectLater(
          homeProvider.moveEventToGroup(1, groupOf(9)),
          throwsException,
        );
        expect(homeProvider.eventList.first.userId, 7);
      });

      test('dropping on its own group does nothing', () async {
        await homeProvider.moveEventToGroup(1, groupOf(7));
        verifyNever(
          () => mockHomeServices.updateEventRelation(
            eventId: any(named: 'eventId'),
            field: any(named: 'field'),
            id: any(named: 'id'),
          ),
        );
      });

      test('a month is not a record: nothing is written', () async {
        homeProvider.setGroupBy(EventGroupBy.startDate);
        await homeProvider.moveEventToGroup(
          1,
          homeProvider.groupedEvents.first,
        );
        verifyNever(
          () => mockHomeServices.updateEventRelation(
            eventId: any(named: 'eventId'),
            field: any(named: 'field'),
            id: any(named: 'id'),
          ),
        );
      });

      test('on the stage grouping it is the usual stage move', () async {
        homeProvider.stageList = [stage(1, 'New', 1), stage(2, 'Booked', 2)];
        homeProvider.setGroupBy(EventGroupBy.stage);
        when(
          () => mockHomeServices.updateEventStage(
            eventId: any(named: 'eventId'),
            stageId: any(named: 'stageId'),
          ),
        ).thenAnswer((_) async => true);
        await homeProvider.moveEventToGroup(
          1,
          const EventGroup(key: 'stage:2', label: 'Booked', events: [], recordId: 2),
        );
        verify(
          () => mockHomeServices.updateEventStage(eventId: 1, stageId: 2),
        ).called(1);
      });
    });

    test('clearProvider drops the grouping with the rest', () {
      homeProvider.setGroupBy(EventGroupBy.venue);
      homeProvider.clearProvider();
      expect(homeProvider.groupBy, isNull);
    });
  });
  test('load the events with no data', () async {
    final fakeEvents = <EventShort>[];
    when(
      () => mockHomeServices.gettingEventsShort(),
    ).thenAnswer((_) async => fakeEvents);
    await homeProvider.loadEvents();
    verify(() => mockHomeServices.gettingEventsShort()).called(1);
    expect(homeProvider.isEventLoading, false);
    expect(homeProvider.eventList.isEmpty, true);
  });
  test('load event with data', () async {
    final fakeEvents = [
      EventShort(
        id: 1,
        name: 'fake event',
        start: DateTime(2026),
        end: DateTime(2026),
        location: 'india',
        attended: 4,
        maxSeats: 10,
        organizerId: 1,
        organizerName: 'dummy',
        stageId: 1,
        stage: 'dummy',
        kanbanState: 'dummy',
      ),
    ];
    when(
      () => mockHomeServices.gettingEventsShort(),
    ).thenAnswer((_) async => fakeEvents);
    await homeProvider.loadEvents();
    expect(homeProvider.eventList.isNotEmpty, true);
    expect(homeProvider.eventList.length, 1);
    expect(homeProvider.isEventLoading, false);
    verify(() => mockHomeServices.gettingEventsShort()).called(1);
  });
  test('loadEvents throws error when service fails', () async {
    when(
      () => mockHomeServices.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    ).thenThrow(Exception('Failed'));

    expect(() => homeProvider.loadEvents(), throwsException);

    expect(homeProvider.isEventLoading, false);
  });
  test('gettingStages loads stages and returns true', () async {
    final mockStages = [
      EventStage(
        id: 1,
        name: 'fake',
        displayName: "fake",
        sequence: 0,
        fold: true,
        pipeEnd: true,
      ),
    ];

    when(
      () => mockHomeServices.gettingStage(),
    ).thenAnswer((_) async => mockStages);

    when(
      () => mockHomeServices.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => []);

    final result = await homeProvider.gettingStages();

    expect(homeProvider.stageList, mockStages);
    expect(result, true);
    expect(homeProvider.isStageLoading, false);
  });
  test('gettingStages returns false when service fails', () async {
    when(
      () => mockHomeServices.gettingStage(),
    ).thenThrow(Exception('Stage error'));
    final result = await homeProvider.gettingStages();
    expect(result, false);
    expect(homeProvider.isStageLoading, false);
  });

  group('rights', () {
    void stubHome() {
      when(
        () => mockHomeServices.gettingStage(),
      ).thenAnswer((_) async => <EventStage>[]);
      when(
        () => mockHomeServices.gettingEventsShort(
          search: any(named: 'search'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => []);
    }

    test('gettingStages loads what the account may do', () async {
      stubHome();
      stageRights = false;

      await homeProvider.gettingStages();

      expect(access.isLoaded, true);
      expect(homeProvider.canManageStages, false);
      expect(access.canAddStage, false);
    });

    test('an administrator may manage stages', () async {
      stubHome();
      stageRights = true;

      await homeProvider.gettingStages();

      expect(homeProvider.canManageStages, true);
      expect(access.canAddStage, true);
      expect(access.canRenameStage, true);
      expect(access.canDeleteStage, true);
      expect(access.canReorderStages, true);
    });

    test('clearProvider forgets the previous account\'s rights', () async {
      stubHome();
      stageRights = false;
      await homeProvider.gettingStages();
      expect(access.isLoaded, true);

      homeProvider.clearProvider();

      expect(access.isLoaded, false);
    });

    test(
      'the provider rebuilds its listeners when the rights change',
      () async {
        stubHome();
        var notified = 0;
        homeProvider.addListener(() => notified++);

        await access.load();

        expect(notified, greaterThan(0));
      },
    );

    test(
      'a failing stage load does not leave the rights half-loaded',
      () async {
        when(
          () => mockHomeServices.gettingStage(),
        ).thenThrow(Exception('Stage error'));

        final result = await homeProvider.gettingStages();

        expect(result, false);
        expect(homeProvider.isStageLoading, false);
      },
    );
  });
}
