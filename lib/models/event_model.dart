// 對應 events / event_participants / event_reminders 資料表，以及
// GET /api/events/:id、POST /api/events、GET|POST /api/events/:id/reminders 回傳 JSON。
// 後端規格：Truku_backend backend/routes/events.ts
//
// 後端回傳為 snake_case，這裡轉成 Dart 慣用的 camelCase。未知欄位（v2 擴充如
// reminder_note、報名截止…）不解析也不影響，需要時再補欄位即可。

/// 後端理論上都回數字，但曾遇過某些環境把 bigint 欄位序列化成字串；
/// 這裡統一容錯解析，避免整頁因單一欄位型別跳掉而白畫面。
int? asEventInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class EventDetail {
  final int id;
  final int hostUid;
  final String title;
  final String? description;
  final DateTime startsAt;
  final String? location;
  final String? address; // 詳細地址（前端可一鍵導航）
  final DateTime? registrationDeadline;
  final String? contactEmail;
  final String? contactPhone;
  final String? reminderNote; // 發起人給參加者的備註
  final int? maxParticipants; // null = 不限名額
  final String? category; // 活動分類標籤，可能為 null
  final String status; // active | cancelled（原始 DB 狀態）
  final String? effectiveStatus; // 後端即時算：active | ended | cancelled
  final bool registrationOpen; // 仍 active、未過截止、未開始
  final DateTime? createdAt;
  final List<EventParticipant> participants;
  // 後端直接算好的人數；非發起人只會收到空 participants 陣列，這時仍要靠這個
  // 欄位顯示正確人數，不能用 participants.length（見 EventSummary 的同名欄位）。
  final int? participantCountRaw;
  final int likeCount; // 即時 COUNT，非反正規化欄位
  final bool isLiked;
  final bool isBookmarked;

  const EventDetail({
    required this.id,
    required this.hostUid,
    required this.title,
    this.description,
    required this.startsAt,
    this.location,
    this.address,
    this.registrationDeadline,
    this.contactEmail,
    this.contactPhone,
    this.reminderNote,
    this.maxParticipants,
    this.category,
    required this.status,
    this.effectiveStatus,
    this.registrationOpen = false,
    this.createdAt,
    this.participants = const [],
    this.participantCountRaw,
    this.likeCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  /// 目前登入者是否為發起人（判斷要不要顯示「發送提醒」「取消活動」）。
  bool isHostedBy(int? uid) => uid != null && uid == hostUid;

  /// 優先用後端算好的計數；只有在後端沒帶這個欄位時才 fallback 用陣列長度
  /// （這種情況只在拿得到完整 participants 時才準）。
  int get participantCount => participantCountRaw ?? participants.length;

  /// 目前登入者是否已報名。
  bool isJoinedBy(int? uid) =>
      uid != null && participants.any((p) => p.uid == uid);

  /// 名額是否已滿（不限名額時永遠 false）。
  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;

  /// 對外顯示狀態；後端沒帶時退回原始 status。
  String get displayStatus => effectiveStatus ?? status;

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    final rawParts = json['participants'] as List<dynamic>? ?? const [];
    return EventDetail(
      id: asEventInt(json['id'])!,
      hostUid: asEventInt(json['host_uid'])!,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      location: json['location'] as String?,
      address: json['address'] as String?,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      reminderNote: json['reminder_note'] as String?,
      maxParticipants: asEventInt(json['max_participants']),
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'active',
      effectiveStatus: json['effective_status'] as String?,
      registrationOpen: json['registration_open'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      participants: rawParts
          .map((e) => EventParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      participantCountRaw: asEventInt(json['participant_count']),
      likeCount: asEventInt(json['like_count']) ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
    );
  }

  /// 樂觀更新用：切換按讚狀態並同步計數，等後端真實回應後再校正。
  EventDetail toggledLike() => _copyWith(
    likeCount: isLiked ? likeCount - 1 : likeCount + 1,
    isLiked: !isLiked,
  );

  EventDetail toggledBookmark() => _copyWith(isBookmarked: !isBookmarked);

  /// API 回傳真實計數後校正，避免樂觀更新的本地累加值飄移。
  EventDetail withLikeResult({required bool liked, required int likeCount}) =>
      _copyWith(isLiked: liked, likeCount: likeCount);

  EventDetail _copyWith({int? likeCount, bool? isLiked, bool? isBookmarked}) =>
      EventDetail(
        id: id,
        hostUid: hostUid,
        title: title,
        description: description,
        startsAt: startsAt,
        location: location,
        address: address,
        registrationDeadline: registrationDeadline,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        reminderNote: reminderNote,
        maxParticipants: maxParticipants,
        category: category,
        status: status,
        effectiveStatus: effectiveStatus,
        registrationOpen: registrationOpen,
        createdAt: createdAt,
        participants: participants,
        participantCountRaw: participantCountRaw,
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
        isBookmarked: isBookmarked ?? this.isBookmarked,
      );
}

/// 活動列表項目（GET /api/events 回傳的 events[]，欄位比詳情頁精簡，
/// 但多了 participantCount / isJoined / 即時算出的狀態）。
class EventSummary {
  final int id;
  final int? hostUid; // GET /api/events 有；GET /api/events/mine 不回傳
  final String title;
  final DateTime startsAt;
  final String? location;
  final int? maxParticipants; // null = 不限名額
  final String? category; // 活動分類標籤，可能為 null
  final String status; // active | cancelled
  final int participantCount;
  final bool isJoined;
  final DateTime? registrationDeadline;
  final String? effectiveStatus; // 後端即時算：active / ended / cancelled
  final bool registrationOpen;
  final int likeCount; // 即時 COUNT，非反正規化欄位
  final bool isLiked;
  final bool isBookmarked;

  const EventSummary({
    required this.id,
    this.hostUid,
    required this.title,
    required this.startsAt,
    this.location,
    this.maxParticipants,
    this.category,
    required this.status,
    this.participantCount = 0,
    this.isJoined = false,
    this.registrationDeadline,
    this.effectiveStatus,
    this.registrationOpen = false,
    this.likeCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  bool isHostedBy(int? uid) => uid != null && uid == hostUid;

  /// 名額是否已滿（不限名額時永遠 false）。
  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;

  /// 對外顯示狀態；後端沒帶時退回原始 status。
  String get displayStatus => effectiveStatus ?? status;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id: asEventInt(json['id'])!,
      hostUid: asEventInt(json['host_uid']),
      title: json['title'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      location: json['location'] as String?,
      maxParticipants: asEventInt(json['max_participants']),
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'active',
      participantCount: asEventInt(json['participant_count']) ?? 0,
      isJoined: json['is_joined'] as bool? ?? false,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      effectiveStatus: json['effective_status'] as String?,
      registrationOpen: json['registration_open'] as bool? ?? false,
      likeCount: asEventInt(json['like_count']) ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
    );
  }
}

class EventParticipant {
  final int uid;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? joinedAt;

  const EventParticipant({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.joinedAt,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    return EventParticipant(
      uid: asEventInt(json['uid'])!,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }
}

class EventReminder {
  final int id;
  final int? eventId;
  final String message;
  final DateTime scheduledAt;
  final String status; // pending | sent | failed | cancelled
  final DateTime? sentAt;

  const EventReminder({
    required this.id,
    this.eventId,
    required this.message,
    required this.scheduledAt,
    required this.status,
    this.sentAt,
  });

  bool get isPending => status == 'pending';

  factory EventReminder.fromJson(Map<String, dynamic> json) {
    return EventReminder(
      id: asEventInt(json['id'])!,
      eventId: asEventInt(json['event_id']),
      message: json['message'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String? ?? 'pending',
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
    );
  }
}
