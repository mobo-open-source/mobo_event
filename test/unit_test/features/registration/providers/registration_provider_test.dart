import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/registration/model/attendee_model.dart';
import 'package:mobo_event/features/registration/model/attendee_short_model.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/model/event_reg_full.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../service/mock_registration_services.dart';


void main(){
  late MockRegistrationServices services;
  late RegistrationProvider provider;

  setUp((){
    services = MockRegistrationServices();
    provider = RegistrationProvider(services: services);
  });
  test('Initial values are correct', () {
    expect(provider.editLoading,true);
    expect(provider.isLoading,true);
    expect(provider.newRegistration, null);
    expect(provider.fetchedAttendeesByEvent, null);
    expect(provider.fetchedAttendees, null);
    expect(provider.demoQuestionAnswer, []);
    expect(provider.activeFiltersByEvent, []);
    expect(provider.activeFiltersByTotal, []);
    expect(provider.selectedAttendee, null);
  });
  test('setActiveFiltersTotal updates filters', () {
    provider.setActiveFiltersTotal(['Registered']);

    expect(provider.activeFiltersByTotal, ['Registered']);
  });
  test('setActiveFiltersEvents updates filters', () {
    provider.setActiveFiltersEvents(['Attended']);
    expect(provider.activeFiltersByEvent, ['Attended']);
  });
  test('clearFilter resets both filters', () {
    provider.setActiveFiltersTotal(['Registered']);
    provider.setActiveFiltersEvents(['Attended']);
    provider.clearFilter();
    expect(provider.activeFiltersByTotal, []);
    expect(provider.activeFiltersByEvent, []);
  });

  test("fetch attendee by event", () async {
    final fakeAttendeeList = <AttendeeShortModel>[
      AttendeeShortModel(id: 1, name: 'fake 1', state: '', barcode: ''),
      AttendeeShortModel(id: 2, name: 'fake 2', state: '', barcode: ''),
    ];

    when(() => services.getAttendeesByEvent(
      eventId: 1,
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      search: any(named: 'search'),
      filter: any(named: 'filter'),
    )).thenAnswer((_) async => fakeAttendeeList);

    when(() => services.gettingAttendeesCountByEvent(
      eventId: 1,
      search: any(named: 'search'),
      filter: any(named: 'filter'),
    )).thenAnswer((_) async => 10);
    await provider.loadAttendeesByEvent(eventId: 1);
    expect(provider.isLoadingEvent, false);
    expect(provider.fetchedAttendeesByEvent, fakeAttendeeList);
    expect(provider.totalRecordsEvent, 10);
  });
  test("fetch attendee by event  but show server return error", () async {
    when(() => services.getAttendeesByEvent(
      eventId: 1,
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      search: any(named: 'search'),
      filter: any(named: 'filter'),
    )).thenThrow(Exception('Failed'));
    expect(provider.loadAttendeesByEvent(eventId: 1), throwsException);
  });



  test("loadAttendees success", () async {
    final fakeList = <AttendeeShortModel>[];

    when(() => services.getAttendeesByPagination(
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      search: any(named: 'search'),
      filter: any(named: 'filter'),
    )).thenAnswer((_) async => fakeList);

    when(() => services.gettingAttendeesCount(
      search: any(named: 'search'),
      filter: any(named: 'filter'),
    )).thenAnswer((_) async => 5);

    await provider.loadAttendees();

    expect(provider.fetchedAttendees, fakeList);
    expect(provider.totalRecords, 5);
    expect(provider.isLoading, false);
  });

  test("scanQr without eventId", () async {
    final fakeAttendee =AttendeeModel(id: 1,
        name: '', ticketName: '', eventId: 1,
        eventDisplayName: '',
        registrationAnswers: [], companyName: '', status: '');

    when(() => services.addAttendeesByQr("QR123"))
        .thenAnswer((_) async => fakeAttendee);

    await provider.scanQr("QR123");

    expect(provider.scannedAttendee, fakeAttendee);
  });

  test("scanQr with eventId", () async {
    final fakeAttendee = AttendeeModel(id: 1,
        name: '', ticketName: '', eventId: 1,
        eventDisplayName: '',
        registrationAnswers: [], companyName: '', status: '');

    when(() => services.addAttendeesByQrByEvent("QR123", 1))
        .thenAnswer((_) async => fakeAttendee);

    await provider.scanQr("QR123", eventId: 1);

    expect(provider.scannedAttendee, fakeAttendee);
  });


  test("resetRegistration clears values", () {
    provider.demoQuestionAnswer
        .add(DemoQuestionAnswer(questionId: 1));
    provider.resetRegistration();
    expect(provider.newRegistration, null);
    expect(provider.demoQuestionAnswer, []);
    expect(provider.selectedAttendee, null);
  });

  test("save & delete question", () {
    final question = DemoQuestionAnswer(questionId: 10);

    provider.saveQuestion(question);
    expect(provider.demoQuestionAnswer.length, 1);

    provider.deleteQuestion(0);
    expect(provider.demoQuestionAnswer.isEmpty, true);
  });

  test("buildEventQuestion builds correctly", () {
    provider.saveQuestion(
      DemoQuestionAnswer(
        questionId: 1,
        valueAnswerId: 2,
        valueTextBox: "Text",
      ),
    );

    final result = provider.buildEventQuestion();

    expect(result.first[0], 0);
    expect(result.first[2]['question_id'], 1);
  });

  test("buildEventEditQuestion handles update and delete", () {
    provider.selectedAttendee = RegistrationFullModel(
      id: 1,
         active:true, state:'',
        name:'',
         email:'',
      phone:'',
      isMultiSlots: true,
      displayName: '',
      saleStatus: '',
      barcode: '',
      registrationAnswers: [
        RegistrationAnswer(id: 1, questionType: '',),
      ],
    );

    provider.demoQuestionAnswer = [
      DemoQuestionAnswer(id: 1, questionId: 1),
      DemoQuestionAnswer(questionId: 2),
    ];

    final commands = provider.buildEventEditQuestion();
    expect(commands.length, 2);
  });
  test("getSelectedAttendeeInformation success", () async {
    final fakeFull = RegistrationFullModel(
      id: 1,
      active:true, state:'',
      name:'',
      email:'',
      phone:'',
      isMultiSlots: true,
      displayName: '',
      saleStatus: '',
      barcode: '',
      registrationAnswers: [
        RegistrationAnswer(id: 1, questionType: '',),
      ],
    );

    when(() => services.getSelectedAttendeeDetails(1))
        .thenAnswer((_) async => fakeFull);

    await provider.getSelectedAttendeeInformation(1);

    expect(provider.selectedAttendee, fakeFull);
    expect(provider.editLoading, false);
    verify(()=>services.getSelectedAttendeeDetails(1)).called(1);
  });
  test("throw error when getSelectedAttendeeInformation service fail", () async {
    when(() => services.getSelectedAttendeeDetails(1)).thenThrow(Exception('Failed'));
    expect( provider.getSelectedAttendeeInformation(1), throwsException);
    expect(provider.editLoading, false);
  });

}