import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/event/pages/event_add_screen.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/service/mock_home_services.dart';
import '../service/mock_event_detailed_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openAddScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rights = AccessRights();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccessRights>.value(value: rights),
          ChangeNotifierProvider(
            create: (_) =>
                EventDetailedProvider(services: MockEventDetailedService()),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                HomeProvider(services: MockHomeServices(), access: rights),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventAddScreen()),
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

  Future<void> tapBack(WidgetTester tester) => tester.tap(
    find.descendant(of: find.byType(AppBar), matching: find.byType(HugeIcon)),
  );

  testWidgets('back leaves without asking when nothing was entered', (
    tester,
  ) async {
    await openAddScreen(tester);
    expect(find.text('Create an event'), findsOneWidget);

    await tapBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('Discard event'), findsNothing);
    expect(find.text('Create an event'), findsNothing);
  });

  testWidgets('back asks first once something was typed, and Stay keeps the '
      'form', (tester) async {
    await openAddScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'Live Music');
    await tester.pump();
    await tapBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('Discard event'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Create an event'), findsOneWidget);

    await tapBack(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Create an event'), findsNothing);
  });

  testWidgets('typing then clearing the name is not a change', (tester) async {
    await openAddScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'x');
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tapBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('Discard event'), findsNothing);
  });
}
