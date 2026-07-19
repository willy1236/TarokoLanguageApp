// 對應 users 資料表 / POST /api/auth/login、GET /api/me 回傳的 user JSON
// 規格參考：docs/資料流通與資料庫總覽.md §3.2 B. users、§4 Flow 2
// avatar_id/frame_id/millet/owned_avatar_ids/owned_frame_ids 見
// Truku_backend 說明文件/API/頭像商店.md v2.0
//
// avatar_id 為 null 代表使用者尚未選用任何內建頭像，屬正常預設狀態、非缺值或錯誤，
// 此時應 fallback 顯示 avatarUrl（登入帳號頭像）。frame_id 為 null 代表未配戴頭像框，
// 兩者各自獨立、可同時配戴。

class UserModel {
  final String uid;
  final String? displayName;
  final String? avatarUrl; // 原 Google 大頭貼，avatarId 為 null 時的 fallback
  final String? avatarId; // 目前配戴的內建頭像 id，對應 item_catalog；null=尚未選用內建頭像
  final String? frameId; // 目前配戴的頭像框 id，對應 item_catalog；null=未配戴
  final List<String> ownedAvatarIds;
  final List<String> ownedFrameIds;
  final int millet; // 小米幣餘額

  const UserModel({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    this.ownedAvatarIds = const [],
    this.ownedFrameIds = const [],
    this.millet = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'].toString(),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarId: json['avatar_id'] as String?,
      frameId: json['frame_id'] as String?,
      ownedAvatarIds: (json['owned_avatar_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      ownedFrameIds: (json['owned_frame_ids'] as List<dynamic>? ?? [])
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
        'frame_id': frameId,
        'owned_avatar_ids': ownedAvatarIds,
        'owned_frame_ids': ownedFrameIds,
        'millet': millet,
      };

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    String? avatarId,
    String? frameId,
    List<String>? ownedAvatarIds,
    List<String>? ownedFrameIds,
    int? millet,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      frameId: frameId ?? this.frameId,
      ownedAvatarIds: ownedAvatarIds ?? this.ownedAvatarIds,
      ownedFrameIds: ownedFrameIds ?? this.ownedFrameIds,
      millet: millet ?? this.millet,
    );
  }
}
