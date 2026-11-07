import 'package:flutter/material.dart';

import '../model/event_mail_scheduler.dart';
import '../services/mail_scheduler_services.dart';

class MailSchedulerProvider extends ChangeNotifier {
  final MailSchedulerServices services;

  MailSchedulerProvider({required this.services});

  List<EventMailScheduler> scheduledMails = [];
  bool loading = true;

  /// The event [scheduledMails] was last asked for; an answer that arrives
  /// after the screen has moved on to another event is dropped.
  int? _eventId;

  /// fetch mail scheduler details
  Future fetchScheduledMail(int eventId) async {
    _eventId = eventId;
    try {
      loading = true;
      final result = await services.fetchCommunication(eventId);
      if (_eventId != eventId) return;
      scheduledMails = result;
      loading = false;
      notifyListeners();
    } catch (e) {
      if (_eventId == eventId) {
        loading = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  ///delete ticket
  Future<bool> deleteTicket(int id) async {
    try {
      loading = true;
      final deleted = await services.removeScheduledMail(id);
      loading = false;
      notifyListeners();
      return deleted;
    } catch (e) {
      loading = false;
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    scheduledMails = [];
    loading = true;
    notifyListeners();
  }
}
