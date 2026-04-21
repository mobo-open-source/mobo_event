import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/questions/model/event_question.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../service/mock_question_services.dart';


void main(){
  late MockQuestionServices services;
  late QuestionsProvider provider;
  setUp((){
    services = MockQuestionServices();
    provider = QuestionsProvider(services: services);
  });
  test("Initial values are correct", (){
    expect(provider.questionList, []);
    expect(provider.remainingQuestionList, []);
    expect(provider.isLoading, true);
    expect(provider.remainLoading, true);
  });


  test("fetch questions from server", ()async{

    final fakeQuestions =[
      EventQuestion(id: 1,
          displayName: '',
          title: '',
          questionType: '',
          answerIds: [],
          answers: [],
          oncePerOrder:true,
          isMandatoryAnswer: true,
          isDefault: true,
          isReusable: true),
      EventQuestion(id: 2,
          displayName: '',
          title: '',
          questionType: '',
          answerIds: [],
          answers: [],
          oncePerOrder:true,
          isMandatoryAnswer: true,
          isDefault: true,
          isReusable: true),


    ];
    when(()=>services.fetchQuestionsWithAnswers(1)).thenAnswer((_)async=>fakeQuestions);
    await provider.fetchQuestions(1);
    expect(provider.questionList.isNotEmpty, true);
    expect(provider.isLoading, false);
    expect(provider.questionList.length, 2);

  });
  test("fetch questions from server but server respond error", ()async{
    when(()=>services.fetchQuestionsWithAnswers(1)).thenThrow(Exception('Failed'));
    expect(provider.isLoading, true);
    expect(provider.fetchQuestions(1), throwsException);
    expect(provider.isLoading, false);
    expect(provider.questionList, []);
  });
  test("fetch remaining questions from server", ()async{
    final fakeQuestions =[
      EventQuestion(id: 1,
          displayName: '',
          title: '',
          questionType: '',
          answerIds: [],
          answers: [],
          oncePerOrder:true,
          isMandatoryAnswer: true,
          isDefault: true,
          isReusable: true),
      EventQuestion(id: 2,
          displayName: '',
          title: '',
          questionType: '',
          answerIds: [],
          answers: [],
          oncePerOrder:true,
          isMandatoryAnswer: true,
          isDefault: true,
          isReusable: true),


    ];
    when(()=>services.fetchRemainQuestionList([1])).thenAnswer((_)async=>fakeQuestions);
    await provider.fetchRemainingQuestions([1]);
    expect(provider.remainingQuestionList.isNotEmpty, true);
    expect(provider.remainLoading, false);
    expect(provider.remainingQuestionList.length, 2);

  });
  test("fetch Remaining questions from server but server respond error", ()async{
    when(()=>services.fetchRemainQuestionList([1])).thenThrow(Exception('Failed'));
    expect(provider.remainLoading, true);
    expect(provider.fetchRemainingQuestions([1]), throwsException);
    expect(provider.remainLoading, false);
    expect(provider.remainingQuestionList, []);
  });
}