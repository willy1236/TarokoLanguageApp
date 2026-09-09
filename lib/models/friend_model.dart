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

/// 撥給我、還在響的來電（GET /api/friends/calls/incoming，也是推播漏接的 fallback）。
class IncomingCall {
  final int callId;
  final int callerUid;
  final String? callerNickname;
  final String? callerFriendCode;
  final String? callerAvatarUrl;
  final DateTime createdAt;

  const IncomingCall({
    required this.callId,
    required this.callerUid,
    this.callerNickname,
    this.callerFriendCode,
    this.callerAvatarUrl,
    required this.createdAt,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> j) => IncomingCall(
    callId: (j['call_id'] as num?)?.toInt() ?? 0,
    callerUid: (j['caller_uid'] as num?)?.toInt() ?? 0,
    callerNickname: j['caller_nickname'] as String?,
    callerFriendCode: j['caller_friend_code'] as String?,
    callerAvatarUrl: j['caller_avatar_url'] as String?,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

/// GET /api/friends/calls/:id 的一通來電狀態（撥出方輪詢用）。
class DirectedCallStatus {
  final int callId;
  final String status; // ringing / accepted / declined / cancelled / missed / ended
  final int? sessionId;
  final int peerUid;
  final String? peerNickname;

  const DirectedCallStatus({
    required this.callId,
    required this.status,
    this.sessionId,
    required this.peerUid,
    this.peerNickname,
  });

  factory DirectedCallStatus.fromJson(Map<String, dynamic> j) => DirectedCallStatus(
    callId: (j['call_id'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? '',
    sessionId: (j['session_id'] as num?)?.toInt(),
    peerUid: (j['peer_uid'] as num?)?.toInt() ?? 0,
    peerNickname: j['peer_nickname'] as String?,
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
