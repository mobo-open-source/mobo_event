import 'package:flutter/material.dart';
import 'package:mobo_event/features/registration/model/attendee_group.dart';
import 'package:mobo_event/features/registration/model/attendee_model.dart';
import 'package:mobo_event/features/registration/model/attendee_short_model.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/model/event_reg_full.dart';
import 'package:mobo_event/features/registration/model/event_registration.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';

class RegistrationProvider extends ChangeNotifier {
  final RegistrationServices services;

  RegistrationProvider({required this.services});

  AttendeeModel? scannedAttendee;

  EventRegistration? newRegistration;
  bool isLoading = true;
  List<AttendeeShortModel>? fetchedAttendees;
  List<AttendeeShortModel>? fetchedAttendeesByEvent;

  /// Why the last attendee list load failed, or null. The lists above are null
  /// after a failure; this is what the error view shows for it.
  Object? loadError;
  List<DemoQuestionAnswer> demoQuestionAnswer = [];
  RegistrationFullModel? selectedAttendee;
  bool editLoading = true;

  bool? notScanned;

  List<String> activeFiltersByTotal = [];
  List<String> activeFiltersByEvent = [];
  List<String> completeFiltersTotal = ['Unconfirmed', 'Registered', 'Attended'];

  List<String> eventTypeByEvents = ['Ongoing Events', 'Taken'];

  List<String> completeFiltersByEvents = [
    'Unconfirmed',
    'Registered',
    'Attended',
    'Unconfirmed or Registered',
  ];

  void clearFilter() {
    activeFiltersByEvent = [];
    activeFiltersByTotal = [];

    notifyListeners();
  }

  /// How the all-attendees list and the per-event list are grouped (the filter
  /// sheet's Group By tab), or null for the plain, paged list. They are
  /// separate screens with separate filters, so separate choices.
  AttendeeGroupBy? groupByTotal;
  AttendeeGroupBy? groupByEvent;

  bool get isGroupedTotal => groupByTotal != null;
  bool get isGroupedEvent => groupByEvent != null;

  void setGroupByTotal(AttendeeGroupBy? value) {
    groupByTotal = value;
    notifyListeners();
  }

  void setGroupByEvent(AttendeeGroupBy? value) {
    groupByEvent = value;
    notifyListeners();
  }

  /// Back to no grouping, for a screen that is opening afresh.
  void clearGroupBy() {
    groupByTotal = null;
    groupByEvent = null;
    notifyListeners();
  }

  /// A grouped list holds every attendee, so [fetchedAttendees] is split into
  /// groups instead of being paged.
  List<AttendeeGroup> get groupedAttendeesTotal => groupByTotal == null
      ? const []
      : groupAttendees(fetchedAttendees ?? const [], groupByTotal!);

  List<AttendeeGroup> get groupedAttendeesEvent => groupByEvent == null
      ? const []
      : groupAttendees(fetchedAttendeesByEvent ?? const [], groupByEvent!);

  ///set active filters
  void setActiveFiltersTotal(List<String> filters) {
    activeFiltersByTotal = List.from(filters);
    notifyListeners();
  }

  void setActiveFiltersEvents(List<String> filters) {
    activeFiltersByEvent = List.from(filters);
    notifyListeners();
  }

  ///fetch attendees  by pagination
  int currentPageEvent = 1;
  final int pageSizeEvent = 40;
  int totalRecordsEvent = 0;
  int get startCountEvent => totalRecordsEvent == 0
      ? 0
      : isGroupedEvent
      ? 1
      : ((currentPageEvent - 1) * pageSizeEvent) + 1;
  int get endCountEvent {
    if (isGroupedEvent) return totalRecordsEvent;
    final endEvent = currentPageEvent * pageSizeEvent;
    return endEvent > totalRecordsEvent ? totalRecordsEvent : endEvent;
  }

  String get paginationTextEvent => totalRecordsEvent == 0
      ? '0/0'
      : '$startCountEvent–$endCountEvent / $totalRecordsEvent';
  int get totalPagesEvent =>
      totalRecordsEvent == 0 ? 1 : (totalRecordsEvent / pageSizeEvent).ceil();
  /// A grouped list shows everything at once: there is no next page.
  bool get canGoPreviousEvent => !isGroupedEvent && currentPageEvent > 1;
  bool get canGoNextEvent =>
      !isGroupedEvent && currentPageEvent < totalPagesEvent;
  void nextPageEvent() {
    if (!canGoNextEvent) return;
    currentPageEvent++;
    loadAttendees();
  }

  void previousPageEvent() {
    if (!canGoPreviousEvent) return;
    currentPageEvent--;
    loadAttendees();
  }

  bool isLoadingEvent = true;

  ///fetch attendees  by pagination
  int currentPage = 1;
  final int pageSize = 40;
  int totalRecords = 0;
  int get startCount => totalRecords == 0
      ? 0
      : isGroupedTotal
      ? 1
      : ((currentPage - 1) * pageSize) + 1;
  int get endCount {
    if (isGroupedTotal) return totalRecords;
    final end = currentPage * pageSize;
    return end > totalRecords ? totalRecords : end;
  }

  String get paginationText =>
      totalRecords == 0 ? '0/0' : '$startCount–$endCount / $totalRecords';
  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();
  bool get canGoPrevious => !isGroupedTotal && currentPage > 1;
  bool get canGoNext => !isGroupedTotal && currentPage < totalPages;

  void nextPage() {
    if (!canGoNext) return;
    currentPage++;
    loadAttendees();
  }

  void previousPage() {
    if (!canGoPrevious) return;
    currentPage--;
    loadAttendees();
  }

  /// Bumped by every load; a fetch that is no longer the latest (the user
  /// typed or filtered again) drops its result and leaves the loading state
  /// to the newer one.
  int _eventRequest = 0;
  int _totalRequest = 0;

  ///load attendees by event
  Future loadAttendeesByEvent({
    bool reset = false,
    String search = '',
    required int eventId,
  }) async {
    final request = ++_eventRequest;
    try {
      isLoadingEvent = true;
      loadError = null;
      if (reset) currentPageEvent = 1;
      notifyListeners();

      if (isGroupedEvent) {
        // Grouped: everything, so the groups and their counts are exact.
        currentPageEvent = 1;
        final all = await services.getAllAttendees(
          eventId: eventId,
          search: search,
          filter: activeFiltersByEvent,
        );
        if (request != _eventRequest) return;
        fetchedAttendeesByEvent = all;
        totalRecordsEvent = all.length;
        isLoadingEvent = false;
        notifyListeners();
        return;
      }

      final offsetEvent = (currentPageEvent - 1) * pageSizeEvent;

      final response = await services.getAttendeesByEvent(
        eventId: eventId,
        limit: pageSizeEvent,
        offset: offsetEvent,
        search: search,
        filter: activeFiltersByEvent,
      );
      if (request != _eventRequest) return;
      final count = await services.gettingAttendeesCountByEvent(
        eventId: eventId,
        search: search,
        filter: activeFiltersByEvent,
      );
      if (request != _eventRequest) return;
      fetchedAttendeesByEvent = response;
      totalRecordsEvent = count;

      isLoadingEvent = false;
      notifyListeners();
    } catch (e) {
      if (request != _eventRequest) return;
      isLoadingEvent = false;
      fetchedAttendeesByEvent = null;
      loadError = e;
      notifyListeners();
      rethrow;
    }
  }

  ///load attendees
  Future loadAttendees({bool reset = false, String search = ''}) async {
    final request = ++_totalRequest;
    try {
      isLoading = true;
      loadError = null;
      if (reset) currentPage = 1;
      notifyListeners();

      if (isGroupedTotal) {
        // Grouped: everything, so the groups and their counts are exact.
        currentPage = 1;
        final all = await services.getAllAttendees(
          search: search,
          filter: activeFiltersByTotal,
        );
        if (request != _totalRequest) return;
        fetchedAttendees = all;
        totalRecords = all.length;
        isLoading = false;
        notifyListeners();
        return;
      }

      final offset = (currentPage - 1) * pageSize;

      final response = await services.getAttendeesByPagination(
        limit: pageSize,
        offset: offset,
        search: search,
        filter: activeFiltersByTotal,
      );
      if (request != _totalRequest) return;
      final count = await services.gettingAttendeesCount(
        search: search,
        filter: activeFiltersByTotal,
      );
      if (request != _totalRequest) return;
      fetchedAttendees = response;
      totalRecords = count;

      isLoading = false;
      notifyListeners();
    } catch (e) {
      if (request != _totalRequest) return;
      isLoading = false;
      fetchedAttendees = null;
      loadError = e;
      notifyListeners();
      rethrow;
    }
  }

  ///scan qr
  Future scanQr(String qrData, {int? eventId}) async {
    try {
      scannedAttendee = null;
      notifyListeners();

      if (eventId != null && eventId != 0) {
        final response = await services.addAttendeesByQrByEvent(
          qrData,
          eventId,
        );
        scannedAttendee = response;
      } else {
        final response = await services.addAttendeesByQr(qrData);
        scannedAttendee = response;
      }
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  void resetRegistration() {
    newRegistration = null;
    demoQuestionAnswer = [];
    selectedAttendee = null;

    editLoading = true;
    notifyListeners();
  }

  saveQuestion(DemoQuestionAnswer demo) {
    demoQuestionAnswer.add(demo);
    notifyListeners();
  }

  deleteQuestion(int index) {
    demoQuestionAnswer.removeAt(index);
    notifyListeners();
  }

  Future onchange(int? eventId) async {
    try {
      final result = await services.onChangeNew(eventId);
      newRegistration = result;
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  ///save registration
  Future getSelectedAttendeeInformation(int id) async {
    try {
      editLoading = true;
      selectedAttendee = null;
      final result = await services.getSelectedAttendeeDetails(id);
      selectedAttendee = result;
      editLoading = false;
      notifyListeners();
    } catch (_) {
      editLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List buildEventQuestion() {
    return List.generate(demoQuestionAnswer.length, (index) {
      final question = demoQuestionAnswer[index];
      return [
        0,
        'virtual_$index',
        {
          'question_id': question.questionId,
          'value_answer_id': question.valueAnswerId,
          'value_text_box': question.valueTextBox,
        },
      ];
    });
  }

  List buildEventEditQuestion() {
    List commands = [];

    final currentAnswerIds = demoQuestionAnswer
        .where((a) => a.id != null)
        .map((a) => a.id)
        .toSet();

    for (var answer in demoQuestionAnswer) {
      final values = {
        'question_id': answer.questionId,
        'value_answer_id': answer.valueAnswerId,
        'value_text_box': answer.valueTextBox,
      };

      if (answer.id != null) {
        commands.add([1, answer.id, values]);
      } else {
        commands.add([0, 0, values]);
      }
    }

    for (var oldAnswer in selectedAttendee!.registrationAnswers) {
      if (oldAnswer.id != null && !currentAnswerIds.contains(oldAnswer.id)) {
        commands.add([2, oldAnswer.id, 0]);
      }
    }

    return commands;
  }
}
