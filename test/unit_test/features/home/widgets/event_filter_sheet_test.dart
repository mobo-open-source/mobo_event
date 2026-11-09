import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:mobo_event/features/home/widgets/event_filter_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../service/mock_home_services.dart';

void main() {
  late MockHomeServices services;
  late HomeProvider provider;
  late TextEditingController search;
  late FocusNode focus;

  setUp(() {
    services = MockHomeServices();
    when(
      () => services.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => []);
    provider = HomeProvider(
      services: services,
      access: AccessRights(call: (_) async => true, version: () async => '19.0'),
    )..version = '19.0';
    search = TextEditingController();
    focus = FocusNode();
  });

  tearDown(() {
    search.dispose();
    focus.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<HomeProvider>.value(
        value: provider,
        child: MaterialApp(
          // The default InkSparkle splash loads a shader the test engine
          // can't decode; the ripple is the same widget tree without it.
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
                  onPressed: () => showEventFilterSheet(
                    context,
                    searchController: search,
                    searchFocusNode: focus,
                  ),
                  child: const Text('open'),
                ),
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

  testWidgets('opens on the Filter tab with both tabs in the header', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Filter & Group By'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Group By'), findsOneWidget);
    expect(find.text('Event Type'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Display as a simple list'), findsNothing);
  });

  testWidgets('the Group By tab lists None and every Odoo group-by', (
    tester,
  ) async {
    await open(tester);
    await goToGroupBy(tester);
    for (final label in [
      'None',
      'Stage',
      'Responsible',
      'Template',
      'Start Date',
      'Venue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Display as a simple list'), findsOneWidget);
    expect(find.text('Event Type'), findsNothing);
  });

  testWidgets('Venue is not offered on Odoo 17', (tester) async {
    provider.version = '17.0';
    await open(tester);
    await goToGroupBy(tester);
    expect(find.text('Venue'), findsNothing);
    expect(find.text('Stage'), findsOneWidget);
  });

  testWidgets('the current grouping is the ticked option when it opens', (
    tester,
  ) async {
    provider.groupBy = EventGroupBy.template;
    await open(tester);
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
        matching: find.text('Template'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Apply commits the grouping without refetching the events', (
    tester,
  ) async {
    await open(tester);
    await goToGroupBy(tester);
    await tester.tap(find.text('Responsible'));
    await tester.pumpAndSettle();
    // Staged only: the list is untouched until Apply.
    expect(provider.groupBy, isNull);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(provider.groupBy, EventGroupBy.responsible);
    expect(find.text('Filter & Group By'), findsNothing);
    verifyNever(
      () => services.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    );
  });

  testWidgets('Apply with a changed filter refetches and keeps the grouping', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Published'));
    await tester.pumpAndSettle();
    await goToGroupBy(tester);
    await tester.tap(find.text('Stage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(provider.activeFilters, ['Published']);
    expect(provider.groupBy, EventGroupBy.stage);
    verify(
      () => services.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    ).called(1);
  });

  testWidgets('closing the sheet discards what was ticked', (tester) async {
    await open(tester);
    await tester.tap(find.text('Published'));
    await goToGroupBy(tester);
    await tester.ensureVisible(find.text('Venue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venue'));
    await tester.pumpAndSettle();
    // The header's close button is the sheet's only IconButton.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Filter & Group By'), findsNothing);
    expect(provider.activeFilters, isEmpty);
    expect(provider.groupBy, isNull);
  });

  testWidgets('Clear All resets the filters and the grouping', (tester) async {
    provider
      ..activeFilters = ['Online']
      ..groupBy = EventGroupBy.venue;
    search.text = 'conf';
    await open(tester);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(provider.activeFilters, isEmpty);
    expect(provider.groupBy, isNull);
    expect(search.text, isEmpty);
    verify(
      () => services.gettingEventsShort(
        search: any(named: 'search'),
        filter: any(named: 'filter'),
      ),
    ).called(1);
  });

  testWidgets('Kanban has no note: Group By drives its columns too', (
    tester,
  ) async {
    provider.viewMode = HomeViewMode.kanban;
    await open(tester);
    await goToGroupBy(tester);
    expect(find.textContaining('Kanban always groups'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    // All six choices are on offer, as in the List view.
    for (final label in ['Stage', 'Responsible', 'Template', 'Venue']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('None says what it does on the board', (tester) async {
    provider.viewMode = HomeViewMode.kanban;
    await open(tester);
    await goToGroupBy(tester);
    expect(find.text('Show the default stage columns'), findsOneWidget);
    expect(find.text('Display as a simple list'), findsNothing);
  });

  testWidgets('the List view\'s None is a simple list', (tester) async {
    await open(tester);
    await goToGroupBy(tester);
    expect(find.text('Display as a simple list'), findsOneWidget);
  });

  group('lays out without overflowing', () {
    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      for (final size in const [
        Size(360, 640), // small phone
        Size(390, 844), // phone
        Size(844, 390), // phone, landscape
        Size(740, 320), // short landscape
      ]) {
        testWidgets('$mode at $size', (tester) async {
          await open(tester, size: size, mode: mode);
          expect(tester.takeException(), isNull);
          await goToGroupBy(tester);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Start Date'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Start Date'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
