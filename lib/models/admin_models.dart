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
