// 管理員後台的資料模型。
// 規格：Truku_backend 說明文件/API/內部管理.md §4～§8.10、安全防護.md「後台端點」。
//
// 後端的後台回應欄位有過渡期寫法（例如檢舉人暱稱曾叫 reporter_name），
// 解析一律容許缺欄位，缺了寧可顯示空白也不要讓整頁載入失敗。

import '../shared/utils/birth_date.dart';

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

/// 檢舉送出當下存下來的內容（檢舉的 `target_snapshot`、案件的 `report_snapshot`）。
/// 只有貼文、活動、個人檔案有；各類型用到的欄位不同，沒有的為 null，
/// 這版不認得的欄位忽略。
class AdminReportSnapshot {
  // 貼文：title、body；活動：title、description、location、address。
  final String? title;
  final String? body;
  final String? description;
  final String? location;
  final String? address;

  // 個人檔案。
  final String? nickname;
  final String? selfIntro;
  final String? avatarUrl;
  final String? avatarId;

  /// 檢舉當時自訂頭像的複本：限時網址（約 15 分鐘），不存到本機。
  /// 當時用的是預設頭像或 Google 大頭貼時沒有這個欄位。
  final String? avatarEvidenceUrl;

  const AdminReportSnapshot({
    this.title,
    this.body,
    this.description,
    this.location,
    this.address,
    this.nickname,
    this.selfIntro,
    this.avatarUrl,
    this.avatarId,
    this.avatarEvidenceUrl,
  });

  /// 留言、私訊、通話與舊檢舉沒有存證，回 null。
  static AdminReportSnapshot? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return AdminReportSnapshot(
      title: raw['title'] as String?,
      body: raw['body'] as String?,
      description: raw['description'] as String?,
      location: raw['location'] as String?,
      address: raw['address'] as String?,
      nickname: raw['nickname'] as String?,
      selfIntro: raw['self_intro'] as String?,
      avatarUrl: raw['avatar_url'] as String?,
      avatarId: raw['avatar_id'] as String?,
      avatarEvidenceUrl: raw['avatar_evidence_url'] as String?,
    );
  }
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

  /// 檢舉當時的內容；[targetPreview]／[targetProfile] 是目前的。請依這份判斷。
  final AdminReportSnapshot? targetSnapshot;

  /// 檢舉之後內容有沒有被改過（沒有存證時為 false）。
  final bool targetChanged;

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
    this.targetSnapshot,
    this.targetChanged = false,
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
      targetSnapshot: AdminReportSnapshot.tryParse(j['target_snapshot']),
      targetChanged: j['target_changed'] == true,
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

  /// 被處置者的好友碼，對照使用者來反映時給的好友碼用；指定對象仍用 uid。
  final String? offenderFriendCode;

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

  /// 由使用者檢舉開案時，那筆檢舉送出當下的內容；[preview] 是目前的。
  /// 管理員直接下架、自動禁言、舊檢舉與留言／私訊／通話為 null。
  final AdminReportSnapshot? reportSnapshot;

  const AdminCase({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.offenderUid,
    this.offenderNickname = '',
    this.offenderFriendCode,
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
    this.reportSnapshot,
  });

  factory AdminCase.fromJson(Map<String, dynamic> j) {
    final type = j['target_type'] as String? ?? '';
    return AdminCase(
      id: _int(j['id']) ?? 0,
      targetType: type,
      targetId: _int(j['target_id']) ?? 0,
      offenderUid: _int(j['offender_uid']) ?? 0,
      offenderNickname: j['offender_nickname'] as String? ?? '',
      offenderFriendCode: j['offender_friend_code'] as String?,
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
      reportSnapshot: AdminReportSnapshot.tryParse(j['report_snapshot']),
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
    offenderFriendCode: offenderFriendCode,
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
    reportSnapshot: reportSnapshot,
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

// ── 禁言、詞庫、題目回報（安全防護.md「後台端點」、內部管理.md §7）────────

/// 目前有效的禁言（GET /api/admin/mutes）。
class AdminMute {
  final int id;
  final int uid;
  final String nickname;

  /// strike（違規累計）／reports（檢舉滿門檻）／profanity（髒話漸進處置）。
  final String reason;

  /// all（全部）／text（只擋文字類）。
  final String scope;
  final DateTime? muteUntil;
  final DateTime? createdAt;

  const AdminMute({
    required this.id,
    required this.uid,
    this.nickname = '',
    required this.reason,
    required this.scope,
    this.muteUntil,
    this.createdAt,
  });

  factory AdminMute.fromJson(Map<String, dynamic> j) => AdminMute(
    id: _int(j['id']) ?? 0,
    uid: _int(j['uid']) ?? 0,
    nickname: j['nickname'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    scope: j['scope'] as String? ?? '',
    muteUntil: _date(j['mute_until']),
    createdAt: _date(j['created_at']),
  );
}

String adminMuteReasonLabel(String reason) => switch (reason) {
  'strike' => '違規累計',
  'reports' => '檢舉滿門檻',
  'profanity' => '髒話',
  _ => reason,
};

String adminMuteScopeLabel(String scope) => switch (scope) {
  'all' => '全部功能',
  'text' => '文字類',
  _ => scope,
};

class AdminBannedWord {
  final int id;
  final String word;

  const AdminBannedWord({required this.id, required this.word});

  factory AdminBannedWord.fromJson(Map<String, dynamic> j) =>
      AdminBannedWord(id: _int(j['id']) ?? 0, word: j['word'] as String? ?? '');
}

/// 使用者於測驗詳解回報的題目錯誤（GET /api/admin/question-reports）。
class AdminQuestionReport {
  final int id;

  /// quiz／listening 等題型。
  final String questionType;
  final String message;

  /// pending／reviewed／resolved。
  final String status;
  final DateTime? createdAt;
  final int? reporterUid;
  final String? reporterNickname;

  /// 正確答案指向的族語與中文（單字或句子），後台不必再自己 join。
  final String? contentTruku;
  final String? contentZh;

  const AdminQuestionReport({
    required this.id,
    required this.questionType,
    required this.message,
    required this.status,
    this.createdAt,
    this.reporterUid,
    this.reporterNickname,
    this.contentTruku,
    this.contentZh,
  });

  factory AdminQuestionReport.fromJson(Map<String, dynamic> j) =>
      AdminQuestionReport(
        id: _int(j['id']) ?? 0,
        questionType: j['question_type'] as String? ?? '',
        message: j['message'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        createdAt: _date(j['created_at']),
        reporterUid: _int(j['reporter_uid']),
        // 規格文件寫 reporter_name，實際後端（SCAN-S24 起）只給暱稱。
        reporterNickname:
            (j['reporter_nickname'] ?? j['reporter_name']) as String?,
        contentTruku: j['content_truku'] as String?,
        contentZh: j['content_zh'] as String?,
      );
}

String adminQuestionTypeLabel(String type) => switch (type) {
  'quiz' => '單字測驗',
  'listening' => '聽力測驗',
  _ => type,
};

String adminQuestionReportStatusLabel(String status) => switch (status) {
  'pending' => '待處理',
  'reviewed' => '已查看',
  'resolved' => '已解決',
  _ => status,
};

/// 個人檔案可重設的欄位（後端 `reset_fields`／`fields` 的值與畫面標籤）。
const adminProfileFields = <({String key, String label})>[
  (key: 'video_nickname', label: '暱稱'),
  (key: 'self_intro', label: '自我介紹'),
  (key: 'avatar', label: '頭像'),
];

// ── 使用者與角色（內部管理.md §8.9、§8.10）──────────────────────────

/// 帳號角色的中文名稱。
String adminRoleLabel(String role) => switch (role) {
  'user' => '一般使用者',
  'organizer' => '活動發起人',
  'admin' => '管理員',
  _ => role,
};

/// 可指定的角色，依畫面顯示順序。
const adminRoles = ['user', 'organizer', 'admin'];

String adminUserStatusLabel(String status) => switch (status) {
  'active' => '正常',
  'locked' => '已鎖定',
  'pending_deletion' => '刪除中',
  _ => status,
};

/// 以好友碼查到的使用者（GET /api/admin/users/lookup）。
/// 後台唯一的「好友碼 → uid」轉換點；不含真名與 email。
class AdminUserLookup {
  final int uid;
  final String friendCode;
  final String nickname;

  /// active／locked／pending_deletion。
  final String status;
  final String role;
  final DateTime? birthDate;
  final bool isIndigenous;
  final String? ethnicGroup;
  final int? tribeId;
  final String? tribeName;
  final int millet;
  final DateTime? createdAt;

  const AdminUserLookup({
    required this.uid,
    required this.friendCode,
    this.nickname = '',
    this.status = 'active',
    this.role = 'user',
    this.birthDate,
    this.isIndigenous = false,
    this.ethnicGroup,
    this.tribeId,
    this.tribeName,
    this.millet = 0,
    this.createdAt,
  });

  factory AdminUserLookup.fromJson(Map<String, dynamic> j) => AdminUserLookup(
    uid: _int(j['uid']) ?? 0,
    friendCode: j['friend_code'] as String? ?? '',
    nickname: j['nickname'] as String? ?? '',
    status: j['status'] as String? ?? 'active',
    role: j['role'] as String? ?? 'user',
    birthDate: parseApiDate(j['birth_date']),
    isIndigenous: j['is_indigenous'] == true,
    ethnicGroup: j['ethnic_group'] as String?,
    tribeId: _int(j['tribe_id']),
    tribeName: j['tribe_name'] as String?,
    millet: _int(j['millet']) ?? 0,
    createdAt: _date(j['created_at']),
  );
}

/// 角色清單的一筆（GET /api/admin/users/roles，只列管理員與活動發起人）。
class AdminRoleUser {
  final int uid;
  final String nickname;
  final String friendCode;
  final String role;

  const AdminRoleUser({
    required this.uid,
    this.nickname = '',
    this.friendCode = '',
    required this.role,
  });

  factory AdminRoleUser.fromJson(Map<String, dynamic> j) => AdminRoleUser(
    uid: _int(j['uid']) ?? 0,
    nickname: j['nickname'] as String? ?? '',
    friendCode: j['friend_code'] as String? ?? '',
    role: j['role'] as String? ?? 'user',
  );
}

/// PATCH /api/admin/users/:uid/role 的結果。[changed] 為 false 代表角色本來就是這個。
class AdminRoleChange {
  final String role;
  final String? previousRole;
  final bool changed;

  const AdminRoleChange({
    required this.role,
    this.previousRole,
    this.changed = true,
  });

  factory AdminRoleChange.fromJson(Map<String, dynamic> j) => AdminRoleChange(
    role: j['role'] as String? ?? '',
    previousRole: j['previous_role'] as String?,
    changed: j['changed'] != false,
  );
}

// ── 小米幣查帳（內部管理.md §4、§5）─────────────────────────────

/// GET /api/admin/millet/reconcile：帳本加總是否等於目前餘額。
class AdminMilletReconcile {
  final int ledgerSum;
  final int userMillet;
  final bool ok;

  const AdminMilletReconcile({
    required this.ledgerSum,
    required this.userMillet,
    required this.ok,
  });

  factory AdminMilletReconcile.fromJson(Map<String, dynamic> j) =>
      AdminMilletReconcile(
        ledgerSum: _int(j['ledger_sum']) ?? 0,
        userMillet: _int(j['user_millet']) ?? 0,
        ok: j['ok'] == true,
      );
}

// ── 出生日期更正（內部管理.md §8.3a）──────────────────────────────

/// PATCH /api/admin/users/:uid/birth-date 的結果。[adult] 為更正後是否滿 18 歲。
class AdminBirthDateResult {
  final DateTime? birthDate;
  final bool adult;

  const AdminBirthDateResult({this.birthDate, required this.adult});

  factory AdminBirthDateResult.fromJson(Map<String, dynamic> j) =>
      AdminBirthDateResult(
        birthDate: parseApiDate(j['birth_date']),
        adult: j['adult'] == true,
      );
}
