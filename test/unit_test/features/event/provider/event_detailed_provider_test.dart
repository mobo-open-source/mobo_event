import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';

import '../service/mock_event_detailed_service.dart';

void main() {
  late MockEventDetailedService service;
  late EventDetailedProvider provider;
  setUp(() {
    service = MockEventDetailedService();
    provider = EventDetailedProvider(services: service);
  });
  group("Initial State", () {
    test('Initial values are correct', () {
      expect(provider.ticketList, []);
      expect(provider.dummyTicketList, []);
      expect(provider.fetchTemplate, false);
      expect(provider.isLoading, true);
      expect(provider.isTicketLoading, true);
      expect(provider.eventModel, null);
      expect(provider.eventTemplate, null);
      expect(provider.sampleEvent, null);
    });
  });

  group("Dummy Ticket Methods", () {

    test("addDummyTicket adds ticket correctly", () {
      final ticket = EventTicket(name: "VIP");
      provider.addDummyTicket(ticket);

      expect(provider.dummyTicketList.length, 1);
      expect(provider.dummyTicketList.first.name, "VIP");
    });

    test("removeDummyTicket removes ticket correctly", () {
      provider.addDummyTicket(EventTicket(name: "VIP"));
      provider.removeDummyTicket(0);

      expect(provider.dummyTicketList.isEmpty, true);
    });

    test("clearDummyTicket clears list", () {
      provider.dummyTicketList = [EventTicket()];
      provider.clearDummyTicket();

      expect(provider.dummyTicketList, []);
    });
  });
  group("Ticket Command Builder", () {
    test("buildEventTicketCommands generates correct structure", () {
      final ticket = EventTicket(
        productId: 1,
        name: "VIP",
        price: 100,
        seatsMax: 50,
        color:'',
      );
      final result = provider.buildEventTicketCommands([ticket]);
      expect(result.length, 1);
      expect(result[0][0], 0);
      expect(result[0][2]['product_id'], 1);
      expect(result[0][2]['name'], "VIP");
      expect(result[0][2]['price'], 100);
    });
  });

  group("Fetch Event Details", () {
    test("fetchEventDetails success", () async {
      final fakeEvent = EventDetailedModel(
        id: 1,
        name: "fake",
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
        seatTaken: 2,
        kanbanState: '',
        slotCount: 1,
        seatsAvailable: 10,
        isMultiSlots: true,
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

      final fakeTicket = [
        EventTicket(),
        EventTicket(),
      ];

      when(() => service.gettingEventDetails(1, fields: any(named: 'fields')))
          .thenAnswer((_) async => fakeEvent);

      when(() => service.getEventTickets(1, fields: any(named: 'fields')))
          .thenAnswer((_) async => fakeTicket);

      await provider.fetchEventDetails(1);

      expect(provider.eventModel!.name, 'fake');
      expect(provider.ticketList.length, 2);
      expect(provider.isLoading, false);
      expect(provider.isTicketLoading, false);
    });

    test("fetchEventDetails with id = 0 should not call API", () async {
      await provider.fetchEventDetails(0);

      verifyNever(
        () => service.gettingEventDetails(any(), fields: any(named: 'fields')),
      );
      expect(provider.isLoading, false);
    });

    test("fetchEventDetails throws error", () async {
      when(() => service.gettingEventDetails(1, fields: any(named: 'fields')))
          .thenThrow(Exception("error"));

      expect(() => provider.fetchEventDetails(1), throwsException);
    });
  });

  group("Fetch Ticket Only", () {
    test("fetchTicket success", () async {
      final fakeTicket = [EventTicket(name: "VIP")];

      when(() => service.getEventTickets(1, fields: any(named: 'fields')))
          .thenAnswer((_) async => fakeTicket);

      await provider.fetchTicket(1);

      expect(provider.ticketList.length, 1);
      expect(provider.isTicketLoading, false);
    });

    test("fetchTicket throws error", () async {
      when(() => service.getEventTickets(1, fields: any(named: 'fields')))
          .thenThrow(Exception("ticket error"));
      expect(() => provider.fetchTicket(1), throwsException);
    });

    test("delete ticket when server give true", ()async{
      when(()=>service.deleteEventTicket(1)).thenAnswer((_)async=>true);
      final result = await provider.deleteTicket(1);
      expect(result, true);

    });
    test("deleting ticket throws error", ()async{
      when(()=>service.deleteEventTicket(1)).thenThrow(Exception("ticket error"));
      expect(provider.deleteTicket(1), throwsException);
    });
  });

  group("Loading", () {
    Future<EventDetailedModel> anyEvent(int id) async => _event(id);

    void stubEvent(int id, Future<EventDetailedModel> Function() answer) =>
        when(
          () => service.gettingEventDetails(id, fields: any(named: 'fields')),
        ).thenAnswer((_) => answer());

    void stubTickets(int id, Future<List<EventTicket>> Function() answer) =>
        when(
          () => service.getEventTickets(id, fields: any(named: 'fields')),
        ).thenAnswer((_) => answer());

    test("the event and its tickets go out together, not one after the other",
        () async {
      final event = Completer<EventDetailedModel>();
      final tickets = Completer<List<EventTicket>>();
      stubEvent(1, () => event.future);
      stubTickets(1, () => tickets.future);

      final load = provider.fetchEventDetails(1);

      // Neither has answered, yet both requests are already out.
      verify(
        () => service.gettingEventDetails(1, fields: any(named: 'fields')),
      ).called(1);
      verify(
        () => service.getEventTickets(1, fields: any(named: 'fields')),
      ).called(1);

      event.complete(_event(1));
      tickets.complete([EventTicket()]);
      await load;
    });

    test("the summary opens once the event is in, before the tickets", () async {
      final tickets = Completer<List<EventTicket>>();
      stubEvent(1, () => anyEvent(1));
      stubTickets(1, () => tickets.future);

      var finished = false;
      final load = provider.fetchEventDetails(1).then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isLoading, false);
      expect(provider.eventModel!.id, 1);
      expect(provider.isTicketLoading, true);
      // The call itself still completes only once the tickets are in too.
      expect(finished, false);

      tickets.complete([EventTicket(name: "VIP")]);
      await load;

      expect(finished, true);
      expect(provider.isTicketLoading, false);
      expect(provider.ticketList.single.name, "VIP");
    });

    test("a failed event read stops loading, tells listeners and rethrows",
        () async {
      var notified = 0;
      provider.addListener(() => notified++);
      when(
        () => service.gettingEventDetails(1, fields: any(named: 'fields')),
      ).thenThrow(Exception("boom"));
      stubTickets(1, () async => []);

      await expectLater(provider.fetchEventDetails(1), throwsException);

      expect(provider.isLoading, false);
      expect(notified, greaterThan(0));
    });

    test("a ticket failure after the event is in still shows the event",
        () async {
      stubEvent(1, () => anyEvent(1));
      when(
        () => service.getEventTickets(1, fields: any(named: 'fields')),
      ).thenThrow(Exception("tickets"));

      await expectLater(provider.fetchEventDetails(1), throwsException);

      expect(provider.eventModel!.id, 1);
      expect(provider.isLoading, false);
      expect(provider.isTicketLoading, false);
    });

    test("a ticket failure that lands after the event failed is not unhandled",
        () async {
      final event = Completer<EventDetailedModel>();
      final tickets = Completer<List<EventTicket>>();
      stubEvent(1, () => event.future);
      stubTickets(1, () => tickets.future);

      final load = provider.fetchEventDetails(1);
      event.completeError(Exception("event"));
      await expectLater(load, throwsException);

      // Nobody is awaiting the tickets any more; an unhandled error here
      // would fail the test.
      tickets.completeError(Exception("tickets"));
      await Future<void>.delayed(Duration.zero);
    });

    test("a late answer for an event the screen has left is dropped", () async {
      final slowEvent = Completer<EventDetailedModel>();
      final slowTickets = Completer<List<EventTicket>>();
      stubEvent(1, () => slowEvent.future);
      stubTickets(1, () => slowTickets.future);
      stubEvent(2, () => anyEvent(2));
      stubTickets(2, () async => [EventTicket(name: "new")]);

      final first = provider.fetchEventDetails(1);
      await provider.fetchEventDetails(2);

      slowEvent.complete(_event(1));
      slowTickets.complete([EventTicket(name: "old")]);
      await first;

      expect(provider.eventModel!.id, 2);
      expect(provider.ticketList.single.name, "new");
      expect(provider.isLoading, false);
    });

    group("Which columns are read", () {
      test("every column until fields_get has been loaded", () async {
        stubEvent(1, () => anyEvent(1));
        stubTickets(1, () async => []);

        await provider.fetchEventDetails(1);

        final eventFields = verify(
          () => service.gettingEventDetails(
            1,
            fields: captureAny(named: 'fields'),
          ),
        ).captured.single;
        final ticketFields = verify(
          () => service.getEventTickets(1, fields: captureAny(named: 'fields')),
        ).captured.single;
        expect(eventFields, isNull);
        expect(ticketFields, isNull);
      });

      test("only the ones this server has, so a newer field cannot fail the read",
          () async {
        provider.eventFields = {'name': {}, 'seats_taken': {}, 'gone': {}};
        provider.ticketFields = {'name': {}, 'price': {}, 'product_id': {}};
        stubEvent(1, () => anyEvent(1));
        stubTickets(1, () async => []);

        await provider.fetchEventDetails(1);

        final eventFields = verify(
          () => service.gettingEventDetails(
            1,
            fields: captureAny(named: 'fields'),
          ),
        ).captured.single;
        final ticketFields = verify(
          () => service.getEventTickets(1, fields: captureAny(named: 'fields')),
        ).captured.single;
        expect(eventFields, ['name', 'seats_taken']);
        expect(ticketFields, ['name', 'product_id', 'price']);
      });
    });
  });
}

EventDetailedModel _event(int id) => EventDetailedModel(
  id: id,
  name: "event $id",
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
  seatTaken: 2,
  kanbanState: '',
  slotCount: 1,
  seatsAvailable: 10,
  isMultiSlots: true,
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
