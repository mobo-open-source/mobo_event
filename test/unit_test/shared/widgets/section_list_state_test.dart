import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/shared/widgets/section_list_state.dart';

void main() {
  // No ripple: the test environment cannot decode Flutter's ink-sparkle shader.
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('SectionHeader', () {
    testWidgets('shows the Add pill only when an action is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(SectionHeader(title: 'Tickets', onAdd: () {})),
      );
      expect(find.text('Add'), findsOneWidget);

      await tester.pumpWidget(host(const SectionHeader(title: 'Tickets')));
      expect(find.text('Add'), findsNothing);
      expect(find.text('Tickets'), findsOneWidget);
    });
  });

  group('SectionCard', () {
    testWidgets('shows its child and passes taps through', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(SectionCard(onTap: () => taps++, child: const Text('Name'))),
      );

      expect(find.text('Name'), findsOneWidget);
      await tester.tap(find.text('Name'));
      expect(taps, 1);
    });

    testWidgets('is inert without an onTap', (tester) async {
      await tester.pumpWidget(host(const SectionCard(child: Text('Name'))));

      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('is drawn by a border, not a shadow', (tester) async {
      await tester.pumpWidget(host(const SectionCard(child: Text('Name'))));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SectionCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.elevation, 0);
      expect(material.shadowColor, isNull);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.style, BorderStyle.solid);
      expect(shape.side.width, greaterThan(0));
    });
  });

  group('EmptySectionState', () {
    testWidgets('offers the add button and its hint when it can add', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          EmptySectionState(
            icon: HugeIcons.strokeRoundedTicket01,
            title: 'No tickets yet',
            actionLabel: 'Add Ticket',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.text('Add Ticket'), findsOneWidget);
      expect(find.text('Tap "Add Ticket" to get started'), findsOneWidget);

      await tester.tap(find.text('Add Ticket'));
      expect(taps, 1);
    });

    testWidgets('puts the add button below the icon, title and hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          EmptySectionState(
            icon: HugeIcons.strokeRoundedTicket01,
            title: 'No tickets yet',
            actionLabel: 'Add Ticket',
            onAction: () {},
          ),
        ),
      );

      final title = tester.getTopLeft(find.text('No tickets yet')).dy;
      final hint = tester.getTopLeft(
        find.text('Tap "Add Ticket" to get started'),
      );
      final button = tester.getTopLeft(find.text('Add Ticket'));
      expect(title, lessThan(hint.dy));
      expect(hint.dy, lessThan(button.dy));
    });

    testWidgets('compactAction makes the button shorter and label-sized', (
      tester,
    ) async {
      Widget empty({required bool compact}) => host(
        EmptySectionState(
          icon: HugeIcons.strokeRoundedTicket01,
          title: 'No tickets yet',
          actionLabel: 'Add Ticket',
          onAction: () {},
          compactAction: compact,
        ),
      );

      await tester.pumpWidget(empty(compact: false));
      final full = tester.getSize(find.bySubtype<ElevatedButton>());

      await tester.pumpWidget(empty(compact: true));
      final compact = tester.getSize(find.bySubtype<ElevatedButton>());

      expect(full.height, 48);
      expect(compact.height, 40);
      // It no longer spans the card.
      expect(compact.width, lessThan(full.width));
    });

    testWidgets('leaves the button and the hint pointing at it off when the '
        'account may not add', (tester) async {
      await tester.pumpWidget(
        host(
          const EmptySectionState(
            icon: HugeIcons.strokeRoundedTicket01,
            title: 'No tickets yet',
            actionLabel: 'Add Ticket',
          ),
        ),
      );

      // The title stays; nothing invites an action the server would refuse.
      expect(find.text('No tickets yet'), findsOneWidget);
      expect(find.text('Add Ticket'), findsNothing);
      expect(find.textContaining('to get started'), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
