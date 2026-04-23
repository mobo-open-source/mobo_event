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

  String _formatOdooDateTime(DateTime dt) {
    final local = dt.toLocal();
    return "${local.year.toString().padLeft(4, '0')}-"
        "${local.month.toString().padLeft(2, '0')}-"
        "${local.day.toString().padLeft(2, '0')} "
        "${local.hour.toString().padLeft(2, '0')}:"
        "${local.minute.toString().padLeft(2, '0')}:"
        "${local.second.toString().padLeft(2, '0')}";
  }

  /// Build event ticket commands
  List buildEventTicketCommands(List<EventTicket> tickets) {
    /// Build ticket commands for Odoo RPC
    return List.generate(tickets.length, (index) {
      final ticket = tickets[index];
      return [
        0,
        'virtual_$index',
        {
          'sequence': index,
          'product_id': ticket.productId,
          'name': ticket.name,
          'price': ticket.price,
          'seats_max': ticket.seatsMax,
          if (ticket.limitMaxPerOrder != 0)
            'limit_max_per_order': ticket.limitMaxPerOrder,
          if (ticket.startSaleDatetime != null)
            "start_sale_datetime": _formatOdooDateTime(
              ticket.startSaleDatetime!,
            ),
          if (ticket.endSaleDatetime != null)
            "end_sale_datetime": _formatOdooDateTime(ticket.endSaleDatetime!),
          'color': ticket.color,
        },
      ];
    });
  }

  /// Clear dummy ticket list
  void clearDummyTicket() {
    dummyTicketList = [];
    notifyListeners();
  }
  /// Add dummy ticket to list

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

  /// Fetch event details
  Future fetchEventDetails(int id) async {
    isLoading = true;
    if (id == 0) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {

      /// Fetch event details from server
      final res = await services.gettingEventDetails(id);
      eventModel = res;
      await fetchTicket(id);
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      rethrow;
    }
  }

  /// Fetch event tickets

  Future fetchTicket(int id) async {
    try {
      isTicketLoading = true;
      final response = await services.getEventTickets(id);
      if (response.isNotEmpty) {
        ticketList = response;
        isTicketLoading = false;
        notifyListeners();
        return;
      }
      ticketList = [];
      isTicketLoading = false;
      notifyListeners();
    } catch (e) {
      isTicketLoading = false;
      notifyListeners();
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
    /// Get model fields
    final modelFields = await services.getModelFields('event.event');
    /// Remove fields that are not in the model
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


  /// Fetch sample event
  Map<String, dynamic> eventFields = {};
  Future<void> loadFields() async {
    eventFields = await services.getModelFields('event.event');
    notifyListeners();
  }

  Map<String, dynamic> ticketFields = {};
  Future<void> loadFieldOfTicket() async {
    ticketFields = await services.getModelFields('event.event.ticket');
    notifyListeners();
  }
}
