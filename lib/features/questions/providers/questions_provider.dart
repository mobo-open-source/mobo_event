
import 'package:flutter/material.dart';

import '../model/event_question.dart';
import '../services/question_service.dart';

class QuestionsProvider extends ChangeNotifier {
  final QuestionService services;
  QuestionsProvider({required this.services});

  List<EventQuestion> questionList = [];
  bool isLoading = true;
  bool remainLoading = true;

  List<EventQuestion> remainingQuestionList = [];

  Future fetchQuestions(int eventId) async {
    try {
      isLoading = true;
      final result = await services.fetchQuestionsWithAnswers(eventId);

      questionList = result;

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
       rethrow;
    }
  }

  Future fetchRemainingQuestions(List<int> ids) async {
    try {
      remainLoading = true;
      final result = await services.fetchRemainQuestionList(ids);

      remainingQuestionList = result;
      remainLoading = false;

      notifyListeners();
    } catch (e) {
      remainLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    remainLoading = true;
    notifyListeners();
  }
}
