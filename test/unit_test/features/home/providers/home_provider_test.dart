import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import '../service/mock_home_services.dart';

void main() {
  late MockHomeServices mockHomeServices;
  late HomeProvider homeProvider;

  setUp(() {
    mockHomeServices = MockHomeServices();
    homeProvider = HomeProvider(services: mockHomeServices);
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
}