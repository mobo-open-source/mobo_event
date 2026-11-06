import 'dart:async';

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

  group("the add-question picker's load", () {
    EventQuestion question(int id) => EventQuestion(
      id: id,
      displayName: '',
      title: '',
      questionType: '',
      answerIds: [],
      answers: [],
      oncePerOrder: true,
      isMandatoryAnswer: true,
      isDefault: true,
      isReusable: true,
    );

    test("a failure is kept for the picker to show, not just thrown", () async {
      when(() => services.fetchRemainQuestionList([1]))
          .thenThrow(Exception('Failed'));

      await expectLater(
        provider.fetchRemainingQuestions([1]),
        throwsException,
      );

      expect(provider.remainLoading, false);
      expect(provider.remainError, 'Failed');
    });

    test("a retry clears the error and loads the questions", () async {
      when(() => services.fetchRemainQuestionList([1]))
          .thenThrow(Exception('Failed'));
      await expectLater(
        provider.fetchRemainingQuestions([1]),
        throwsException,
      );
      expect(provider.remainError, isNotNull);

      when(() => services.fetchRemainQuestionList([1]))
          .thenAnswer((_) async => [question(7)]);
      var notified = 0;
      provider.addListener(() => notified++);
      final retry = provider.fetchRemainingQuestions([1]);

      // Straight back to the skeleton, error gone.
      expect(provider.remainLoading, true);
      expect(provider.remainError, isNull);
      expect(notified, 1);

      await retry;
      expect(provider.remainLoading, false);
      expect(provider.remainError, isNull);
      expect(provider.remainingQuestionList.single.id, 7);
    });

    test("a list is fresh only for the question set it was fetched against", () async {
      when(() => services.fetchRemainQuestionList([3, 1]))
          .thenAnswer((_) async => [question(7)]);
      // Nothing fetched yet.
      expect(provider.hasFreshRemaining([1, 3]), false);

      await provider.fetchRemainingQuestions([3, 1]);
      // The order of the ids doesn't matter.
      expect(provider.hasFreshRemaining([1, 3]), true);
      // The event gained a question since, so the list is out of date.
      expect(provider.hasFreshRemaining([1, 3, 5]), false);

      provider.reset();
      expect(provider.hasFreshRemaining([1, 3]), false);
    });

    test("a failed fetch is never fresh", () async {
      when(() => services.fetchRemainQuestionList([1]))
          .thenThrow(Exception('Failed'));
      await expectLater(
        provider.fetchRemainingQuestions([1]),
        throwsException,
      );

      expect(provider.hasFreshRemaining([1]), false);
    });

    test("reset marks the list stale without notifying", () async {
      when(() => services.fetchRemainQuestionList([1]))
          .thenAnswer((_) async => [question(7)]);
      await provider.fetchRemainingQuestions([1]);
      expect(provider.remainLoading, false);

      var notified = 0;
      provider.addListener(() => notified++);
      provider.reset();

      // The picker is closing (or reloading behind itself): it must not be
      // flipped back to a skeleton by this.
      expect(provider.remainLoading, true);
      expect(provider.remainError, isNull);
      expect(notified, 0);
    });
  });

  test("clear empties the list and puts it back in its loading state", () async {
    when(() => services.fetchQuestionsWithAnswers(1)).thenAnswer(
      (_) async => [
        EventQuestion(
          id: 1,
          displayName: '',
          title: '',
          questionType: '',
          answerIds: [],
          answers: [],
          oncePerOrder: true,
          isMandatoryAnswer: true,
          isDefault: true,
          isReusable: true,
        ),
      ],
    );
    await provider.fetchQuestions(1);
    expect(provider.isLoading, false);

    var notified = 0;
    provider.addListener(() => notified++);
    provider.clear();

    expect(provider.questionList, []);
    expect(provider.isLoading, true);
    expect(notified, 1);
  });

  test("a late answer for an event the screen has left is dropped", () async {
    final slow = Completer<List<EventQuestion>>();
    EventQuestion question(int id) => EventQuestion(
      id: id,
      displayName: '',
      title: '',
      questionType: '',
      answerIds: [],
      answers: [],
      oncePerOrder: true,
      isMandatoryAnswer: true,
      isDefault: true,
      isReusable: true,
    );
    when(() => services.fetchQuestionsWithAnswers(1))
        .thenAnswer((_) => slow.future);
    when(() => services.fetchQuestionsWithAnswers(2))
        .thenAnswer((_) async => [question(20)]);

    final first = provider.fetchQuestions(1);
    await provider.fetchQuestions(2);
    slow.complete([question(10)]);
    await first;

    expect(provider.questionList.single.id, 20);
    expect(provider.isLoading, false);
  });
}
