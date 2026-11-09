import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/registration/model/attendee_group.dart';
import 'package:mobo_event/features/registration/widget/attendee_filter_sheet.dart';

void main() {
  late List<String> committedFilters;
  late AttendeeGroupBy? committedGroupBy;
  late List<String> calls;

  setUp(() {
    committedFilters = ['untouched'];
    committedGroupBy = null;
    calls = [];
  });

  Future<void> open(
    WidgetTester tester, {
    List<AttendeeGroupBy>? options,
    AttendeeGroupBy? initial,
    List<String> filters = const ['Registered'],
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        darkTheme: AppTheme.darkTheme.copyWith(
          splashFactory: InkRipple.splashFactory,
        ),
        themeMode: mode,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAttendeeFilterSheet(
                  context,
                  initialFilters: filters,
                  eventTypes: const ['Ongoing Events', 'Taken'],
                  stateFilters: const ['Unconfirmed', 'Registered', 'Attended'],
                  groupByOptions: options ?? AttendeeGroupBy.values,
                  initialGroupBy: initial,
                  onCommit: (f, g) {
                    committedFilters = f;
                    committedGroupBy = g;
                    calls.add('commit');
                  },
                  onClearReload: () async => calls.add('clear-reload'),
                  onApplyReload: () async => calls.add('apply-reload'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> goToGroupBy(WidgetTester tester) async {
    await tester.tap(find.text('Group By'));
    await tester.pumpAndSettle();
  }

  testWidgets('has the same Filter and Group By tabs as the events sheet', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Filter & Group By'), findsOneWidget);
    expect(find.text('Event Type'), findsOneWidget);
    expect(find.text('Registration state'), findsOneWidget);
    expect(find.text('Ongoing Events'), findsOneWidget);
    // The staged filter shows as active.
    expect(find.text('Active Filters'), findsOneWidget);
  });

  testWidgets('the Group By tab lists None and the options it was given', (
    tester,
  ) async {
    await open(tester);
    await goToGroupBy(tester);
    expect(find.text('None'), findsOneWidget);
    for (final option in AttendeeGroupBy.values) {
      await tester.ensureVisible(find.text(option.label));
      expect(find.text(option.label), findsOneWidget, reason: option.label);
    }
  });

  testWidgets('only the options it is given are listed', (tester) async {
    await open(
      tester,
      options: [AttendeeGroupBy.ticket, AttendeeGroupBy.status],
    );
    await goToGroupBy(tester);
    expect(find.text('Ticket Type'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Event'), findsNothing);
    expect(find.text('Partner'), findsNothing);
  });

  testWidgets('Apply hands back the filters and the grouping, then reloads', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    await goToGroupBy(tester);
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(committedFilters, ['Registered', 'Taken']);
    expect(committedGroupBy, AttendeeGroupBy.status);
    expect(calls, ['commit', 'apply-reload']);
    expect(find.text('Filter & Group By'), findsNothing);
  });

  testWidgets('Clear All resets both, then reloads', (tester) async {
    await open(tester, initial: AttendeeGroupBy.ticket);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(committedFilters, isEmpty);
    expect(committedGroupBy, isNull);
    expect(calls, ['commit', 'clear-reload']);
  });

  testWidgets('closing the sheet commits nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Taken'));
    await goToGroupBy(tester);
    await tester.tap(find.text('Ticket Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Filter & Group By'), findsNothing);
    expect(calls, isEmpty);
    expect(committedFilters, ['untouched']);
  });

  testWidgets('the current grouping starts selected', (tester) async {
    await open(tester, initial: AttendeeGroupBy.ticket);
    await goToGroupBy(tester);
    final selected = tester.widgetList<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.checked == true,
      ),
    );
    expect(selected, hasLength(1));
    expect(
      find.descendant(
        of: find.byWidget(selected.single),
        matching: find.text('Ticket Type'),
      ),
      findsOneWidget,
    );
  });

  group('lays out without overflowing', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in const [
        Size(360, 640),
        Size(844, 390),
        Size(740, 320),
      ]) {
        testWidgets('$mode at $size', (tester) async {
          await open(tester, size: size, mode: mode);
          expect(tester.takeException(), isNull);
          await goToGroupBy(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
