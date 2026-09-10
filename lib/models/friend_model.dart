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
  final String? avatarId;
  final String? frameId;
  final String? selfIntro;

  const FriendUser({
    required this.uid,
    this.nickname,
    this.friendCode,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    this.selfIntro,
  });

  factory FriendUser.fromJson(Map<String, dynamic> j) => FriendUser(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
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
    super.avatarId,
    super.frameId,
    super.selfIntro,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    selfIntro: j['self_intro'] as String?,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

/// 羈絆展示同意狀態（POST/DELETE /api/friends/:uid/showcase、GET /api/friends）。
/// mine=我是否已同意展示；theirs=對方是否已同意；mutual=雙方皆同意（僅此時對外公開檔案可見）。
class Showcase {
  final bool mine;
  final bool theirs;
  final bool mutual;

  const Showcase({required this.mine, required this.theirs, required this.mutual});

  factory Showcase.fromJson(Map<String, dynamic> j) => Showcase(
    mine: j['mine'] as bool? ?? false,
    theirs: j['theirs'] as bool? ?? false,
    mutual: j['mutual'] as bool? ?? false,
  );

  static const none = Showcase(mine: false, theirs: false, mutual: false);
}

class Friendship extends FriendUser {
  final int bondPoints;
  final BondLevelInfo bondLevel;
  final DateTime? acceptedAt;
  final Showcase showcase;

  const Friendship({
    required super.uid,
    super.nickname,
    super.friendCode,
    super.avatarUrl,
    super.avatarId,
    super.frameId,
    super.selfIntro,
    required this.bondPoints,
    required this.bondLevel,
    this.acceptedAt,
    this.showcase = Showcase.none,
  });

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    selfIntro: j['self_intro'] as String?,
    bondPoints: (j['bond_points'] as num?)?.toInt() ?? 0,
    bondLevel: j['bond_level'] is Map<String, dynamic>
        ? BondLevelInfo.fromJson(j['bond_level'] as Map<String, dynamic>)
        : const BondLevelInfo(level: 1, name: '初識'),
    acceptedAt: j['accepted_at'] == null
        ? null
        : DateTime.tryParse(j['accepted_at'].toString()),
    showcase: j['showcase'] is Map<String, dynamic>
        ? Showcase.fromJson(j['showcase'] as Map<String, dynamic>)
        : Showcase.none,
  );

  Friendship copyWith({
    String? nickname,
    String? friendCode,
    String? avatarUrl,
    String? avatarId,
    String? frameId,
    String? selfIntro,
    int? bondPoints,
    BondLevelInfo? bondLevel,
    DateTime? acceptedAt,
    Showcase? showcase,
  }) => Friendship(
    uid: uid,
    nickname: nickname ?? this.nickname,
    friendCode: friendCode ?? this.friendCode,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    avatarId: avatarId ?? this.avatarId,
    frameId: frameId ?? this.frameId,
    selfIntro: selfIntro ?? this.selfIntro,
    bondPoints: bondPoints ?? this.bondPoints,
    bondLevel: bondLevel ?? this.bondLevel,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    showcase: showcase ?? this.showcase,
  );
}

/// 撥給我、還在響的來電（GET /api/friends/calls/incoming，也是推播漏接的 fallback）。
class IncomingCall {
  final int callId;
  final int callerUid;
  final String? callerNickname;
  final String? callerFriendCode;
  final String? callerAvatarUrl;
  final String? callerAvatarId;
  final String? callerFrameId;
  final DateTime createdAt;

  const IncomingCall({
    required this.callId,
    required this.callerUid,
    this.callerNickname,
    this.callerFriendCode,
    this.callerAvatarUrl,
    this.callerAvatarId,
    this.callerFrameId,
    required this.createdAt,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> j) => IncomingCall(
    callId: int.tryParse(j['call_id']?.toString() ?? '') ?? 0,
    callerUid: int.tryParse(j['caller_uid']?.toString() ?? '') ?? 0,
    callerNickname: j['caller_nickname'] as String?,
    callerFriendCode: j['caller_friend_code'] as String?,
    callerAvatarUrl: j['caller_avatar_url'] as String?,
    callerAvatarId: j['caller_avatar_id'] as String?,
    callerFrameId: j['caller_frame_id'] as String?,
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
    callId: int.tryParse(j['call_id']?.toString() ?? '') ?? 0,
    status: j['status'] as String? ?? '',
    sessionId: int.tryParse(j['session_id']?.toString() ?? ''),
    peerUid: int.tryParse(j['peer_uid']?.toString() ?? '') ?? 0,
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
    super.avatarId,
    super.frameId,
    super.selfIntro,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
    uid: (j['uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    selfIntro: j['self_intro'] as String?,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
