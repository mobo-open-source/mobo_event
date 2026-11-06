import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/home/widgets/kanban_board.dart';

void main() {
  // A kanban column is 300px wide with 12px of header padding on each side and
  // room for the "⋮" button, so the pill gets a little over 200px.
  Widget host(Widget pill) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: pill),
              ),
              const Icon(Icons.more_vert),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('a very long stage name is ellipsised instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StageCountPill(
          isDark: false,
          title: 'hrehdjdjdjdjdjdjjddjdjdjdf;fkfkdkdkdkdkdkdkdkdkdkdkdkdkdkdk',
          count: 0,
        ),
      ),
    );

    // An overflow is reported as a FlutterError, which the tester surfaces.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StageCountPill)).width, lessThanOrEqualTo(240));
  });

  testWidgets('the count stays visible when the name is cut', (tester) async {
    await tester.pumpWidget(
      host(
        const StageCountPill(
          isDark: false,
          title: 'A stage name that is far too long to fit in the header',
          count: 12,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(' (12)'), findsOneWidget);
  });

  testWidgets('a short name keeps its natural size', (tester) async {
    await tester.pumpWidget(
      host(const StageCountPill(isDark: true, title: 'New', count: 2)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('New'), findsOneWidget);
    expect(find.text(' (2)'), findsOneWidget);
    expect(tester.getSize(find.byType(StageCountPill)).width, lessThan(140));
  });
}
