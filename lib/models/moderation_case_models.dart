// 當事人看自己被處置的案件與申訴。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §3。
//
// 只看得到自己是被處置者的案件；私訊、通話的待審案件看不到（後端回 404）。

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

int? _int(Object? v) => v == null ? null : int.tryParse('$v');

/// 被處置的內容。各類型給的欄位不同，沒有的留 null：
/// 貼文（標題、內文）、留言／私訊（內文、私訊另有傳送時間）、通話（開始時間）、
/// 活動（標題、說明）、個人檔案（被重設前的值）、自動禁言（都沒有）。
class MyCasePreview {
  final String? title;
  final String? body;
  final DateTime? time;

  /// 個人檔案案件被重設前的值，鍵為後端欄位名（只含被重設的欄位）。
  final Map<String, dynamic> profileBefore;

  const MyCasePreview({
    this.title,
    this.body,
    this.time,
    this.profileBefore = const {},
  });

  static const empty = MyCasePreview();

  bool get isEmpty =>
      title == null && body == null && time == null && profileBefore.isEmpty;

  factory MyCasePreview.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return empty;
    final before = raw['before'];
    return MyCasePreview(
      title: raw['title'] as String?,
      body: (raw['body'] ?? raw['description']) as String?,
      time: _date(raw['sent_at'] ?? raw['started_at']),
      profileBefore: before is Map<String, dynamic> ? before : const {},
    );
  }
}

/// 已確認違規的處罰，或自動禁言案件的那筆禁言。
class MyPenalty {
  final int? strikeNumber;
  final DateTime? muteUntil;
  final bool muteLifted;

  /// 帳號已停權（唯讀）。
  final bool locked;

  const MyPenalty({
    this.strikeNumber,
    this.muteUntil,
    this.muteLifted = false,
    this.locked = false,
  });

  factory MyPenalty.fromJson(Map<String, dynamic> j) => MyPenalty(
    strikeNumber: _int(j['strike_number']),
    muteUntil: _date(j['mute_until']),
    muteLifted: j['mute_lifted'] == true,
    locked: j['locked'] == true,
  );
}

class MyAppeal {
  final int id;

  /// pending／accepted／rejected。
  final String status;
  final String reason;

  /// 管理員給申訴人的回覆，處理前為 null。
  final String? reply;
  final DateTime? createdAt;
  final DateTime? handledAt;

  const MyAppeal({
    required this.id,
    required this.status,
    required this.reason,
    this.reply,
    this.createdAt,
    this.handledAt,
  });

  factory MyAppeal.fromJson(Map<String, dynamic> j) => MyAppeal(
    id: _int(j['id']) ?? 0,
    status: j['status'] as String? ?? 'pending',
    reason: j['reason'] as String? ?? '',
    reply: j['reply'] as String?,
    createdAt: _date(j['created_at']),
    handledAt: _date(j['handled_at']),
  );
}

/// `GET /api/me/moderation/cases/:id` 的整個回應。
class MyModerationCase {
  final int id;

  /// post／comment／message／call／event／profile／mute。
  final String targetType;

  /// pending（待複審）／confirmed（已確認違規）／overturned（已撤銷）。
  final String status;
  final String reason;
  final DateTime? openedAt;
  final DateTime? reviewedAt;

  /// 待審或已撤銷時為 null。
  final MyPenalty? penalty;
  final MyCasePreview preview;

  /// 還沒申訴時為 null。
  final MyAppeal? appeal;
  final bool canAppeal;
  final DateTime? appealDeadline;

  const MyModerationCase({
    required this.id,
    required this.targetType,
    required this.status,
    required this.reason,
    this.openedAt,
    this.reviewedAt,
    this.penalty,
    this.preview = MyCasePreview.empty,
    this.appeal,
    this.canAppeal = false,
    this.appealDeadline,
  });

  factory MyModerationCase.fromJson(Map<String, dynamic> j) {
    final c = j['case'] as Map<String, dynamic>? ?? const {};
    final penalty = c['penalty'];
    final appeal = j['appeal'];
    return MyModerationCase(
      id: _int(c['id']) ?? 0,
      targetType: c['target_type'] as String? ?? '',
      status: c['status'] as String? ?? 'pending',
      reason: c['reason'] as String? ?? '',
      openedAt: _date(c['opened_at']),
      reviewedAt: _date(c['reviewed_at']),
      penalty: penalty is Map<String, dynamic>
          ? MyPenalty.fromJson(penalty)
          : null,
      preview: MyCasePreview.fromJson(c['preview']),
      appeal: appeal is Map<String, dynamic> ? MyAppeal.fromJson(appeal) : null,
      canAppeal: j['can_appeal'] == true,
      appealDeadline: _date(j['appeal_deadline']),
    );
  }

  /// 送出申訴後就地更新：有了申訴就不能再申訴。
  MyModerationCase withAppeal(MyAppeal appeal) => MyModerationCase(
    id: id,
    targetType: targetType,
    status: status,
    reason: reason,
    openedAt: openedAt,
    reviewedAt: reviewedAt,
    penalty: penalty,
    preview: preview,
    appeal: appeal,
    canAppeal: false,
    appealDeadline: appealDeadline,
  );
}

String moderationTargetLabel(String type) => switch (type) {
  'post' => '貼文',
  'comment' => '留言',
  'message' => '私訊',
  'call' => '通話',
  'event' => '活動',
  'profile' => '個人檔案',
  'mute' => '禁言',
  _ => '內容',
};

String moderationCaseStatusLabel(String status) => switch (status) {
  'pending' => '待複審',
  'confirmed' => '已確認',
  'overturned' => '已撤銷',
  _ => status,
};

String appealStatusLabel(String status) => switch (status) {
  'pending' => '處理中',
  'accepted' => '已成立',
  'rejected' => '已駁回',
  _ => status,
};
