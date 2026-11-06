import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/login/pages/login_layout.dart';
import 'package:mobo_event/features/login/pages/server_setup_screen.dart';
import 'package:mobo_event/features/login/providers/login_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every `/web/database/list` request the screen makes and fails each
/// one like a refused connection — so a test can count server lookups without
/// touching the network.
class _DatabaseListRequests extends HttpOverrides {
  final List<Uri> urls = [];

  int get count => urls.length;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _RefusingHttpClient(urls);
}

class _RefusingHttpClient implements HttpClient {
  _RefusingHttpClient(this._urls);

  final List<Uri> _urls;

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    _urls.add(url);
    return Future<HttpClientRequest>.error(
      const SocketException('Connection refused'),
    );
  }

  /// The rest of what `DatabaseService` touches is property setters and
  /// `close()`, none of which matter here.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _DatabaseListRequests requests;
  HttpOverrides? previousOverrides;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousOverrides = HttpOverrides.current;
    requests = _DatabaseListRequests();
    HttpOverrides.global = requests;
  });

  tearDown(() => HttpOverrides.global = previousOverrides);

  MaterialApp app(Widget home) => MaterialApp(
    theme: AppTheme.lightTheme.copyWith(splashFactory: InkRipple.splashFactory),
    home: home,
  );

  final urlField = find.byType(TextField).first;

  /// Opens the screen and hands back the provider it created for itself.
  Future<LoginProvider> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const ServerSetupScreen()));
    await tester.pumpAndSettle();
    return Provider.of<LoginProvider>(
      tester.element(find.byType(LoginUrlTextField)),
      listen: false,
    );
  }

  group('server error while typing', () {
    testWidgets('goes away on the next keystroke and stays away', (
      tester,
    ) async {
      final provider = await open(tester);

      // A lookup that fails leaves an error on screen.
      await tester.enterText(urlField, 'old.example.com');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final message = provider.errorMessage;
      expect(message, isNotNull, reason: 'the refused lookup sets an error');
      expect(find.text(message!), findsOneWidget);

      // Typing again clears it. 400ms is past the 320ms fade, and inside the
      // quiet period, so no new lookup has had the chance to fail yet.
      await tester.enterText(urlField, 'old.example.coms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(message), findsNothing);
      expect(provider.errorMessage, isNull);

      // …and it does not creep back on the keystroke after that.
      await tester.enterText(urlField, 'old.example.com');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(message), findsNothing);
      expect(provider.errorMessage, isNull);

      // Let the pending lookup run its course.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('still shows the error of a new lookup that fails', (
      tester,
    ) async {
      final provider = await open(tester);

      await tester.enterText(urlField, 'old.example.com');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final first = provider.errorMessage!;

      await tester.enterText(urlField, 'other.example.com');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(first), findsNothing);

      // The debounced lookup fails the same way, so the error returns.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.errorMessage, first);
      expect(find.text(first), findsOneWidget);
    });
  });

  group('database lookup while typing', () {
    testWidgets('waits for the URL to be left alone for a second', (
      tester,
    ) async {
      await open(tester);
      expect(requests.count, 0);

      await tester.enterText(urlField, 'odoo.example.com');
      await tester.pump(const Duration(milliseconds: 900));
      expect(requests.count, 0, reason: 'still inside the quiet second');

      await tester.pump(const Duration(milliseconds: 150));
      expect(requests.count, 1);
      expect(
        requests.urls.single.toString(),
        'https://odoo.example.com/web/database/list',
      );

      await tester.pump(const Duration(seconds: 3));
      expect(requests.count, 1, reason: 'one edit, one lookup');
    });

    testWidgets('typing again restarts the wait', (tester) async {
      await open(tester);

      await tester.enterText(urlField, 'odoo.example');
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests.count, 0);

      // 1.6s after the first keystroke — the first wait would have been over
      // at 1.0s, so this only holds if the second keystroke restarted it.
      await tester.enterText(urlField, 'odoo.example.com');
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests.count, 0);

      // A full second after the last keystroke.
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests.count, 1);
      expect(
        requests.urls.single.toString(),
        'https://odoo.example.com/web/database/list',
      );
    });

    testWidgets('a pasted URL with a protocol is looked up once, after the '
        'wait', (tester) async {
      final provider = await open(tester);

      // Pasting "http://…" switches the protocol selector, strips the prefix
      // from the field and reports the edit — three signals for one paste.
      await tester.enterText(urlField, 'http://odoo.example.com');
      await tester.pump(const Duration(milliseconds: 900));
      expect(requests.count, 0, reason: 'not before the quiet second');
      expect(provider.selectedProtocol, 'http://');

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(seconds: 3));
      expect(requests.count, 1);
      expect(
        requests.urls.single.toString(),
        'http://odoo.example.com/web/database/list',
      );
    });

    testWidgets('an emptied field asks nothing and shows no error', (
      tester,
    ) async {
      final provider = await open(tester);

      await tester.enterText(urlField, 'odoo.example.com');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(urlField, '');
      await tester.pump(const Duration(seconds: 3));

      expect(requests.count, 0);
      expect(provider.errorMessage, isNull);
    });

    testWidgets('an unparseable URL is never looked up', (tester) async {
      final provider = await open(tester);

      await tester.enterText(urlField, '[');
      await tester.pump(const Duration(seconds: 3));

      expect(requests.count, 0);
      expect(provider.errorMessage, isNull);
    });

    testWidgets('tapping a saved server looks it up straight away, once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'previous_server_urls': ['https://saved.example.com'],
      });
      await open(tester);

      // The last-used server is restored and looked up on arrival; that is
      // not what this test is about.
      await tester.pump(const Duration(seconds: 2));
      requests.urls.clear();

      await tester.enterText(urlField, 'sav');
      await tester.pump();
      await tester.pump();
      expect(find.text('https://saved.example.com'), findsOneWidget);

      await tester.tap(find.text('https://saved.example.com'));
      await tester.pump();
      expect(requests.count, 1, reason: 'a tap is deliberate: no wait');

      // The wait that "sav" started must not add a second lookup.
      await tester.pump(const Duration(seconds: 3));
      expect(requests.count, 1);
    });
  });
}
