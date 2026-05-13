class AnonQuestionModel {
  final String id;
  final String sessionId;
  final String questionText;
  final DateTime createdAt;

  const AnonQuestionModel({
    required this.id,
    required this.sessionId,
    required this.questionText,
    required this.createdAt,
  });

  factory AnonQuestionModel.fromJson(Map<String, dynamic> json) => AnonQuestionModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        questionText: json['question_text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
