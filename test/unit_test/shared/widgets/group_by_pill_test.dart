import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/shared/widgets/filters/group_by_pill.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget pill, ThemeMode mode) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: Scaffold(body: Center(child: pill)),
        ),
      );

  BoxDecoration decoration(WidgetTester tester) => tester
      .widget<Container>(
        find.descendant(
          of: find.byType(GroupByPill),
          matching: find.byType(Container),
        ),
      )
      .decoration! as BoxDecoration;

  testWidgets('is the active-filter badge\'s black pill in light mode', (
    tester,
  ) async {
    await pump(tester, const GroupByPill(label: 'Stage'), ThemeMode.light);
    expect(decoration(tester).color, Colors.black);
    expect(find.text('Stage'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Stage'));
    expect(text.style!.color, Colors.white);
    expect(tester.getSize(find.byType(GroupByPill)).height, 36);
  });

  testWidgets('hugs its label however much width it is offered', (
    tester,
  ) async {
    // The toolbar offers the pill the whole slot left of the view selector:
    // an Expanded, with a left-aligned child.
    await pump(
      tester,
      const SizedBox(
        width: 360,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GroupByPill(label: 'Stage'),
              ),
            ),
          ],
        ),
      ),
      ThemeMode.light,
    );
    final size = tester.getSize(find.byType(GroupByPill));
    expect(size.height, 36);
    expect(size.width, lessThan(150));
    // And it is vertically centred in its 36px, with the label beside the icon.
    final pill = tester.getRect(find.byType(GroupByPill));
    final text = tester.getRect(find.text('Stage'));
    expect(text.center.dy, closeTo(pill.center.dy, 1));
  });

  testWidgets('a pill with no fixed height hugs its label too', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        width: 360,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GroupByPill(label: 'Ticket Type', height: null),
              ),
            ),
          ],
        ),
      ),
      ThemeMode.light,
    );
    expect(tester.getSize(find.byType(GroupByPill)).width, lessThan(200));
  });

  testWidgets('inverts to white in dark mode, like the badge', (tester) async {
    await pump(tester, const GroupByPill(label: 'Stage'), ThemeMode.dark);
    expect(decoration(tester).color, Colors.white);
    expect(tester.widget<Text>(find.text('Stage')).style!.color, Colors.black);
  });

  testWidgets('can be sized to a smaller badge', (tester) async {
    await pump(
      tester,
      const GroupByPill(
        label: 'Ticket Type',
        height: null,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        radius: 5,
        fontSize: 14,
      ),
      ThemeMode.light,
    );
    expect(tester.getSize(find.byType(GroupByPill)).height, lessThan(36));
    expect(
      decoration(tester).borderRadius,
      BorderRadius.circular(5),
    );
  });
}
