import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:mobo_event/features/home/widgets/event_group_list.dart';
import 'package:mobo_event/features/home/widgets/event_short_card.dart';
import 'package:mobo_event/features/profile/providers/profile_provider.dart';
import 'package:mobo_event/shared/widgets/groups/expandable_group_list.dart';
import 'package:provider/provider.dart';

import '../service/mock_home_services.dart';

EventShort event(int id) => EventShort(
  id: id,
  name: 'Event $id',
  start: DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 2),
  location: 'Hall',
  attended: 1,
  maxSeats: 10,
  organizerId: 0,
  organizerName: '',
  stageId: 1,
  stage: 'New',
  kanbanState: 'normal',
);

EventGroup eventGroup(String key, String label, int count, {int from = 1}) =>
    EventGroup(
      key: key,
      label: label,
      events: [for (var i = 0; i < count; i++) event(from + i)],
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget list, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final home = HomeProvider(
      services: MockHomeServices(),
      access: AccessRights(call: (_) async => true, version: () async => '19.0'),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HomeProvider>.value(value: home),
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
          home: Scaffold(body: list),
        ),
      ),
    );
    await tester.pump();
  }

  final cards = find.byType(EventShortCard);

  testWidgets('groups start collapsed: a tile per group, no cards', (
    tester,
  ) async {
    await pump(
      tester,
      EventGroupList(
        groups: [eventGroup('a', 'New', 3), eventGroup('b', 'Booked', 1, from: 10)],
      ),
    );
    expect(find.text('New'), findsOneWidget);
    expect(find.text('3 events'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('1 event'), findsOneWidget);
    expect(cards, findsNothing);
  });

  testWidgets('tapping a tile opens its events, tapping again closes them', (
    tester,
  ) async {
    await pump(
      tester,
      EventGroupList(
        groups: [eventGroup('a', 'New', 2), eventGroup('b', 'Booked', 1, from: 10)],
      ),
    );

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(cards, findsNWidgets(2));
    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Event 10'), findsNothing);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(cards, findsNothing);
  });

  testWidgets('groups open independently of each other', (tester) async {
    await pump(
      tester,
      EventGroupList(
        groups: [eventGroup('a', 'New', 1), eventGroup('b', 'Booked', 1, from: 10)],
      ),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();
    expect(cards, findsNWidgets(2));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(cards, findsOneWidget);
    expect(find.text('Event 10'), findsOneWidget);
  });

  testWidgets('a lone group is open from the start', (tester) async {
    await pump(tester, EventGroupList(groups: [eventGroup('a', 'New', 2)]));
    expect(cards, findsNWidgets(2));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(cards, findsNothing);
  });

  testWidgets('a big group shows a page, then more on request', (tester) async {
    await pump(
      tester,
      EventGroupList(groups: [eventGroup('a', 'New', 7)], pageSize: 3),
    );
    expect(find.text('Show 4 more'), findsOneWidget);
    expect(cards, findsNWidgets(3));

    await tester.tap(find.text('Show 4 more'));
    await tester.pumpAndSettle();
    expect(find.text('Show 1 more'), findsOneWidget);
    expect(cards, findsNWidgets(6));

    await tester.ensureVisible(find.text('Show 1 more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 1 more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Show'), findsNothing);
    expect(cards, findsNWidgets(7));
  });

  testWidgets('a group keeps its open state when the list above it changes', (
    tester,
  ) async {
    final groups = ValueNotifier<List<EventGroup>>([
      eventGroup('a', 'New', 1),
      eventGroup('b', 'Booked', 1, from: 10),
    ]);
    await pump(
      tester,
      ValueListenableBuilder<List<EventGroup>>(
        valueListenable: groups,
        builder: (_, value, _) => EventGroupList(groups: value),
      ),
    );
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();
    expect(find.text('Event 10'), findsOneWidget);

    // A filter removes the first group; Booked must stay open.
    groups.value = [eventGroup('b', 'Booked', 1, from: 10)];
    await tester.pumpAndSettle();
    expect(find.text('New'), findsNothing);
    expect(find.text('Event 10'), findsOneWidget);
  });

  testWidgets('open groups stay open through a reload of the screen', (
    tester,
  ) async {
    // A screen swaps the list for a skeleton while it reloads, then back.
    final expansion = GroupExpansion();
    final showList = ValueNotifier<bool>(true);
    await pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: showList,
        builder: (_, visible, _) => visible
            ? EventGroupList(
                groups: [
                  eventGroup('a', 'New', 1),
                  eventGroup('b', 'Booked', 1, from: 10),
                ],
                expansion: expansion,
              )
            : const SizedBox(),
      ),
    );
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();
    expect(find.text('Event 10'), findsOneWidget);

    showList.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Booked'), findsNothing);
    showList.value = true;
    await tester.pumpAndSettle();

    expect(find.text('Event 10'), findsOneWidget);
    expect(find.text('Event 1'), findsNothing);
  });

  testWidgets('"Show more" survives a reload too', (tester) async {
    final expansion = GroupExpansion();
    final showList = ValueNotifier<bool>(true);
    await pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: showList,
        builder: (_, visible, _) => visible
            ? EventGroupList(
                groups: [eventGroup('a', 'New', 7)],
                pageSize: 3,
                expansion: expansion,
              )
            : const SizedBox(),
      ),
    );
    await tester.tap(find.text('Show 4 more'));
    await tester.pumpAndSettle();
    showList.value = false;
    await tester.pumpAndSettle();
    showList.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Show 1 more'), findsOneWidget);
  });

  group('lays out without overflowing', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in const [
        Size(360, 640),
        Size(844, 390), // phone, landscape
      ]) {
        testWidgets('$mode at $size', (tester) async {
          await pump(
            tester,
            EventGroupList(
              groups: [
                eventGroup('a', 'A very long group name ' * 4, 2),
                eventGroup('b', 'Booked', 1, from: 10),
              ],
            ),
            size: size,
            mode: mode,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(InkWell).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(cards, findsWidgets);
        });
      }
    }
  });
}
