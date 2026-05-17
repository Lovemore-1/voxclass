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

  // Live presentation state
  final String? currentSlideId;
  final int currentPage;
  final double? pointerX;
  final double? pointerY;
  final bool pointerVisible;

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
    this.currentSlideId,
    this.currentPage = 1,
    this.pointerX,
    this.pointerY,
    this.pointerVisible = false,
  });

  bool get isActive => status == 'active';
  bool get isPresenting => currentSlideId != null;

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
        currentSlideId: json['current_slide_id'] as String?,
        currentPage: (json['current_page'] as int?) ?? 1,
        pointerX: (json['pointer_x'] as num?)?.toDouble(),
        pointerY: (json['pointer_y'] as num?)?.toDouble(),
        pointerVisible: (json['pointer_visible'] as bool?) ?? false,
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
        'current_slide_id': currentSlideId,
        'pointer_x': pointerX,
        'pointer_y': pointerY,
        'pointer_visible': pointerVisible,
      };
}
