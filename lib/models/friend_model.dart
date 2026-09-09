// 好友關係 + 封鎖（見 Truku_backend backend/routes/friends.ts）。
// 對外一律以公開暱稱／好友碼呈現，絕不含真名/email/族群等隱私。

class BondLevelInfo {
  final int level;
  final String name;

  const BondLevelInfo({required this.level, required this.name});

  factory BondLevelInfo.fromJson(Map<String, dynamic> j) => BondLevelInfo(
    level: (j['level'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? '',
  );
}

/// 好友列表／邀請列表／封鎖名單共用的公開使用者欄位。
class FriendUser {
  final int uid;
  final String? nickname;
  final String? friendCode;
  final String? avatarUrl;
  final String? selfIntro;

  const FriendUser({
    required this.uid,
    this.nickname,
    this.friendCode,
    this.avatarUrl,
    this.selfIntro,
  });

  factory FriendUser.fromJson(Map<String, dynamic> j) => FriendUser(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    selfIntro: j['self_intro'] as String?,
  );
}

class FriendRequest extends FriendUser {
  final DateTime createdAt;

  const FriendRequest({
    required super.uid,
    super.nickname,
    super.friendCode,
    super.avatarUrl,
    super.selfIntro,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    selfIntro: j['self_intro'] as String?,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

class Friendship extends FriendUser {
  final int bondPoints;
  final BondLevelInfo bondLevel;
  final DateTime? acceptedAt;

  const Friendship({
    required super.uid,
    super.nickname,
    super.friendCode,
    super.avatarUrl,
    super.selfIntro,
    required this.bondPoints,
    required this.bondLevel,
    this.acceptedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    selfIntro: j['self_intro'] as String?,
    bondPoints: (j['bond_points'] as num?)?.toInt() ?? 0,
    bondLevel: j['bond_level'] is Map<String, dynamic>
        ? BondLevelInfo.fromJson(j['bond_level'] as Map<String, dynamic>)
        : const BondLevelInfo(level: 1, name: '初識'),
    acceptedAt: j['accepted_at'] == null
        ? null
        : DateTime.tryParse(j['accepted_at'].toString()),
  );
}

class BlockedUser extends FriendUser {
  final DateTime createdAt;

  const BlockedUser({
    required super.uid,
    super.nickname,
    super.friendCode,
    super.avatarUrl,
    super.selfIntro,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    selfIntro: j['self_intro'] as String?,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
