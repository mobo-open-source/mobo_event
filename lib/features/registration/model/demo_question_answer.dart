class DemoQuestionAnswer {
  final int? id;
  final int questionId;
  final dynamic valueAnswerId;
  final dynamic valueTextBox;
  final String? answer;
  final String? selectedValue;
  final String? questionName;

  DemoQuestionAnswer({
    required this.questionId,
    this.valueAnswerId,
    this.valueTextBox,
    this.id,
    this.answer,
    this.questionName,
    this.selectedValue
  });

  factory DemoQuestionAnswer.fromJson(Map<String, dynamic> json) {
    return DemoQuestionAnswer(
      questionId: json['question_id'],
      valueAnswerId: json['value_answer_id'],
      valueTextBox: json['value_text_box'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'value_answer_id': valueAnswerId,
      'value_text_box': valueTextBox,
    };
  }
}
