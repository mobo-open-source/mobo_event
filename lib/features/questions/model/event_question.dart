import 'package:mobo_event/features/questions/model/answer.dart';

class EventQuestion {
  final int id;
  final String displayName;
  final String title;
  final String questionType;
  final List<int> answerIds;
  final List<EventAnswer> answers;
  final bool oncePerOrder;
  final bool isMandatoryAnswer;
  final bool isDefault;
  final bool isReusable;

  EventQuestion({
    required this.id,
    required this.displayName,
    required this.title,
    required this.questionType,
    required this.answerIds,
    required this.answers,
    required this.oncePerOrder,
    required this.isMandatoryAnswer,
    required this.isDefault,
    required this.isReusable,

  });

  factory EventQuestion.fromJson(Map<String, dynamic> json) {
    return EventQuestion(
      id: json['id'],
      displayName: json['display_name'] ?? '',
      title: json['title'] ?? '',
      questionType: json['question_type'] ?? '',
      answerIds: List<int>.from(json['answer_ids'] ?? []),
      answers: [],
      oncePerOrder: json['once_per_order'] ?? false,
      isMandatoryAnswer: json['is_mandatory_answer'] ?? false,
      isDefault: json['is_default'] ?? false,
      isReusable: json['is_reusable'] ?? false,
    );
  }

  EventQuestion copyWith({
    List<EventAnswer>? answers,
  }) {
    return EventQuestion(
      id: id,
      displayName: displayName,
      title: title,
      questionType: questionType,
      answerIds: answerIds,
      answers: answers ?? this.answers,
      oncePerOrder: oncePerOrder,
      isMandatoryAnswer: isMandatoryAnswer,
      isDefault: isDefault,
      isReusable: isReusable,
    );
  }

  /// Compared by record id, so a picker recognises the value it was handed
  /// among options it loaded itself (a separate object for the same record).
  @override
  bool operator ==(Object other) => other is EventQuestion && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
