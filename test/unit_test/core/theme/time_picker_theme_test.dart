import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';

void main() {
  testWidgets('the time picker types with a white caret', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // No ripple: the test environment cannot decode the ink-sparkle shader.
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 5),
              // Keyboard entry: the picker's hour and minute become fields.
              initialEntryMode: TimePickerEntryMode.input,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  timePickerTheme: AppTheme.timePickerTheme(false),
                  textSelectionTheme: AppTheme.timePickerTextSelection,
                ),
                child: child!,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields, hasLength(2));
    for (final field in fields) {
      // On the brand-filled field being edited, a brand caret is invisible.
      expect(field.cursorColor, Colors.white);
    }
  });

  test('a selection in the picker is a white wash; the handle stays brand', () {
    final theme = AppTheme.timePickerTextSelection;

    expect(theme.cursorColor, Colors.white);
    expect(theme.selectionColor, Colors.white.withValues(alpha: 0.35));
    expect(theme.selectionHandleColor, AppTheme.primaryColor);
  });
}
