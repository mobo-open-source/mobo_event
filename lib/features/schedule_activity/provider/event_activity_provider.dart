
import 'package:flutter/material.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';

class EventActivityProvider extends ChangeNotifier {
  final EventActivityServices services;
  EventActivityProvider({required this.services});

  bool isLoading = true;
  List<ActivitiesModel> activityList = [];

  ///fetch the activities
  Future<void> fetchActivities(List<dynamic> activitiesId) async {
    try {
       isLoading = true;
      if (activitiesId.isEmpty) {
        activityList = [];
        isLoading = false;
        notifyListeners();
        return;
      }
      final res = await services.fetchActivities(activitiesId);

      if (res.isNotEmpty) {
        activityList = res;
        isLoading = false;
        notifyListeners();
        return;
      }
      activityList = [];
      isLoading = false;
      notifyListeners();
    } catch (_) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
