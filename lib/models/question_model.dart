class QuestionModel {
  final String id;
  final String sessionId;
  final String? slideId;
  final String questionText;
  final String sourceType;
  final bool isPushed;
  final DateTime createdAt;

  const QuestionModel({
    required this.id,
    required this.sessionId,
    this.slideId,
    required this.questionText,
    required this.sourceType,
    required this.isPushed,
    required this.createdAt,
  });

  bool get isFromSlide => sourceType == 'slide';
  bool get isFromConfused => sourceType == 'confused';

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        slideId: json['slide_id'] as String?,
        questionText: json['question_text'] as String,
        sourceType: json['source_type'] as String,
        isPushed: json['is_pushed'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'slide_id': slideId,
        'question_text': questionText,
        'source_type': sourceType,
        'is_pushed': isPushed,
        'created_at': createdAt.toIso8601String(),
      };
}
