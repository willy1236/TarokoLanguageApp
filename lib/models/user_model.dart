// 對應 users 資料表 / POST /api/auth/login、GET /api/me 回傳的 user JSON
// 規格參考：docs/資料流通與資料庫總覽.md §3.2 B. users、§4 Flow 2
//
// avatar_id / owned_avatar_ids / millet 目前後端尚未回傳（頭像兌換系統 #12 進行中，
// 後端規格見 Truku_backend#1，尚未 merge），fromJson 需容忍缺失並給預設值。
// 欄位命名跟隨後端 Truku_backend#1 定案：貨幣欄位是 `millet`，不是 `coins`。
//
// avatar_id 為 null 代表使用者尚未選用任何內建頭像，屬正常預設狀態、非缺值或錯誤，
// 此時應 fallback 顯示 avatarUrl（登入帳號頭像）。
//
// 未來 #11（頭像框）可比照本檔新增對稱的 avatarFrameId / ownedFrameIds 欄位，
// 本次不實作。

class UserModel {
  final String uid;
  final String? displayName;
  final String? avatarUrl; // 原 Google 大頭貼，avatarId 為 null 時的 fallback
  final String? avatarId; // 目前配戴的內建頭像 id，對應 avatar_catalog；null=尚未選用內建頭像
  final List<String> ownedAvatarIds;
  final int millet; // 小米幣餘額

  const UserModel({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.avatarId,
    this.ownedAvatarIds = const [],
    this.millet = 0,
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
      millet: json['millet'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'avatar_id': avatarId,
        'owned_avatar_ids': ownedAvatarIds,
        'millet': millet,
      };

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    String? avatarId,
    List<String>? ownedAvatarIds,
    int? millet,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      ownedAvatarIds: ownedAvatarIds ?? this.ownedAvatarIds,
      millet: millet ?? this.millet,
    );
  }
}
