
import 'package:flutter/cupertino.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/odoo_session_manager.dart';
import 'package:mobo_event/features/home/model/event_short.dart';

import '../services/home_services.dart';

class HomeProvider extends ChangeNotifier {
  final HomeServices services;
  HomeProvider({required this.services});


  List<EventStage> stageList = [];
  List<EventShort> eventList = [];

  String version ='';


  ///getting version
  fetchVersion()async{
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final oodoVersion = session!.version;
      version = oodoVersion!;
       notifyListeners();
    }catch(e){
       }
  }

  bool isStageLoading = false;
  bool isEventLoading = false;
  bool loading = false;
  List<String> activeFilters = [];


  /// default values in filters
  List<String> eventType = ['Published', 'Archived', 'Upcoming/Running'];
  List<String> fullFilters = ['My events', 'Online'];

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void clearProvider() {
    stageList = [];
    eventList = [];
    isStageLoading = true;
    isEventLoading = true;
    notifyListeners();
  }

  void setActiveFilters(List<String> filters) {
    activeFilters = List.from(filters);
    notifyListeners();
  }


  ///getting events
  Future loadEvents({String search = ''}) async {
    try {
      isEventLoading = true;
      notifyListeners();

      /// Fetch events from server
      final events = await services.gettingEventsShort(
        search: search,
        filter: activeFilters,
      );
      eventList = events;
    } catch (e) {
      rethrow;
    } finally {
      isEventLoading = false;
      notifyListeners();
    }
  }

  ///getting stages
  Future<bool> gettingStages() async {
    try {
      isStageLoading = true;
      isEventLoading = true;
      notifyListeners();

      /// Fetch stages from server
      final stages = await services.gettingStage();
      stageList = stages;
      /// Fetch events from server
     await loadEvents();

     /// getting version
      return stageList.isNotEmpty;
    } catch (e) {
      return false;
    } finally {
      isStageLoading = false;
      isEventLoading = false;
      notifyListeners();
    }
  }
}
