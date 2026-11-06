import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/scheduler/model/event_mail_scheduler.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../service/mock_mail_scheduler_services.dart';


void main(){
  late MockMailSchedularServices services;
  late MailSchedulerProvider provider;

  setUp((){
    services = MockMailSchedularServices();
    provider = MailSchedulerProvider(services: services);
  });


  test("Initial values", (){
    expect(provider.scheduledMails, []);
    expect(provider.loading, true);
  });

  test("fetch communication details from server", ()async{

    final fakeCommunication = [
      EventMailScheduler(id: 1,
          sequence: 1,
          intervalNbr: 2,
          intervalUnit: '',
          intervalType: '',
          mailRegistrationIds: [],
          mailSlotIds: [],
          mailDone: true,
          mailState: '',
          mailCountDone: 2,
          notificationType: ''),
      EventMailScheduler(id: 2,
          sequence: 1,
          intervalNbr: 2,
          intervalUnit: '',
          intervalType: '',
          mailRegistrationIds: [],
          mailSlotIds: [],
          mailDone: true,
          mailState: '',
          mailCountDone: 2,
          notificationType: ''),

    ];
    when(()=>services.fetchCommunication(1)).thenAnswer((_)async=>fakeCommunication);
    await provider.fetchScheduledMail(1);
    expect(provider.loading, false);
    expect(provider.scheduledMails.length, 2);
  });
  test("fetch communication details from serve  and server give error", ()async{
    when(()=>services.fetchCommunication(1)).thenThrow(Exception('Failed'));
    expect(provider.fetchScheduledMail(1), throwsException);
    expect(provider.scheduledMails.length, 0);
    expect(provider.scheduledMails.isEmpty, true);
    expect(provider.loading, false);
  });

  test("deleting ticket successfully", ()async{
    when(()=>services.removeScheduledMail(1)).thenAnswer((_)async=>true);
    final isRemoved = await services.removeScheduledMail(1);
    expect(isRemoved, true);

  });
  test("deleting ticket but server gives false", ()async{
    when(()=>services.removeScheduledMail(1)).thenAnswer((_)async=>false);
    final isRemoved = await services.removeScheduledMail(1);
    expect(isRemoved, false);
  });

  test("deleting ticket but server gives error", ()async{
    when(()=>services.removeScheduledMail(1)).thenThrow(Exception('Failed'));
    expect(provider.deleteTicket(1), throwsException);
  });
  test("reset method", ()async{
    expect(provider.loading, true);
    when(()=>services.removeScheduledMail(1)).thenAnswer((_)async=>true);
    await provider.deleteTicket(1);
    expect(provider.loading, false);
    provider.reset();
    expect(provider.loading, true);
  });

  test("a late answer for an event the screen has left is dropped", () async {
    final slow = Completer<List<EventMailScheduler>>();
    EventMailScheduler mail(int id) => EventMailScheduler(
      id: id,
      sequence: 1,
      intervalNbr: 2,
      intervalUnit: '',
      intervalType: '',
      mailRegistrationIds: [],
      mailSlotIds: [],
      mailDone: true,
      mailState: '',
      mailCountDone: 2,
      notificationType: '',
    );
    when(() => services.fetchCommunication(1)).thenAnswer((_) => slow.future);
    when(() => services.fetchCommunication(2))
        .thenAnswer((_) async => [mail(20)]);

    final first = provider.fetchScheduledMail(1);
    await provider.fetchScheduledMail(2);
    slow.complete([mail(10)]);
    await first;

    expect(provider.scheduledMails.single.id, 20);
    expect(provider.loading, false);
  });
}
