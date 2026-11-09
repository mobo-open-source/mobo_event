import 'package:flutter/material.dart';
import 'package:mobo_event/features/event/model/event_sample_response.dart';
import 'package:mobo_event/features/event/model/event_type_model.dart';

import '../model/event_detailed_model.dart';
import '../../ticket/model/event_ticket_model.dart';
import '../services/event_detailed_services.dart';

class EventDetailedProvider extends ChangeNotifier {
  final EventDetailedServices services;
  EventDetailedProvider({required this.services});

  EventDetailedModel? eventModel;
  EventTypeModel? eventTemplate;
  EventResponse? sampleEvent;
  List<EventTicket> ticketList = [];
  List<EventTicket> dummyTicketList = [];

  bool fetchTemplate = false;
  bool isLoading = true;
  bool isTicketLoading = true;

  /// Odoo stores Datetime fields in UTC; the ticket model parses them back
  /// as UTC too, so the write side must convert before formatting.
  String _formatOdooDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return "${utc.year.toString().padLeft(4, '0')}-"
        "${utc.month.toString().padLeft(2, '0')}-"
        "${utc.day.toString().padLeft(2, '0')} "
        "${utc.hour.toString().padLeft(2, '0')}:"
        "${utc.minute.toString().padLeft(2, '0')}:"
        "${utc.second.toString().padLeft(2, '0')}";
  }

  /// Build event ticket commands
  List buildEventTicketCommands(List<EventTicket> tickets) {
    // product_id / price come from event_sale and limit_max_per_order is
    // Odoo 19 only — an unknown key in a create command fails the whole
    // event create, so only send what this server's ticket model has.
    bool has(String field) =>
        ticketFields.isEmpty || ticketFields.containsKey(field);

    return List.generate(tickets.length, (index) {
      final ticket = tickets[index];
      return [
        0,
        0,
        {
          'sequence': index,
          'name': ticket.name,
          if (has('product_id') && ticket.productId != null)
            'product_id': ticket.productId,
          if (has('price') && ticket.price != null) 'price': ticket.price,
          'seats_max': ticket.seatsMax ?? 0,
          if (has('limit_max_per_order') && (ticket.limitMaxPerOrder ?? 0) > 0)
            'limit_max_per_order': ticket.limitMaxPerOrder,
          if (ticket.startSaleDatetime != null)
            "start_sale_datetime": _formatOdooDateTime(
              ticket.startSaleDatetime!,
            ),
          if (ticket.endSaleDatetime != null)
            "end_sale_datetime": _formatOdooDateTime(ticket.endSaleDatetime!),
          if (ticket.color != null) 'color': ticket.color,
        },
      ];
    });
  }

  /// Clear dummy ticket list
  void clearDummyTicket() {
    dummyTicketList = [];
    notifyListeners();
  }

  /// Remove the dummy ticket at [index]
  void removeDummyTicket(int index) {
    dummyTicketList.removeAt(index);
    notifyListeners();
  }

  /// Add dummy ticket to list
  void addDummyTicket(EventTicket ticket) {
    dummyTicketList.add(ticket);
    notifyListeners();
  }

  void reset() {
    isLoading = true;
    isTicketLoading = true;
    notifyListeners();
  }

  /// The event whose details and tickets were asked for last. This provider is
  /// shared by every Details screen, so an answer that arrives after the user
  /// has moved on to another event must not overwrite that event's data.
  int? _detailsFor;
  int? _ticketsFor;

  /// [wanted] cut down to the columns this server has, so a field from a newer
  /// Odoo release never fails the read on an older one. Null — read every
  /// column — until `fields_get` has been loaded.
  List<String>? _readable(List<String> wanted, Map<String, dynamic> known) =>
      known.isEmpty ? null : wanted.where(known.containsKey).toList();

  /// Fetch event details. [isLoading] drops as soon as the event itself is in,
  /// so the summary shows without waiting on the tickets, which are read
  /// alongside it and have their own [isTicketLoading]. The returned future
  /// still completes only once both are in.
  Future fetchEventDetails(int id) async {
    isLoading = true;
    if (id == 0) {
      isLoading = false;
      notifyListeners();
      return;
    }

    _detailsFor = id;
    final tickets = fetchTicket(id);
    // Awaited below, once the event is in; until then a failure here must not
    // surface as an unhandled error if the event read fails first.
    tickets.ignore();

    try {
      final res = await services.gettingEventDetails(
        id,
        fields: _readable(EventDetailedModel.readFields, eventFields),
      );
      if (_detailsFor != id) return;
      eventModel = res;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_detailsFor == id) {
        isLoading = false;
        notifyListeners();
      }
      rethrow;
    }
    await tickets;
  }

  /// Re-reads the open event after one of its tabs has saved part of it.
  /// Unlike [fetchEventDetails] it leaves [isLoading] alone, so the screen
  /// keeps its place — the tab that saved stays open — instead of dropping to
  /// the loading skeleton and coming back on the first tab.
  Future<void> refreshEventDetails(int id) async {
    final res = await services.gettingEventDetails(
      id,
      fields: _readable(EventDetailedModel.readFields, eventFields),
    );
    if (_detailsFor != id) return;
    eventModel = res;
    notifyListeners();
  }

  /// Fetch event tickets
  Future fetchTicket(int id) async {
    _ticketsFor = id;
    try {
      isTicketLoading = true;
      final response = await services.getEventTickets(
        id,
        fields: _readable(EventTicket.readFields, ticketFields),
      );
      if (_ticketsFor != id) return;
      ticketList = response;
      isTicketLoading = false;
      notifyListeners();
    } catch (e) {
      if (_ticketsFor == id) {
        isTicketLoading = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<bool> deleteTicket(int id) async {
    try {
      final deleted = await services.deleteEventTicket(id);

      if (deleted) {
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  ///fetching single template details
  Future getSingleTemplateDetails(int templateId) async {
    try {
      fetchTemplate = true;
      final result = await services.eventTemplate(templateId);
      eventTemplate = result;
      fetchTemplate = false;
      notifyListeners();
    } catch (e) {
      fetchTemplate = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Build safe payload
  Future<Map<String, dynamic>> buildSafePayload(
    Map<String, dynamic> payload,
  ) async {
    final modelFields = await services.getModelFields('event.event');
    payload.removeWhere((key, value) => !modelFields.containsKey(key));

    return payload;
  }

  Future createNewSample() async {
    try {
      final result = await services.onChangeEvent();
      sampleEvent = result;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> eventFields = {};
  Future<void> loadFields() async {
    eventFields = await services.getModelFields('event.event');
    notifyListeners();
  }

  Map<String, dynamic> ticketFields = {};
  Future<void> loadFieldOfTicket() async {
    ticketFields = await services.getModelFields('event.event.ticket');
    try {
      currencySymbol = await services.getCompanyCurrencySymbol() ?? currencySymbol;
    } catch (_) {
      // Keep the previous symbol; prices still show.
    }
    notifyListeners();
  }

  /// Symbol of the company currency, shown next to ticket prices.
  String currencySymbol = '\$';
}
