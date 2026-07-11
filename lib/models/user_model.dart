// 對應 users 資料表 / POST /api/auth/login、GET /api/me 回傳的 user JSON
// 規格參考：docs/資料流通與資料庫總覽.md §3.2 B. users、§4 Flow 2
//
// avatarId / ownedAvatarIds / coins 目前後端尚未回傳（頭像兌換系統 #12 進行中），
// fromJson 需容忍缺失並給預設值。
//
// 未來 #11（頭像框）可比照本檔新增對稱的 avatarFrameId / ownedFrameIds 欄位，
// 本次不實作。

class UserModel {
  final String uid;
  final String? displayName;
  final String? avatarUrl; // 原 Google 大頭貼，fallback 用
  final String? avatarId; // 目前配戴的內建頭像 id，對應 avatar_catalog
  final List<String> ownedAvatarIds;
  final int coins; // 小米幣餘額

  const UserModel({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.avatarId,
    this.ownedAvatarIds = const [],
    this.coins = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'].toString(),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarId: json['avatar_id'] as String?,
      ownedAvatarIds: (json['owned_avatar_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      coins: json['coins'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'avatar_id': avatarId,
        'owned_avatar_ids': ownedAvatarIds,
        'coins': coins,
      };

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    String? avatarId,
    List<String>? ownedAvatarIds,
    int? coins,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      ownedAvatarIds: ownedAvatarIds ?? this.ownedAvatarIds,
      coins: coins ?? this.coins,
    );
  }
}
