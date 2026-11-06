
import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../shared/helper/helper_method.dart';
import '../model/event_question.dart';
import '../services/question_service.dart';

class QuestionsProvider extends ChangeNotifier {
  final QuestionService services;
  QuestionsProvider({required this.services});

  List<EventQuestion> questionList = [];
  bool isLoading = true;
  bool remainLoading = true;

  /// Why the last [fetchRemainingQuestions] failed, for the add-question picker
  /// to show; null while it hasn't.
  String? remainError;

  /// How long the picker waits for the reusable questions before giving up,
  /// so a request that never answers ends in an error with a Retry instead of
  /// a skeleton that never goes away.
  static const Duration remainTimeout = Duration(seconds: 20);

  List<EventQuestion> remainingQuestionList = [];

  /// The ids of the event's own questions that [remainingQuestionList] was
  /// fetched against (sorted), or null when it holds nothing usable. The list
  /// is "the reusable questions not among these".
  List<int>? _remainFor;

  /// Whether [remainingQuestionList] is already the answer for an event whose
  /// questions are [ids]: loaded, not failed, and fetched against the same set.
  /// The picker opens on a list like that at once, instead of on a skeleton.
  bool hasFreshRemaining(List<int> ids) {
    final fetchedFor = _remainFor;
    if (remainLoading || remainError != null || fetchedFor == null) {
      return false;
    }
    return listEquals(fetchedFor, ([...ids]..sort()));
  }

  /// The event [questionList] was last asked for; an answer that arrives after
  /// the screen has moved on to another event is dropped.
  int? _eventId;

  /// Fetch questions
  Future fetchQuestions(int eventId) async {
    _eventId = eventId;
    try {
      isLoading = true;
      final result = await services.fetchQuestionsWithAnswers(eventId);
      if (_eventId != eventId) return;

      questionList = result;

      isLoading = false;
      notifyListeners();
    } catch (_) {
      if (_eventId == eventId) {
        isLoading = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Empties the questions and puts the list back in its loading state, so the
  /// next event's Questions tab never starts out showing this one's. (Not
  /// [reset], which only concerns the add-question picker.)
  void clear() {
    questionList = [];
    isLoading = true;
    notifyListeners();
  }

  /// Fetch remaining questions
  ///
  /// A failure is kept in [remainError] for the picker to show, and also
  /// rethrown, so a caller that awaits this still sees it.
  Future fetchRemainingQuestions(List<int> ids) async {
    // A retry goes back to the skeleton; the first load is already showing it.
    final changed = !remainLoading || remainError != null;
    remainLoading = true;
    remainError = null;
    if (changed) notifyListeners();

    try {
      final result = await services
          .fetchRemainQuestionList(ids)
          .timeout(remainTimeout);

      remainingQuestionList = result;
      _remainFor = ([...ids]..sort());
      remainLoading = false;

      notifyListeners();
    } catch (e) {
      _remainFor = null;
      remainLoading = false;
      remainError = e is TimeoutException
          ? 'The server took too long to respond.'
          : cleanedError(e.toString());
      notifyListeners();
      rethrow;
    }
  }

  /// Marks the picker's list stale, so its next opening starts from the loading
  /// state.
  ///
  /// Silent on purpose: the picker calls this as it closes, and after Save while
  /// the questions reload behind it. Notifying there flipped the dialog back to
  /// a skeleton on its way out, which showed as a flash of "loading".
  void reset() {
    remainLoading = true;
    remainError = null;
    _remainFor = null;
  }
}
