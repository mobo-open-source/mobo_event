import 'package:flutter/material.dart';
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
  int get startCountEvent =>
      totalRecordsEvent == 0 ? 0 : ((currentPageEvent - 1) * pageSizeEvent) + 1;
  int get endCountEvent {
    final endEvent = currentPageEvent * pageSizeEvent;
    return endEvent > totalRecordsEvent ? totalRecordsEvent : endEvent;
  }

  String get paginationTextEvent => totalRecordsEvent == 0
      ? '0/0'
      : '$startCountEvent–$endCountEvent / $totalRecordsEvent';
  int get totalPagesEvent =>
      totalRecordsEvent == 0 ? 1 : (totalRecordsEvent / pageSizeEvent).ceil();
  bool get canGoPreviousEvent => currentPageEvent > 1;
  bool get canGoNextEvent => currentPageEvent < totalPagesEvent;
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
  int get startCount =>
      totalRecords == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
  int get endCount {
    final end = currentPage * pageSize;
    return end > totalRecords ? totalRecords : end;
  }

  String get paginationText =>
      totalRecords == 0 ? '0/0' : '$startCount–$endCount / $totalRecords';
  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();
  bool get canGoPrevious => currentPage > 1;
  bool get canGoNext => currentPage < totalPages;

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

  Future loadAttendeesByEvent({
    bool reset = false,
    String search = '',
    required int eventId,
  }) async {
    try {
      isLoadingEvent = true;
      if (reset) currentPageEvent = 1;
      notifyListeners();
      final offsetEvent = (currentPageEvent - 1) * pageSizeEvent;

      final response = await services.getAttendeesByEvent(
        eventId: eventId,
        limit: pageSizeEvent,
        offset: offsetEvent,
        search: search,
        filter: activeFiltersByEvent,
      );
      fetchedAttendeesByEvent = response;
      totalRecordsEvent = await services.gettingAttendeesCountByEvent(
        eventId: eventId,
        search: search,
        filter: activeFiltersByEvent,
      );

      isLoadingEvent = false;
      notifyListeners();
    } catch (e) {
      isLoadingEvent = false;
      fetchedAttendeesByEvent = null;
      notifyListeners();
      rethrow;
    }
  }

  ///load attendees
  Future loadAttendees({bool reset = false, String search = ''}) async {
    try {
      isLoading = true;
      if (reset) currentPage = 1;
      notifyListeners();
      final offset = (currentPage - 1) * pageSize;

      final response = await services.getAttendeesByPagination(
        limit: pageSize,
        offset: offset,
        search: search,
        filter: activeFiltersByTotal,
      );
      fetchedAttendees = response;
      totalRecords = await services.gettingAttendeesCount(
        search: search,
        filter: activeFiltersByTotal,
      );

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      fetchedAttendees = null;
      notifyListeners();
      rethrow;
    }
  }

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
    } catch (e) {
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
    } catch (e) {
      rethrow;
    }
  }

  Future getSelectedAttendeeInformation(int id) async {
    try {
      editLoading = true;
      selectedAttendee = null;
      final result = await services.getSelectedAttendeeDetails(id);
      selectedAttendee = result;
      editLoading = false;
      notifyListeners();
    } catch (e) {
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
