// 對應 users 資料表 / POST /api/auth/login、GET /api/me 回傳的 user JSON
// 規格參考：docs/資料流通與資料庫總覽.md §3.2 B. users、§4 Flow 2
// avatar_id/frame_id/millet/owned_avatar_ids/owned_frame_ids 見
// Truku_backend 說明文件/API/頭像商店.md v2.0
//
// avatar_id 為 null 代表使用者尚未選用任何內建頭像，屬正常預設狀態、非缺值或錯誤，
// 此時應 fallback 顯示 avatarUrl（登入帳號頭像）。frame_id 為 null 代表未配戴頭像框，
// 兩者各自獨立、可同時配戴。

class UserModel {
  final int uid;
  final String? displayName;
  final String? avatarUrl; // 原 Google 大頭貼，avatarId 為 null 時的 fallback
  final String? avatarId; // 目前配戴的內建頭像 id，對應 item_catalog；null=尚未選用內建頭像
  final String? frameId; // 目前配戴的頭像框 id，對應 item_catalog；null=未配戴
  final List<String> ownedAvatarIds;
  final List<String> ownedFrameIds;
  final int millet; // 小米幣餘額
  final String email;
  final DateTime createdAt;
  final bool checkedInToday; // 今天（台灣時間）是否已簽到，見 每日簽到.md
  final int checkinStreak; // 目前連續簽到天數，由後端即時計算
  final String? ethnicGroup; // 族群，見 00_核心與認證.md §2.5；未設為 null
  final int? tribeId; // 部落 id，對應 tribes.id；未設為 null
  final String? tribeName; // 部落中文名，由後端 join tribes 帶出
  final bool? isIndigenous; // 是否原住民；ethnicGroup 一經設定即永久鎖定
  final String? tribalName; // 本人族語名，不受 ethnicGroup 鎖定限制，可隨時修改
  final bool profileCompleted; // 首次登入完善資料是否已完成，見 issue #43
  final String? quizSuggestedLevel; // 分級測驗建議的單字起始等級；null=尚未分級
  final String? listeningSuggestedLevel; // 分級測驗建議的聽力起始等級；null=尚未分級

  const UserModel({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    this.ownedAvatarIds = const [],
    this.ownedFrameIds = const [],
    this.millet = 0,
    required this.email,
    required this.createdAt,
    this.checkedInToday = false,
    this.checkinStreak = 0,
    this.ethnicGroup,
    this.tribeId,
    this.tribeName,
    this.isIndigenous,
    this.tribalName,
    this.profileCompleted = false,
    this.quizSuggestedLevel,
    this.listeningSuggestedLevel,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as int,
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
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      checkinStreak: json['checkin_streak'] as int? ?? 0,
      ethnicGroup: json['ethnic_group'] as String?,
      tribeId: json['tribe_id'] as int?,
      tribeName: json['tribe_name'] as String?,
      isIndigenous: json['is_indigenous'] as bool?,
      tribalName: json['tribal_name'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      quizSuggestedLevel: json['quiz_suggested_level'] as String?,
      listeningSuggestedLevel: json['listening_suggested_level'] as String?,
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
        'email': email,
        'created_at': createdAt.toIso8601String(),
        'checked_in_today': checkedInToday,
        'checkin_streak': checkinStreak,
        'ethnic_group': ethnicGroup,
        'tribe_id': tribeId,
        'tribe_name': tribeName,
        'is_indigenous': isIndigenous,
        'tribal_name': tribalName,
        'profile_completed': profileCompleted,
        'quiz_suggested_level': quizSuggestedLevel,
        'listening_suggested_level': listeningSuggestedLevel,
      };

  int get joinedDays => DateTime.now().difference(createdAt).inDays;

  UserModel copyWith({
    int? uid,
    String? displayName,
    String? avatarUrl,
    String? avatarId,
    String? frameId,
    List<String>? ownedAvatarIds,
    List<String>? ownedFrameIds,
    int? millet,
    String? email,
    DateTime? createdAt,
    bool? checkedInToday,
    int? checkinStreak,
    String? ethnicGroup,
    int? tribeId,
    String? tribeName,
    bool? isIndigenous,
    String? tribalName,
    bool? profileCompleted,
    String? quizSuggestedLevel,
    String? listeningSuggestedLevel,
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
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      checkedInToday: checkedInToday ?? this.checkedInToday,
      checkinStreak: checkinStreak ?? this.checkinStreak,
      ethnicGroup: ethnicGroup ?? this.ethnicGroup,
      tribeId: tribeId ?? this.tribeId,
      tribeName: tribeName ?? this.tribeName,
      isIndigenous: isIndigenous ?? this.isIndigenous,
      tribalName: tribalName ?? this.tribalName,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      quizSuggestedLevel: quizSuggestedLevel ?? this.quizSuggestedLevel,
      listeningSuggestedLevel:
          listeningSuggestedLevel ?? this.listeningSuggestedLevel,
    );
  }
}
