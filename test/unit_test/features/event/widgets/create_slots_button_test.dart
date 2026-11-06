import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/event/widget/create_slots_button.dart';

void main() {
  // No ripple: the test environment cannot decode Flutter's ink-sparkle shader.
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: child),
  );

  testWidgets('reads "Create Slots" while the event has none', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(CreateSlotsButton(onPressed: () => taps++)),
    );

    expect(find.text('Create Slots'), findsOneWidget);
    await tester.tap(find.text('Create Slots'));
    expect(taps, 1);
  });

  testWidgets('shows the slot total once the event has some', (tester) async {
    await tester.pumpWidget(
      host(CreateSlotsButton(count: 3, onPressed: () {})),
    );
    expect(find.text('Manage 3 slots'), findsOneWidget);
    expect(find.text('Create Slots'), findsNothing);

    await tester.pumpWidget(
      host(CreateSlotsButton(count: 1, onPressed: () {})),
    );
    expect(find.text('Manage 1 slot'), findsOneWidget);
  });

  testWidgets('spins and ignores taps while the event is being saved', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(CreateSlotsButton(isLoading: true, onPressed: () => taps++)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Create Slots'));
    expect(taps, 0);
  });
}
