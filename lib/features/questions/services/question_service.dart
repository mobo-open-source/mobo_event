
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/utils/odoo_compat.dart';
import '../model/answer.dart';
import '../model/event_question.dart';

class QuestionService {
  /// Fetch questions with answers
  Future<List<EventQuestion>> fetchQuestionsWithAnswers(int eventId) async {
    try {
      final compat = await OdooCompat.current();

      final qRes = await OdooSessionManager.callKwWithCompany({
        "model": "event.question",
        "method": "search_read",
        "args": [],
        "kwargs": {
          "domain": [
            [compat.questionEventField, "in", [eventId]],
          ],

          "order": "sequence asc",
        },
      });

      final res = qRes as List;
      if(res .isEmpty){
        return [];
      }

      final questions = (res)
          .map((e) => EventQuestion.fromJson(e))
          .toList();

      final Set<int> allAnswerIds = {};
      for (var q in questions) {
        allAnswerIds.addAll(q.answerIds);
      }

      if (allAnswerIds.isEmpty) return questions;

      final aRes = await OdooSessionManager.callKwWithCompany({
        "model": "event.question.answer",
        "method": "search_read",
        "args": [],
        "kwargs": {
          "domain": [
            ["id", "in", allAnswerIds.toList()],
          ],
          "fields": ["id", "display_name"],
        },
      });

      final answers = (aRes as List)
          .map((e) => EventAnswer.fromJson(e))
          .toList();

      final Map<int, EventAnswer> answerMap = {for (var a in answers) a.id: a};

      return questions.map((q) {
        final qAnswers = q.answerIds
            .map((id) => answerMap[id])
            .whereType<EventAnswer>()
            .toList();

        return q.copyWith(answers: qAnswers);
      }).toList();

    } catch (_) {
      rethrow;
    }
  }

  /// Remove question
  Future<void> removeQuestion(int eventId, int questionId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {
            'question_ids': [
              [3, questionId],
            ],
          },
        ],
        'kwargs': {},
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Add questions
  Future addQuestions(List<int> ids, int eventId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {
            'question_ids': ids.map((id) => [4, id]).toList(),
          },
        ],
        'kwargs': {},
      });
    } catch (_) {
      rethrow;
    }
  }

  Future fetchRemainQuestionList(List<int> listedQuestionId) async {
    try {
      final qRes = await OdooSessionManager.callKwWithCompany({
        "model": "event.question",
        "method": "search_read",
        "args": [],
        "kwargs": {
          'domain': [
            '&',
            ['is_reusable', '=', true],
            '!',
            ['id', 'in', listedQuestionId],
          ],
          "fields": [

          ],
          "order": "sequence asc",
        },
      });

      final response = qRes as List;

      final rQuestion = response
          .map((single) => EventQuestion.fromJson(single))
          .toList();

      return rQuestion;
    } catch (_) {
      rethrow;
    }
  }

  /// Save question to Odoo
  Future<void> saveQuestionToOdoo({
    required String title,
    required bool isMandatory,
    required String questionType,
    required bool oncePerOrder,
    required bool isDefault,
    required bool isReusable,
    required List<String> answers,
    required int eventId,
    int sequence = 10,
  }) async {
    try {
      final compat = await OdooCompat.current();
      final payload = {
        'title': title,
        'is_mandatory_answer': isMandatory,
        'question_type': questionType,
        'once_per_order': oncePerOrder,
        if (compat.hasReusableQuestions) 'is_default': isDefault,
        if (compat.hasReusableQuestions) 'is_reusable': isReusable,
        'sequence': sequence,

        if (answers.isNotEmpty)
          'answer_ids': answers.asMap().entries.map((e) {
            return [
              0,
              0,
              {
                'sequence': (e.key + 1) * 10,
                'name': e.value,
              },
            ];
          }).toList(),
      };

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'event.question',
        'method': 'create',
        'args': [ payload],
      });
      await OdooSessionManager.callKwWithCompany({
        'model': 'event.event',
        'method': 'write',
        'args': [
          [eventId],
          {
            'question_ids': [
              [4, result]
            ]
          }
        ],
      });

    } catch (_) {
      // Not swallowed: a refusal (no create access on the question, no write
      // access on the event) has to reach the dialog, which otherwise reports
      // "Created and saved" over a question that was never linked.
      rethrow;
    }
  }

  /// Edit question
  Future<void> editQuestions({
    required int questionId,
    required String title,
    required bool isMandatory,
    required String questionType,
    required bool oncePerOrder,
    required bool isDefault,
    required bool isReusable,
    required List<String> answers,
    required int eventId,
    int sequence = 10,
  }) async {
    try {
      final compat = await OdooCompat.current();
      final payload = {
        'title': title,
        'is_mandatory_answer': isMandatory,
        'question_type': questionType,
        'once_per_order': oncePerOrder,
        if (compat.hasReusableQuestions) 'is_default': isDefault,
        if (compat.hasReusableQuestions) 'is_reusable': isReusable,
        'sequence': sequence,

        'answer_ids': [
          [5, 0, 0],
          if (answers.isNotEmpty)
            ...answers.asMap().entries.map((e) {
              return [
                0,
                0,
                {
                  'sequence': (e.key + 1) * 10,
                  'name': e.value,
                },
              ];
            }).toList(),
        ],
      };

      await OdooSessionManager.callKwWithCompany({
        'model': 'event.question',
        'method': 'write',
        'args': [
          [questionId],
          payload,
        ],
      });

       } catch (_) {
       rethrow;
    }
  }

}
