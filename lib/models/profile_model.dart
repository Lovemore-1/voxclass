class ProfileModel {
  final String id;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  bool get isLecturer => role == 'lecturer';
  bool get isStudent => role == 'student';

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'role': role,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
