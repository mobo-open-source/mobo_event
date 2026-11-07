import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/core/utils/database_expiry.dart';
import 'package:mobo_event/features/login/pages/login_layout.dart';
import 'package:mobo_event/features/login/pages/server_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MaterialApp app(Widget home) => MaterialApp(
    theme: AppTheme.lightTheme.copyWith(splashFactory: InkRipple.splashFactory),
    home: home,
  );

  group('LoginErrorDisplay', () {
    Future<double> heightOf(
      WidgetTester tester, {
      required String? error,
      double width = 280,
    }) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [LoginErrorDisplay(error: error)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(LoginErrorDisplay)).height;
    }

    testWidgets('keeps its 40px height with no error', (tester) async {
      expect(await heightOf(tester, error: null), 40);
    });

    testWidgets('keeps its 40px height for a short message', (tester) async {
      expect(await heightOf(tester, error: 'Invalid username'), 40);
    });

    testWidgets('grows for the expired-database message instead of '
        'overflowing', (tester) async {
      final height = await heightOf(
        tester,
        error: DatabaseExpiredException.message,
      );

      expect(height, greaterThan(40));
      expect(tester.takeException(), isNull);
      expect(find.text(DatabaseExpiredException.message), findsOneWidget);
    });
  });

  group('ServerSetupScreen', () {
    Future<void> open(WidgetTester tester, {String? initialError}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(ServerSetupScreen(initialError: initialError)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows why the user was sent back, on arrival', (tester) async {
      await open(tester, initialError: DatabaseExpiredException.message);

      expect(find.text(DatabaseExpiredException.message), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows no error when nothing sent the user back', (
      tester,
    ) async {
      await open(tester);

      expect(find.text(DatabaseExpiredException.message), findsNothing);
    });

    testWidgets('drops the notice once the server is edited', (tester) async {
      await open(tester, initialError: DatabaseExpiredException.message);

      await tester.enterText(find.byType(TextField).first, 'other.example.com');
      await tester.pump();

      expect(find.text(DatabaseExpiredException.message), findsNothing);

      // Let the debounced database lookup run its course.
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
