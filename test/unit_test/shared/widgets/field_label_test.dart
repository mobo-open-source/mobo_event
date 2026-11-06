import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/shared/widgets/forms/field_label.dart';
import 'package:mobo_event/shared/widgets/toggles/mobo_checkbox.dart';

void main() {
  const first = Key('first');
  const second = Key('second');
  const third = Key('third');
  const column = Key('column');

  Widget host(List<Widget> children) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          key: column,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: spacedFormChildren(children),
        ),
      ),
    ),
  );

  Widget label(String text) =>
      FieldLabel(text, bottomGap: AppTheme.labelGap);

  testWidgets('a label sits closer to its field than to the one above', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        label('Name'),
        const SizedBox(key: first, height: 48),
        label('Phone'),
        const SizedBox(key: second, height: 48),
      ]),
    );

    final name = tester.getRect(find.text('Name'));
    final phone = tester.getRect(find.text('Phone'));
    final firstField = tester.getRect(find.byKey(first));
    final secondField = tester.getRect(find.byKey(second));

    // Label -> its field: billing's tight pairing...
    expect(firstField.top - name.bottom, closeTo(AppTheme.labelGap, 0.01));
    expect(secondField.top - phone.bottom, closeTo(AppTheme.labelGap, 0.01));
    // ...and the field above -> the next label: the larger gap, so the label
    // reads as belonging to the field under it.
    expect(phone.top - firstField.bottom, closeTo(AppTheme.fieldGap, 0.01));
    expect(AppTheme.fieldGap, greaterThan(AppTheme.labelGap));
  });

  testWidgets('children that are not labels keep their 10px gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        const SizedBox(key: first, height: 48),
        const SizedBox(key: second, height: 48),
        const SizedBox(key: third, height: 48),
      ]),
    );

    final a = tester.getRect(find.byKey(first));
    final b = tester.getRect(find.byKey(second));
    final c = tester.getRect(find.byKey(third));

    expect(b.top - a.bottom, closeTo(10, 0.01));
    expect(c.top - b.bottom, closeTo(10, 0.01));
  });

  testWidgets('a field a checkbox switches on sits 16 below its box', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        MoboCheckboxTile(
          title: 'Limit registration',
          value: true,
          onChanged: (_) {},
        ),
        label('Registration Limit'),
        const SizedBox(key: first, height: 48),
      ]),
    );

    final box = tester.getRect(find.byType(MoboCheckbox));
    final tile = tester.getRect(find.byType(MoboCheckboxTile));
    final limit = tester.getRect(find.text('Registration Limit'));

    // The tile's own 10px tap padding plus 6: 16 from the box to the label,
    // like the gap between two fields, not the 26 a full field gap would add.
    expect(limit.top - tile.bottom, closeTo(6, 0.01));
    expect(limit.top - box.bottom, closeTo(16, 0.01));
  });

  testWidgets('the form toggle padding keeps two toggles 12px apart', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        MoboCheckboxTile(
          key: first,
          title: 'Multiple Slot',
          value: false,
          onChanged: (_) {},
          padding: formToggleRowPadding,
        ),
        MoboCheckboxTile(
          title: 'Limit registration',
          value: false,
          onChanged: (_) {},
          padding: formToggleRowPadding,
        ),
        label('Registration Limit'),
        const SizedBox(height: 48),
      ]),
    );

    final boxes = tester.getRect(find.byType(MoboCheckbox).first);
    final nextBox = tester.getRect(find.byType(MoboCheckbox).last);
    final limit = tester.getRect(find.text('Registration Limit'));

    // 6px of padding under one row + 6 above the next.
    expect(nextBox.top - boxes.bottom, closeTo(12, 0.01));
    // Whatever the tile's padding, the label is still 16 below the box.
    expect(limit.top - nextBox.bottom, closeTo(16, 0.01));
  });

  testWidgets('stacked toggle rows have no form gap between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        MoboCheckboxTile(
          key: first,
          title: 'Multiple Slot',
          value: false,
          onChanged: (_) {},
        ),
        MoboCheckboxTile(
          key: second,
          title: 'Limit registration',
          value: false,
          onChanged: (_) {},
        ),
        const SizedBox(key: third, height: 48),
      ]),
    );

    final a = tester.getRect(find.byKey(first));
    final b = tester.getRect(find.byKey(second));
    final c = tester.getRect(find.byKey(third));

    // Each row's own 10px tap padding is all that separates their boxes.
    expect(b.top - a.bottom, closeTo(0, 0.01));
    // A toggle followed by something that is not a toggle keeps the 10.
    expect(c.top - b.bottom, closeTo(10, 0.01));
  });

  testWidgets('a toggle group counts as a toggle row', (tester) async {
    await tester.pumpWidget(
      host([
        FormToggleGroup(
          key: first,
          children: [
            MoboCheckboxTile(
              title: 'Multiple Slot',
              value: true,
              onChanged: (_) {},
            ),
            const SizedBox(height: 36),
          ],
        ),
        MoboCheckboxTile(
          key: second,
          title: 'Limit registration',
          value: false,
          onChanged: (_) {},
        ),
      ]),
    );

    final group = tester.getRect(find.byKey(first));
    final next = tester.getRect(find.byKey(second));

    // The group's members touch (42 + 36), and the next toggle follows it
    // without the form's gap.
    expect(group.height, closeTo(42 + 36, 0.01));
    expect(next.top - group.bottom, closeTo(0, 0.01));
  });

  group('formCardHeader', () {
    testWidgets('has the same room above the title as below it', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: Container(
                  key: first,
                  child: formCardHeader('Hi', false),
                ),
              ),
            ),
          ),
        ),
      );

      final header = tester.getRect(find.byKey(first));
      final title = tester.getRect(find.text('Hi'));
      final rule = tester.getRect(find.byType(Divider));

      expect(title.top - header.top, closeTo(16, 0.01));
      expect(rule.top - title.bottom, closeTo(16, 0.01));
      // The rule is the bottom edge of the header, spanning its width.
      expect(header.bottom - rule.bottom, closeTo(0, 0.01));
      expect(rule.width, 300);
    });
  });

  testWidgets('the last child has no gap after it', (tester) async {
    await tester.pumpWidget(
      host([
        const SizedBox(key: first, height: 48),
        const SizedBox(key: second, height: 48),
      ]),
    );

    // Two 48px children with the 10px between them and nothing after.
    expect(tester.getSize(find.byKey(column)).height, 48 + 10 + 48);
  });

  group('formCardBody', () {
    Widget body(List<Widget> children) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Container(key: first, child: formCardBody(children)),
          ),
        ),
      ),
    );

    testWidgets('pads 16 all round, with no extra tail under the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        body(const [
          SizedBox(height: 48),
          SizedBox(height: 48),
        ]),
      );

      // 16 + 48 + 10 + 48 + 16, as in billing's MoboFormCard.
      expect(tester.getSize(find.byKey(first)).height, 16 + 48 + 10 + 48 + 16);
    });

    testWidgets('stays 16 from the box whatever the row\'s own padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        body([
          const SizedBox(height: 48),
          MoboCheckboxTile(
            title: 'Limit registration',
            value: false,
            onChanged: (_) {},
            padding: formToggleRowPadding,
          ),
        ]),
      );

      final box = tester.getRect(find.byType(MoboCheckbox));
      final card = tester.getRect(find.byKey(first));

      expect(card.bottom - box.bottom, closeTo(16, 0.01));
    });

    testWidgets('a card ending in a checkbox row stays 16 from the box', (
      tester,
    ) async {
      await tester.pumpWidget(
        body([
          const SizedBox(height: 48),
          MoboCheckboxTile(
            title: 'Limit registration',
            value: false,
            onChanged: (_) {},
          ),
        ]),
      );

      final tile = tester.getRect(find.byType(MoboCheckboxTile));
      final box = tester.getRect(find.byType(MoboCheckbox));
      final card = tester.getRect(find.byKey(first));

      // The tile's own 10px tap padding plus 6 of card padding.
      expect(card.bottom - box.bottom, closeTo(16, 0.01));
      expect(card.bottom - tile.bottom, closeTo(6, 0.01));
    });
  });

  testWidgets('a FieldLabel without a bottomGap adds no space of its own', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              FieldLabel('Name'),
              SizedBox(key: first, height: 48),
            ],
          ),
        ),
      ),
    );

    final name = tester.getRect(find.text('Name'));
    expect(tester.getRect(find.byKey(first)).top, closeTo(name.bottom, 0.01));
  });
}
