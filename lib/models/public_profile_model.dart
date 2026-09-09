// GET /api/users/:friend_code 回傳的公開個人檔案。
// 只含公開資訊，絕不含真名/email/族群等隱私（見 Truku_backend routes/auth.ts）。

class BondLevel {
  final int level;
  final String name;

  const BondLevel({required this.level, required this.name});

  factory BondLevel.fromJson(Map<String, dynamic> j) => BondLevel(
    level: (j['level'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? '',
  );
}

class PublicProfile {
  final int uid;
  final String? nickname;
  final String friendCode;
  final String? selfIntro;
  final String? avatarUrl;
  final String? avatarId;
  final String? frameId;
  final DateTime joinedAt;
  final BondLevel? bondLevel;

  const PublicProfile({
    required this.uid,
    this.nickname,
    required this.friendCode,
    this.selfIntro,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    required this.joinedAt,
    this.bondLevel,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String? ?? '',
    selfIntro: j['self_intro'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    joinedAt: DateTime.tryParse(j['joined_at']?.toString() ?? '') ?? DateTime.now(),
    bondLevel: j['bond_level'] is Map<String, dynamic>
        ? BondLevel.fromJson(j['bond_level'] as Map<String, dynamic>)
        : null,
  );

  int get joinedDays => DateTime.now().difference(joinedAt).inDays;
}
