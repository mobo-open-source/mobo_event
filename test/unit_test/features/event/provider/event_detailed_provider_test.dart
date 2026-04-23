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

      when(() => service.gettingEventDetails(1))
          .thenAnswer((_) async => fakeEvent);

      when(() => service.getEventTickets(1))
          .thenAnswer((_) async => fakeTicket);

      await provider.fetchEventDetails(1);

      expect(provider.eventModel!.name, 'fake');
      expect(provider.ticketList.length, 2);
      expect(provider.isLoading, false);
      expect(provider.isTicketLoading, false);
    });

    test("fetchEventDetails with id = 0 should not call API", () async {
      await provider.fetchEventDetails(0);

      verifyNever(() => service.gettingEventDetails(any()));
      expect(provider.isLoading, false);
    });

    test("fetchEventDetails throws error", () async {
      when(() => service.gettingEventDetails(1))
          .thenThrow(Exception("error"));

      expect(() => provider.fetchEventDetails(1), throwsException);
    });
  });

  group("Fetch Ticket Only", () {
    test("fetchTicket success", () async {
      final fakeTicket = [EventTicket(name: "VIP")];

      when(() => service.getEventTickets(1))
          .thenAnswer((_) async => fakeTicket);

      await provider.fetchTicket(1);

      expect(provider.ticketList.length, 1);
      expect(provider.isTicketLoading, false);
    });

    test("fetchTicket throws error", () async {
      when(() => service.getEventTickets(1))
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
}