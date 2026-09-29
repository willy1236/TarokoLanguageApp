// 管理員後台的資料模型。
// 規格：Truku_backend 說明文件/API/內部管理.md §4～§8.9、安全防護.md「後台端點」。
//
// 後端的後台回應欄位有過渡期寫法（例如檢舉人暱稱曾叫 reporter_name），
// 解析一律容許缺欄位，缺了寧可顯示空白也不要讓整頁載入失敗。

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// 個人檔案檢舉／案件裡被檢舉者目前的公開欄位。
class AdminProfileSnapshot {
  final int? uid;
  final String? nickname;
  final String? selfIntro;
  final String? avatarUrl;
  final String? avatarId;

  const AdminProfileSnapshot({
    this.uid,
    this.nickname,
    this.selfIntro,
    this.avatarUrl,
    this.avatarId,
  });

  factory AdminProfileSnapshot.fromJson(Map<String, dynamic> j) =>
      AdminProfileSnapshot(
        uid: _int(j['uid']),
        nickname: j['nickname'] as String?,
        selfIntro: j['self_intro'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        avatarId: j['avatar_id'] as String?,
      );
}

/// 通話檢舉／案件的通話資訊（沒有內容，只有雙方與時間）。
class AdminCallInfo {
  final int? callerUid;
  final int? calleeUid;
  final String? status;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const AdminCallInfo({
    this.callerUid,
    this.calleeUid,
    this.status,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory AdminCallInfo.fromJson(Map<String, dynamic> j) => AdminCallInfo(
    callerUid: _int(j['caller_uid']),
    calleeUid: _int(j['callee_uid']),
    status: j['status'] as String?,
    createdAt: _date(j['created_at'] ?? j['started_at']),
    answeredAt: _date(j['answered_at']),
    endedAt: _date(j['ended_at']),
  );
}

/// 檢舉佇列的一筆（GET /api/admin/forum/reports）。
class AdminReport {
  final int id;

  /// post／comment／message／call／profile／event。
  final String targetType;
  final int targetId;
  final String reason;

  /// pending／reviewed／dismissed／actioned。
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final int? caseId;
  final int? reporterUid;
  final String? reporterNickname;
  final String? reporterFriendCode;

  /// 貼文標題、留言／私訊內文、活動「標題＋換行＋說明」；通話與個人檔案為 null。
  final String? targetPreview;
  final bool targetDeleted;
  final AdminCallInfo? targetCall;
  final AdminProfileSnapshot? targetProfile;

  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.caseId,
    this.reporterUid,
    this.reporterNickname,
    this.reporterFriendCode,
    this.targetPreview,
    this.targetDeleted = false,
    this.targetCall,
    this.targetProfile,
  });

  factory AdminReport.fromJson(Map<String, dynamic> j) {
    final call = j['target_call'];
    final profile = j['target_profile'];
    return AdminReport(
      id: _int(j['id']) ?? 0,
      targetType: j['target_type'] as String? ?? '',
      targetId: _int(j['target_id']) ?? 0,
      reason: j['reason'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      createdAt: _date(j['created_at']),
      reviewedAt: _date(j['reviewed_at']),
      caseId: _int(j['case_id']),
      reporterUid: _int(j['reporter_uid']),
      // 規格文件寫 reporter_name，實際後端（SCAN-S24 起）只給暱稱與好友碼。
      reporterNickname:
          (j['reporter_nickname'] ?? j['reporter_name']) as String?,
      reporterFriendCode: j['reporter_friend_code'] as String?,
      targetPreview: j['target_preview'] as String?,
      targetDeleted: j['target_deleted'] == true,
      targetCall: call is Map<String, dynamic>
          ? AdminCallInfo.fromJson(call)
          : null,
      targetProfile: profile is Map<String, dynamic>
          ? AdminProfileSnapshot.fromJson(profile)
          : null,
    );
  }
}

/// 目標類型的中文名稱（檢舉與違規區共用）。
String adminTargetTypeLabel(String type) => switch (type) {
  'post' => '貼文',
  'comment' => '留言',
  'message' => '私訊',
  'call' => '通話',
  'profile' => '個人檔案',
  'event' => '活動',
  'mute' => '自動禁言',
  _ => type,
};

// ── 違規區案件（內部管理.md §8.6～§8.7）────────────────────────────

/// 違規案件裡被處置內容的預覽，依 target_type 各有不同形狀。
sealed class AdminCasePreview {
  const AdminCasePreview();

  factory AdminCasePreview.fromJson(String targetType, Object? raw) {
    final j = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return switch (targetType) {
      'post' => PostCasePreview(
        title: j['title'] as String?,
        body: j['body'] as String?,
      ),
      'comment' => CommentCasePreview(
        body: j['body'] as String?,
        postId: _int(j['post_id']),
      ),
      'message' => MessageCasePreview(
        body: j['body'] as String?,
        sentAt: _date(j['sent_at']),
      ),
      'event' => EventCasePreview(
        title: j['title'] as String?,
        description: j['description'] as String?,
        startsAt: _date(j['starts_at']),
      ),
      'mute' => MuteCasePreview(
        scope: j['scope'] as String?,
        muteUntil: _date(j['mute_until']),
        liftedAt: _date(j['lifted_at']),
      ),
      'profile' => ProfileCasePreview(
        before: j['before'] is Map<String, dynamic>
            ? j['before'] as Map<String, dynamic>
            : const {},
        current: j['current'] is Map<String, dynamic>
            ? AdminProfileSnapshot.fromJson(
                j['current'] as Map<String, dynamic>,
              )
            : const AdminProfileSnapshot(),
      ),
      // call，以及日後新增而這版不認得的類型：照通話欄位盡量解析。
      _ => CallCasePreview(AdminCallInfo.fromJson(j)),
    };
  }
}

class PostCasePreview extends AdminCasePreview {
  final String? title;
  final String? body;
  const PostCasePreview({this.title, this.body});
}

class CommentCasePreview extends AdminCasePreview {
  final String? body;
  final int? postId;
  const CommentCasePreview({this.body, this.postId});
}

class MessageCasePreview extends AdminCasePreview {
  final String? body;
  final DateTime? sentAt;
  const MessageCasePreview({this.body, this.sentAt});
}

class CallCasePreview extends AdminCasePreview {
  final AdminCallInfo call;
  const CallCasePreview(this.call);
}

class EventCasePreview extends AdminCasePreview {
  final String? title;
  final String? description;
  final DateTime? startsAt;
  const EventCasePreview({this.title, this.description, this.startsAt});
}

class MuteCasePreview extends AdminCasePreview {
  final String? scope;
  final DateTime? muteUntil;
  final DateTime? liftedAt;
  const MuteCasePreview({this.scope, this.muteUntil, this.liftedAt});
}

/// 個人檔案案件：[before] 是重設前的值（只含被重設的欄位，鍵為後端欄位名），
/// [current] 是目前的公開欄位。
class ProfileCasePreview extends AdminCasePreview {
  final Map<String, dynamic> before;
  final AdminProfileSnapshot current;
  const ProfileCasePreview({required this.before, required this.current});
}

class AdminCase {
  final int id;
  final String targetType;
  final int targetId;
  final int offenderUid;
  final String offenderNickname;

  /// active／locked／…；locked 時才能解鎖帳號。
  final String? offenderStatus;

  /// admin_delete／user_report／auto_reports。
  final String source;
  final int? reportId;
  final String reason;
  final bool contentRemoved;
  final int? openedBy;
  final String? openedByNickname;
  final DateTime? openedAt;

  /// pending／confirmed／overturned。
  final String status;
  final int? reviewedBy;
  final String? reviewedByNickname;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final int? strikeNumber;
  final Map<String, dynamic>? snapshot;
  final AdminCasePreview preview;

  const AdminCase({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.offenderUid,
    this.offenderNickname = '',
    this.offenderStatus,
    required this.source,
    this.reportId,
    required this.reason,
    this.contentRemoved = false,
    this.openedBy,
    this.openedByNickname,
    this.openedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedByNickname,
    this.reviewedAt,
    this.reviewNote,
    this.strikeNumber,
    this.snapshot,
    this.preview = const PostCasePreview(),
  });

  factory AdminCase.fromJson(Map<String, dynamic> j) {
    final type = j['target_type'] as String? ?? '';
    return AdminCase(
      id: _int(j['id']) ?? 0,
      targetType: type,
      targetId: _int(j['target_id']) ?? 0,
      offenderUid: _int(j['offender_uid']) ?? 0,
      offenderNickname: j['offender_nickname'] as String? ?? '',
      offenderStatus: j['offender_status'] as String?,
      source: j['source'] as String? ?? '',
      reportId: _int(j['report_id']),
      reason: j['reason'] as String? ?? '',
      contentRemoved: j['content_removed'] == true,
      openedBy: _int(j['opened_by']),
      openedByNickname: j['opened_by_nickname'] as String?,
      openedAt: _date(j['opened_at']),
      status: j['status'] as String? ?? 'pending',
      reviewedBy: _int(j['reviewed_by']),
      reviewedByNickname: j['reviewed_by_nickname'] as String?,
      reviewedAt: _date(j['reviewed_at']),
      reviewNote: j['review_note'] as String?,
      strikeNumber: _int(j['strike_number']),
      snapshot: j['snapshot'] is Map<String, dynamic>
          ? j['snapshot'] as Map<String, dynamic>
          : null,
      preview: AdminCasePreview.fromJson(type, j['preview']),
    );
  }

  bool get isPending => status == 'pending';

  /// 解鎖帳號後畫面就地更新被處置者狀態。
  AdminCase withOffenderStatus(String status) => AdminCase(
    id: id,
    targetType: targetType,
    targetId: targetId,
    offenderUid: offenderUid,
    offenderNickname: offenderNickname,
    offenderStatus: status,
    source: source,
    reportId: reportId,
    reason: reason,
    contentRemoved: contentRemoved,
    openedBy: openedBy,
    openedByNickname: openedByNickname,
    openedAt: openedAt,
    status: this.status,
    reviewedBy: reviewedBy,
    reviewedByNickname: reviewedByNickname,
    reviewedAt: reviewedAt,
    reviewNote: reviewNote,
    strikeNumber: strikeNumber,
    snapshot: snapshot,
    preview: preview,
  );
}

String adminCaseSourceLabel(String source) => switch (source) {
  'admin_delete' => '管理員刪除',
  'user_report' => '使用者檢舉',
  'auto_reports' => '自動禁言',
  _ => source,
};

String adminCaseStatusLabel(String status) => switch (status) {
  'pending' => '待二審',
  'confirmed' => '已確認違規',
  'overturned' => '已撤銷',
  _ => status,
};

/// 二審確認違規後的處置（review 回應的 `strike`）。
class AdminStrike {
  final int? strikeNumber;
  final bool locked;
  final DateTime? muteUntil;

  /// 鎖帳號時連帶取消的主辦活動數。
  final int cancelledEventCount;

  const AdminStrike({
    this.strikeNumber,
    this.locked = false,
    this.muteUntil,
    this.cancelledEventCount = 0,
  });

  factory AdminStrike.fromJson(Map<String, dynamic> j) {
    final cancelled = j['cancelledEvents'] ?? j['cancelled_events'];
    return AdminStrike(
      strikeNumber: _int(j['strikeNumber'] ?? j['strike_number']),
      locked: j['locked'] == true,
      muteUntil: _date(j['muteUntil'] ?? j['mute_until']),
      cancelledEventCount: cancelled is List ? cancelled.length : 0,
    );
  }
}

/// POST /api/admin/moderation/cases/:id/review 的結果。
class AdminReviewResult {
  final AdminCase reviewedCase;
  final AdminStrike? strike;
  final int? autoLiftedMuteId;

  const AdminReviewResult({
    required this.reviewedCase,
    this.strike,
    this.autoLiftedMuteId,
  });

  factory AdminReviewResult.fromJson(Map<String, dynamic> j) =>
      AdminReviewResult(
        reviewedCase: AdminCase.fromJson(j['case'] as Map<String, dynamic>),
        strike: j['strike'] is Map<String, dynamic>
            ? AdminStrike.fromJson(j['strike'] as Map<String, dynamic>)
            : null,
        autoLiftedMuteId: _int(j['auto_lifted_mute_id']),
      );
}

/// POST /api/admin/forum/reports/:id/resolve 的結果。
class AdminResolveResult {
  /// dismissed／actioned。
  final String status;
  final AdminCase? openedCase;
  final List<int> autoClosedReportIds;
  final int? autoLiftedMuteId;

  const AdminResolveResult({
    required this.status,
    this.openedCase,
    this.autoClosedReportIds = const [],
    this.autoLiftedMuteId,
  });

  factory AdminResolveResult.fromJson(Map<String, dynamic> j) =>
      AdminResolveResult(
        status: j['status'] as String? ?? '',
        openedCase: j['case'] is Map<String, dynamic>
            ? AdminCase.fromJson(j['case'] as Map<String, dynamic>)
            : null,
        autoClosedReportIds: [
          for (final id in (j['auto_closed_report_ids'] as List? ?? const []))
            ?_int(id),
        ],
        autoLiftedMuteId: _int(j['auto_lifted_mute_id']),
      );
}

/// 個人檔案可重設的欄位（後端 `reset_fields`／`fields` 的值與畫面標籤）。
const adminProfileFields = <({String key, String label})>[
  (key: 'video_nickname', label: '暱稱'),
  (key: 'self_intro', label: '自我介紹'),
  (key: 'avatar', label: '頭像'),
];
