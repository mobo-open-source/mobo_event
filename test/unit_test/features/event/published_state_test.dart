import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/model/event_sample_response.dart';
import 'package:mobo_event/features/event/widget/event_publish_row.dart';
import 'package:mobo_event/features/event/widget/published_toggle.dart';
import 'package:mobo_event/shared/widgets/toggles/mobo_toggle.dart';

/// The `search_read` row of an event, with only what the model insists on.
/// [extra] adds or overrides fields, the way each Odoo release does.
Map<String, dynamic> eventRow([Map<String, dynamic> extra = const {}]) => {
  'id': 7,
  'display_name': 'Launch',
  'date_begin': '2026-10-12 09:00:00',
  'date_end': '2026-10-12 17:00:00',
  'seats_taken': 0,
  'website_id': false,
  'company_id': false,
  ...extra,
};

Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      // The default ink-sparkle splash loads a shader the headless test
      // engine cannot decode, which fails the first tap in a process.
      theme: ThemeData(
        brightness: brightness,
        splashFactory: NoSplash.splashFactory,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );

void main() {
  group('EventDetailedModel publish state', () {
    test('website_published true is live', () {
      final e = EventDetailedModel.fromJson(
        eventRow({'website_published': true, 'is_published': true}),
      );
      expect(e.websitePublished, isTrue);
      expect(e.isLive, isTrue);
      expect(e.hasPublishState, isTrue);
      expect(e.isPublishScheduled, isFalse);
    });

    test('website_published false is known but not live', () {
      final e = EventDetailedModel.fromJson(
        eventRow({'website_published': false, 'is_published': false}),
      );
      expect(e.websitePublished, isFalse);
      expect(e.isLive, isFalse);
      expect(e.hasPublishState, isTrue);
    });

    test('no website_event means no published state at all', () {
      // The fields are absent, which is not the same as unpublished.
      final e = EventDetailedModel.fromJson(eventRow());
      expect(e.websitePublished, isNull);
      expect(e.hasPublishState, isFalse);
      expect(e.isLive, isFalse);
    });

    test('is_published answers when website_published is not on the row', () {
      final e = EventDetailedModel.fromJson(eventRow({'is_published': true}));
      expect(e.isLive, isTrue);
    });

    test('Odoo 17-19 have no publish_on', () {
      final e = EventDetailedModel.fromJson(
        eventRow({'website_published': false}),
      );
      expect(e.publishOn, isNull);
      expect(e.isPublishScheduled, isFalse);
    });

    test('Odoo 20 sends publish_on=false when nothing is scheduled', () {
      final e = EventDetailedModel.fromJson(
        eventRow({'website_published': false, 'publish_on': false}),
      );
      expect(e.publishOn, isNull);
      expect(e.isPublishScheduled, isFalse);
    });

    test('a scheduled publish is not live yet', () {
      final e = EventDetailedModel.fromJson(
        eventRow({
          'website_published': false,
          'publish_on': '2026-11-01 08:30:00',
        }),
      );
      expect(e.publishOn, isNotNull);
      expect(e.isPublishScheduled, isTrue);
      expect(e.isLive, isFalse);
    });
  });

  group('EventValue (create-form defaults)', () {
    Map<String, dynamic> sample([Map<String, dynamic> extra = const {}]) => {
      'date_begin': '2026-10-12 09:00:00',
      'date_end': '2026-10-12 17:00:00',
      'date_tz': 'UTC',
      'company_id': {'id': 1, 'display_name': 'Co'},
      'organizer_id': {'id': 2, 'display_name': 'Org'},
      'user_id': {'id': 3, 'display_name': 'Me'},
      'address_id': {'id': 4, 'display_name': 'Hall'},
      ...extra,
    };

    test('starts unpublished by default', () {
      expect(EventValue.fromJson(sample()).websitePublished, isFalse);
      expect(
        EventValue.fromJson(
          sample({'website_published': false}),
        ).websitePublished,
        isFalse,
      );
    });

    test('follows a server default that publishes', () {
      expect(
        EventValue.fromJson(
          sample({'website_published': true}),
        ).websitePublished,
        isTrue,
      );
    });
  });

  group('MoboToggleTile', () {
    testWidgets('tapping the row flips the value', (tester) async {
      bool? got;
      await tester.pumpWidget(
        host(
          MoboToggleTile(
            title: 'Published',
            value: false,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Published'));
      expect(got, isTrue);
    });

    testWidgets('a locked row ignores taps and dims the switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MoboToggleTile(
            title: 'Published',
            value: false,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('Published'));
      expect(tester.takeException(), isNull);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(MoboToggleTile),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('no help means no "?"', (tester) async {
      await tester.pumpWidget(
        host(
          MoboToggleTile(title: 'Published', value: false, onChanged: (_) {}),
        ),
      );
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('tapping the "?" shows the help and leaves the switch alone', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(
        host(
          MoboToggleTile(
            title: 'Published',
            value: false,
            onChanged: (_) => toggles++,
            helpTitle: 'Visible on current website',
            helpLines: const ['On: shown.', 'Off: hidden.'],
          ),
        ),
      );
      expect(
        find.text('Visible on current website', findRichText: true),
        findsNothing,
      );

      await tester.tap(find.byType(Tooltip));
      await tester.pump(const Duration(milliseconds: 200));

      expect(toggles, 0);
      expect(
        find.textContaining('Visible on current website', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('• On: shown.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('• Off: hidden.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('help renders in the dark theme too', (tester) async {
      await tester.pumpWidget(
        host(
          MoboToggleTile(
            title: 'Published',
            value: true,
            onChanged: (_) {},
            helpLines: const ['Only a line.'],
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.tap(find.byType(Tooltip));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      // No title: the first bullet starts the bubble rather than a blank line.
      expect(
        find.textContaining('• Only a line.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('\n• Only a line.', findRichText: true),
        findsNothing,
      );
    });
  });

  group('PublishedToggle', () {
    testWidgets('editable when nothing is scheduled', (tester) async {
      bool? got;
      await tester.pumpWidget(
        host(PublishedToggle(value: false, onChanged: (v) => got = v)),
      );
      await tester.tap(find.text('Published'));
      expect(got, isTrue);
      expect(find.textContaining('Scheduled to publish'), findsNothing);
    });

    testWidgets('locks while a publish is scheduled and says when', (
      tester,
    ) async {
      var changed = false;
      await tester.pumpWidget(
        host(
          PublishedToggle(
            value: false,
            scheduledOn: DateTime(2026, 11, 1, 8, 30),
            onChanged: (_) => changed = true,
          ),
        ),
      );
      await tester.tap(find.text('Published'));
      expect(changed, isFalse);
      expect(
        find.text('Scheduled to publish on 01 Nov 2026, 08:30 AM'),
        findsOneWidget,
      );
    });
  });

  group('EventPublishRow', () {
    EventDetailedModel event(Map<String, dynamic> extra) =>
        EventDetailedModel.fromJson(eventRow(extra));

    testWidgets('published', (tester) async {
      await tester.pumpWidget(
        host(EventPublishRow(event: event({'website_published': true}))),
      );
      expect(find.text('Published'), findsOneWidget);
      // The same globe in every state; the word and colour carry the state.
      final globe = tester.widget<HugeIcon>(find.byType(HugeIcon));
      expect(globe.icon, HugeIcons.strokeRoundedGlobal);
    });

    testWidgets('not published', (tester) async {
      await tester.pumpWidget(
        host(EventPublishRow(event: event({'website_published': false}))),
      );
      expect(find.text('Not published'), findsOneWidget);
    });

    testWidgets('scheduled (Odoo 20)', (tester) async {
      await tester.pumpWidget(
        host(
          EventPublishRow(
            event: event({
              'website_published': false,
              'publish_on': '2026-11-01 08:30:00',
            }),
          ),
        ),
      );
      expect(find.textContaining('Scheduled'), findsOneWidget);
    });

    testWidgets('renders in the dark theme', (tester) async {
      await tester.pumpWidget(
        host(
          EventPublishRow(event: event({'website_published': true})),
          brightness: Brightness.dark,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Published'), findsOneWidget);
    });
  });
}
