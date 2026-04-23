import 'package:flutter/material.dart';

import '../model/event_mail_scheduler.dart';
import '../services/mail_scheduler_services.dart';

class MailSchedulerProvider extends ChangeNotifier {
  final MailSchedulerServices services;

  MailSchedulerProvider({required this.services});

  List<EventMailScheduler> scheduledMails = [];
  bool loading = true;


  /// fetch mail scheduler details
  Future fetchScheduledMail(int eventId) async {
    try {
      loading = true;
      final result = await services.fetchCommunication(eventId);
      scheduledMails = result;
      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      notifyListeners();
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
