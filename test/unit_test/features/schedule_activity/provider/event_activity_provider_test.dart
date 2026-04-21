import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';
import 'package:mobo_event/features/schedule_activity/provider/event_activity_provider.dart';
import 'package:mocktail/mocktail.dart';
import '../services/mock_event_activity_services.dart';


void main(){
  late MockEventActivityServices service;
  late EventActivityProvider provider;
  setUp((){
    service = MockEventActivityServices();
    provider= EventActivityProvider(services: service);
  });

  test("checking initial values ", (){
    expect(provider.isLoading, true);
    expect(provider.activityList, []);
  });
  test("fetch activities from the server when activity id is empty", ()async{

    final fakeActivityList = <ActivitiesModel>[];
    when(()=>service.fetchActivities([])).thenAnswer((_)async=>fakeActivityList);
    await provider.fetchActivities([]);
    expect(provider.isLoading, false);
    expect(provider.activityList, []);
  });
  test("fetch activities from the server give result", ()async{

    final fakeActivityList =[
      ActivitiesModel(id: 1, activityType: [], userId: [], state: ''),
      ActivitiesModel(id: 2, activityType: [], userId: [], state: ''),
    ];
    when(()=>service.fetchActivities([1])).thenAnswer((_)async=>fakeActivityList);
    await provider.fetchActivities([1]);
    expect(provider.isLoading, false);
    expect(provider.activityList.length,2);
  });

  test("fetch activities from the server give exception", ()async{

    when(()=>service.fetchActivities([1])).thenThrow(Exception('Failed'));
    expect( provider.fetchActivities([1]), throwsException);
    expect(provider.isLoading,false);
    expect(provider.activityList,[]);
  });
}