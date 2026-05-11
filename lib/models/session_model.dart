class SessionModel {
  final String id;
  final String lecturerId;
  final String title;
  final String? subject;
  final String code;
  final String status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int? studentCount;

  const SessionModel({
    required this.id,
    required this.lecturerId,
    required this.title,
    this.subject,
    required this.code,
    required this.status,
    required this.createdAt,
    this.endedAt,
    this.studentCount,
  });

  bool get isActive => status == 'active';

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        id: json['id'] as String,
        lecturerId: json['lecturer_id'] as String,
        title: json['title'] as String,
        subject: json['subject'] as String?,
        code: json['code'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        studentCount: json['student_count'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lecturer_id': lecturerId,
        'title': title,
        'subject': subject,
        'code': code,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      };
}
