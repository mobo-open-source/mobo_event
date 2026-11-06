import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:mobo_event/features/home/widgets/kanban_board.dart';
import 'package:mobo_event/features/home/widgets/no_events_empty_state.dart';
import 'package:mobo_event/features/profile/providers/profile_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../service/mock_home_services.dart';

EventShort event(
  int id, {
  required int stageId,
  required String stage,
  int userId = 0,
  String userName = '',
  int venueId = 0,
  String venueName = '',
  DateTime? start,
}) => EventShort(
  id: id,
  name: 'Event $id',
  start: start ?? DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 2),
  location: venueName,
  attended: 0,
  maxSeats: 0,
  organizerId: 0,
  organizerName: '',
  stageId: stageId,
  stage: stage,
  kanbanState: 'normal',
  userId: userId,
  userName: userName,
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

void main() {
  late MockHomeServices services;
  late HomeProvider provider;

  setUp(() {
    services = MockHomeServices();
    provider =
        HomeProvider(
            services: services,
            access: AccessRights(
              call: (_) async => true,
              version: () async => '19.0',
            ),
          )
          ..version = '19.0'
          ..stageList = [stage(1, 'New', 1), stage(2, 'Booked', 2)]
          ..eventList = [
            event(1, stageId: 1, stage: 'New', userId: 7, userName: 'Maya'),
            event(2, stageId: 2, stage: 'Booked', userId: 7, userName: 'Maya'),
            event(3, stageId: 1, stage: 'New', userId: 9, userName: 'Noor'),
            event(4, stageId: 1, stage: 'New'),
          ];
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1000, 800),
    ThemeMode mode = ThemeMode.light,
    // The empty state loops a Lottie animation, which never settles.
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HomeProvider>.value(value: provider),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          themeMode: mode,
          home: Scaffold(
            body: Consumer<HomeProvider>(
              builder: (_, home, _) => KanbanBoard(provider: home),
            ),
          ),
        ),
      ),
    );
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 300));
  }

  /// The pill's title and its " (n)" count are separate texts.
  Finder column(String title, int count) => find.byWidgetPredicate(
    (w) => w is Text && w.data == title,
    description: 'column "$title"',
  );

  testWidgets('with no grouping the board is the stage board', (tester) async {
    await pump(tester);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('Add Stage'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
  });

  testWidgets('grouped by Stage it is still the stage board', (tester) async {
    provider.setGroupBy(EventGroupBy.stage);
    await pump(tester);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Add Stage'), findsOneWidget);
  });

  testWidgets('grouped by Responsible the columns are the people', (
    tester,
  ) async {
    provider.setGroupBy(EventGroupBy.responsible);
    await pump(tester);

    expect(column('Maya', 2), findsOneWidget);
    expect(column('Noor', 1), findsOneWidget);
    expect(column('Unassigned', 1), findsOneWidget);
    expect(find.text(' (2)'), findsOneWidget);
    // The stage columns, and the stage management, are gone.
    expect(find.text('New'), findsNothing);
    expect(find.text('Booked'), findsNothing);
    expect(find.text('Add Stage'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // Every event is still on the board.
    for (final id in [1, 2, 3, 4]) {
      expect(find.text('Event $id'), findsOneWidget, reason: 'Event $id');
    }
  });

  testWidgets('grouped by Start Date the columns are the months', (
    tester,
  ) async {
    provider.eventList = [
      event(1, stageId: 1, stage: 'New', start: DateTime(2026, 11, 3)),
      event(2, stageId: 1, stage: 'New', start: DateTime(2026, 10, 3)),
    ];
    provider.setGroupBy(EventGroupBy.startDate);
    await pump(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('no events at all: the usual empty state, not a blank board', (
    tester,
  ) async {
    provider.eventList = [];
    provider.setGroupBy(EventGroupBy.responsible);
    await pump(tester, settle: false);
    expect(find.byType(NoEventsEmptyState), findsOneWidget);
    // Nothing was filtered out, so there is nothing to "clear".
    expect(find.text('Clear Filters'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow board still lays out (light and dark)', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      provider.setGroupBy(EventGroupBy.responsible);
      await pump(tester, size: const Size(390, 700), mode: mode);
      expect(tester.takeException(), isNull, reason: '$mode');
    }
  });

  group('dragging a card to another column', () {
    Future<void> drag(WidgetTester tester, String card, String ontoCard) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text(card)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text(ontoCard)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    void answer(bool ok) => when(
      () => services.updateEventRelation(
        eventId: any(named: 'eventId'),
        field: any(named: 'field'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => ok);

    testWidgets('changes the responsible, and the board regroups', (
      tester,
    ) async {
      answer(true);
      provider.setGroupBy(EventGroupBy.responsible);
      await pump(tester);

      await drag(tester, 'Event 3', 'Event 1');

      verify(
        () => services.updateEventRelation(
          eventId: 3,
          field: 'user_id',
          id: 7,
        ),
      ).called(1);
      // Noor's only event moved: her column is gone, Maya's has three.
      expect(find.text('Noor'), findsNothing);
      expect(find.text(' (3)'), findsOneWidget);
    });

    testWidgets('a refused move puts the card back and says so', (
      tester,
    ) async {
      answer(false);
      provider.setGroupBy(EventGroupBy.responsible);
      await pump(tester);

      await drag(tester, 'Event 3', 'Event 1');

      expect(find.text("Couldn't move event"), findsOneWidget);
      expect(find.text('Noor'), findsOneWidget);
      expect(provider.eventList.firstWhere((e) => e.id == 3).userId, 9);
    });

    testWidgets('onto the none column clears the field', (tester) async {
      answer(true);
      provider.setGroupBy(EventGroupBy.responsible);
      await pump(tester);

      await drag(tester, 'Event 3', 'Event 4');

      verify(
        () => services.updateEventRelation(
          eventId: 3,
          field: 'user_id',
          id: 0,
        ),
      ).called(1);
    });

    testWidgets('on the stage board it still writes the stage', (tester) async {
      when(
        () => services.updateEventStage(
          eventId: any(named: 'eventId'),
          stageId: any(named: 'stageId'),
        ),
      ).thenAnswer((_) async => true);
      await pump(tester);

      await drag(tester, 'Event 1', 'Event 2');

      verify(
        () => services.updateEventStage(eventId: 1, stageId: 2),
      ).called(1);
    });

    testWidgets('months are not records: the card stays put', (tester) async {
      provider.eventList = [
        event(1, stageId: 1, stage: 'New', start: DateTime(2026, 10, 3)),
        event(2, stageId: 1, stage: 'New', start: DateTime(2026, 11, 3)),
      ];
      provider.setGroupBy(EventGroupBy.startDate);
      await pump(tester);

      await drag(tester, 'Event 1', 'Event 2');

      verifyNever(
        () => services.updateEventRelation(
          eventId: any(named: 'eventId'),
          field: any(named: 'field'),
          id: any(named: 'id'),
        ),
      );
      expect(find.text('October 2026'), findsOneWidget);
    });
  });
}
