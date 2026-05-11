class ReactionModel {
  final String id;
  final String sessionId;
  final String? studentId;
  final String studentName;
  final String type;
  final DateTime createdAt;

  const ReactionModel({
    required this.id,
    required this.sessionId,
    this.studentId,
    required this.studentName,
    required this.type,
    required this.createdAt,
  });

  bool get isGreen => type == 'green';
  bool get isYellow => type == 'yellow';
  bool get isRed => type == 'red';

  factory ReactionModel.fromJson(Map<String, dynamic> json) => ReactionModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        studentId: json['student_id'] as String?,
        studentName: json['student_name'] as String? ?? 'Anonymous',
        type: json['type'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'student_name': studentName,
        'type': type,
        'created_at': createdAt.toIso8601String(),
      };
}
