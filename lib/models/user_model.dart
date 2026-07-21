class UserModel {
  final int uid;
  final String? displayName;
  final String? avatarUrl;
  final String email;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    required this.email,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as int,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  int get joinedDays => DateTime.now().difference(createdAt).inDays;
}
