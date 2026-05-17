class SlideModel {
  final String id;
  final String sessionId;
  final String fileUrl;
  final String fileName;
  final int orderIndex;
  final DateTime createdAt;
  final String? speakerNotes;

  const SlideModel({
    required this.id,
    required this.sessionId,
    required this.fileUrl,
    required this.fileName,
    required this.orderIndex,
    required this.createdAt,
    this.speakerNotes,
  });

  factory SlideModel.fromJson(Map<String, dynamic> json) => SlideModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        fileUrl: json['file_url'] as String,
        fileName: json['file_name'] as String,
        orderIndex: json['order_index'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        speakerNotes: json['speaker_notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'file_url': fileUrl,
        'file_name': fileName,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'speaker_notes': speakerNotes,
      };
}
