import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/pages/event_details_screen.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:mobo_event/features/questions/model/event_question.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/features/scheduler/model/event_mail_scheduler.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../home/service/mock_home_services.dart';
import '../../questions/service/mock_question_services.dart';
import '../../scheduler/service/mock_mail_scheduler_services.dart';
import '../service/mock_event_detailed_service.dart';

/// The providers Details reads, over mock services, plus helpers to script
/// what the server answers.
class _Harness {
  final detailService = MockEventDetailedService();
  final mailService = MockMailSchedularServices();
  final questionService = MockQuestionServices();
  final homeService = MockHomeServices();
  final rights = AccessRights();

  late final detail = EventDetailedProvider(services: detailService);
  late final mails = MailSchedulerProvider(services: mailService);
  late final questions = QuestionsProvider(services: questionService);
  late final home = HomeProvider(services: homeService, access: rights);

  _Harness() {
    when(
      () => detailService.getModelFields(any()),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      () => homeService.gettingEventsShort(filter: [], search: ''),
    ).thenAnswer((_) async => []);
  }

  void event(int id, Future<EventDetailedModel> Function() answer) => when(
    () => detailService.gettingEventDetails(id, fields: any(named: 'fields')),
  ).thenAnswer((_) => answer());

  void tickets(int id, Future<List<EventTicket>> Function() answer) => when(
    () => detailService.getEventTickets(id, fields: any(named: 'fields')),
  ).thenAnswer((_) => answer());

  void mailList(int id, Future<List<EventMailScheduler>> Function() answer) =>
      when(
        () => mailService.fetchCommunication(id),
      ).thenAnswer((_) => answer());

  void questionList(int id, Future<List<EventQuestion>> Function() answer) =>
      when(
        () => questionService.fetchQuestionsWithAnswers(id),
      ).thenAnswer((_) => answer());

  /// Every request answers straight away, with an empty tab.
  void allAnswer(int id) {
    event(id, () => Future.value(_event(id)));
    tickets(id, () => Future.value([]));
    mailList(id, () => Future.value([]));
    questionList(id, () => Future.value([]));
  }

  Widget app({int id = 1, bool refreshHome = false}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<EventDetailedProvider>.value(value: detail),
      ChangeNotifierProvider<MailSchedulerProvider>.value(value: mails),
      ChangeNotifierProvider<QuestionsProvider>.value(value: questions),
      ChangeNotifierProvider<HomeProvider>.value(value: home),
      ChangeNotifierProvider<AccessRights>.value(value: rights),
    ],
    child: MaterialApp(
      home: EventDetailsScreen(id: id, refreshHome: refreshHome),
    ),
  );
}

void _phone(WidgetTester tester, {Size size = const Size(400, 800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('requests the event, tickets, mails and questions all at once, '
      'and reloads neither the stages nor the Home list', (tester) async {
    _phone(tester);
    final h = _Harness();
    h.event(1, () => Completer<EventDetailedModel>().future);
    h.tickets(1, () => Completer<List<EventTicket>>().future);
    h.mailList(1, () => Completer<List<EventMailScheduler>>().future);
    h.questionList(1, () => Completer<List<EventQuestion>>().future);

    await tester.pumpWidget(h.app());
    await tester.pump();

    // Nothing has answered, yet all four are already out — none waits for
    // another.
    verify(
      () => h.detailService.gettingEventDetails(1, fields: any(named: 'fields')),
    ).called(1);
    verify(
      () => h.detailService.getEventTickets(1, fields: any(named: 'fields')),
    ).called(1);
    verify(() => h.mailService.fetchCommunication(1)).called(1);
    verify(() => h.questionService.fetchQuestionsWithAnswers(1)).called(1);

    // Home has loaded the stages and the event list already.
    verifyNever(() => h.homeService.gettingStage());
    verifyNever(
      () => h.homeService.gettingEventsShort(
        filter: any(named: 'filter'),
        search: any(named: 'search'),
      ),
    );
  });

  testWidgets('opens on the event as soon as it is in, before the tickets',
      (tester) async {
    _phone(tester);
    final h = _Harness();
    final tickets = Completer<List<EventTicket>>();
    h.event(1, () => Future.value(_event(1)));
    h.tickets(1, () => tickets.future);
    h.mailList(1, () => Future.value([]));
    h.questionList(1, () => Future.value([]));

    await tester.pumpWidget(h.app());
    await _settle(tester);

    expect(find.text('event 1'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(h.detail.isTicketLoading, true);

    tickets.complete([]);
    await _settle(tester);
    expect(h.detail.isTicketLoading, false);
  });

  testWidgets('never shows the previous event while the next one loads',
      (tester) async {
    _phone(tester);
    final h = _Harness();
    // Event 2 was the last one opened, and is fully loaded.
    h.detail.eventModel = _event(2);
    h.detail.isLoading = false;
    h.detail.isTicketLoading = false;
    h.event(1, () => Completer<EventDetailedModel>().future);
    h.tickets(1, () => Completer<List<EventTicket>>().future);
    h.mailList(1, () => Completer<List<EventMailScheduler>>().future);
    h.questionList(1, () => Completer<List<EventQuestion>>().future);

    await tester.pumpWidget(h.app());

    // The very first frame, before the load has even started.
    expect(find.text('event 2'), findsNothing);
    await tester.pump();
    expect(find.text('event 2'), findsNothing);
  });

  testWidgets('an event that cannot be loaded shows Retry, not a skeleton '
      'for ever, and Retry loads it', (tester) async {
    _phone(tester);
    final h = _Harness();
    h.event(1, () => Future<EventDetailedModel>.error(Exception('boom')));
    h.tickets(1, () => Future.value([]));
    h.mailList(1, () => Future.value([]));
    h.questionList(1, () => Future.value([]));

    await tester.pumpWidget(h.app());
    await _settle(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('event 1'), findsNothing);

    h.allAnswer(1);
    await tester.tap(find.text('Retry'));
    await _settle(tester);

    expect(find.text('event 1'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a tab that fails to load only gets a message; the event '
      'still shows', (tester) async {
    _phone(tester);
    final h = _Harness();
    h.allAnswer(1);
    h.questionList(1, () => Future<List<EventQuestion>>.error(Exception('tab down')));

    await tester.pumpWidget(h.app());
    await _settle(tester);

    expect(find.text('event 1'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('tab down'), findsOneWidget);
  });

  testWidgets('pulling down reloads all of it', (tester) async {
    _phone(tester);
    final h = _Harness();
    h.allAnswer(1);

    await tester.pumpWidget(h.app());
    await _settle(tester);
    expect(find.text('event 1'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await _settle(tester);

    verify(
      () => h.detailService.gettingEventDetails(1, fields: any(named: 'fields')),
    ).called(2);
    verify(() => h.mailService.fetchCommunication(1)).called(2);
    verify(() => h.questionService.fetchQuestionsWithAnswers(1)).called(2);
    expect(find.text('event 1'), findsOneWidget);
  });

  group('Home list', () {
    testWidgets('is reloaded in the background when asked to', (tester) async {
      _phone(tester);
      final h = _Harness();
      h.allAnswer(1);

      await tester.pumpWidget(h.app(refreshHome: true));
      await _settle(tester);

      verify(
        () => h.homeService.gettingEventsShort(filter: [], search: ''),
      ).called(1);
      expect(find.text('event 1'), findsOneWidget);
    });

    testWidgets('a failed reload never breaks the screen', (tester) async {
      _phone(tester);
      final h = _Harness();
      h.allAnswer(1);
      when(
        () => h.homeService.gettingEventsShort(filter: [], search: ''),
      ).thenAnswer((_) => Future.error(Exception('home down')));

      await tester.pumpWidget(h.app(refreshHome: true));
      await _settle(tester);

      expect(find.text('event 1'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('is left alone on a plain open', (tester) async {
      _phone(tester);
      final h = _Harness();
      h.allAnswer(1);

      await tester.pumpWidget(h.app());
      await _settle(tester);

      verifyNever(
        () => h.homeService.gettingEventsShort(
          filter: any(named: 'filter'),
          search: any(named: 'search'),
        ),
      );
    });
  });

  group('Field list', () {
    testWidgets('is loaded when Home has not', (tester) async {
      _phone(tester);
      final h = _Harness();
      h.allAnswer(1);

      await tester.pumpWidget(h.app());
      await _settle(tester);

      verify(() => h.detailService.getModelFields('event.event')).called(1);
    });

    testWidgets('is not loaded again when Home already did', (tester) async {
      _phone(tester);
      final h = _Harness();
      h.detail.eventFields = {'name': {}};
      h.allAnswer(1);

      await tester.pumpWidget(h.app());
      await _settle(tester);

      verifyNever(() => h.detailService.getModelFields(any()));
      expect(find.text('event 1'), findsOneWidget);
    });
  });

  testWidgets('lays out in landscape too: skeleton, then the event and tabs',
      (tester) async {
    _phone(tester, size: const Size(900, 420));
    final h = _Harness();
    final event = Completer<EventDetailedModel>();
    h.allAnswer(1);
    h.event(1, () => event.future);

    await tester.pumpWidget(h.app());
    await tester.pump();
    expect(find.text('event 1'), findsNothing);

    event.complete(_event(1));
    await _settle(tester);
    expect(find.text('event 1'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

EventDetailedModel _event(int id) => EventDetailedModel(
  id: id,
  name: 'event $id',
  start: DateTime(2026),
  end: DateTime(2026),
  location: '',
  attended: 0,
  maxSeats: 10,
  organizerId: 10,
  organizerName: '',
  stageId: 2,
  stage: '',
  websiteIds: [],
  websiteMenu: true,
  startWithTimezone: DateTime(2026),
  endWithTimezone: DateTime(2026),
  seatTaken: 0,
  kanbanState: '',
  slotCount: 1,
  seatsAvailable: 10,
  isMultiSlots: false,
  seatsLimited: true,
  badgeFormat: '',
  isPublished: true,
  websitePublished: true,
  websiteUrl: '',
  websiteAbsoluteUrl: '',
  visibility: '',
  template: '',
  timezone: '',
  venueName: '',
  venueAddress: '',
  country: '',
);
