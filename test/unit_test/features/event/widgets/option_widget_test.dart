import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/event/widget/option_widget.dart';

void main() {
  // The Details screen's tab row: a horizontal list 40 tall, so each pill is
  // handed exactly that height whatever its text needs.
  Widget tabRow(List<Widget> pills) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: pills),
      ),
    ),
  );

  for (final active in [true, false]) {
    testWidgets(
      'centres its title in the pill when ${active ? 'active' : 'inactive'}',
      (tester) async {
        await tester.pumpWidget(
          tabRow([OptionWidget(title: 'Tickets', isActive: active)]),
        );

        final pill = tester.getRect(find.byType(OptionWidget));
        final text = tester.getRect(find.text('Tickets'));

        expect(pill.height, 40);
        // Level with the middle of the pill, not sitting up at its top...
        expect(text.center.dy, closeTo(pill.center.dy, 0.5));
        // ...and with the same room on its left and right.
        expect(text.center.dx, closeTo(pill.center.dx, 0.5));
      },
    );
  }

  testWidgets('a pill is as wide as its title plus 30 and a border each side', (
    tester,
  ) async {
    await tester.pumpWidget(tabRow(const [OptionWidget(title: 'Tickets')]));

    final pill = tester.getRect(find.byType(OptionWidget));
    final text = tester.getRect(find.text('Tickets'));

    expect(pill.width, closeTo(text.width + 60 + 2, 0.5));
  });
}
