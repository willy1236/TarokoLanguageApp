// 管理員後台的 API 呼叫。規格：Truku_backend 說明文件/API/內部管理.md。
//
// 所有端點都要 role == 'admin'，其他角色回 403 ADMIN_ONLY（由畫面端的
// handleAdminError 統一處理）。錯誤訊息原樣交給畫面顯示，這裡不改寫。
// 列表回 `(items, pageInfo)`：後端多數後台列表目前一次給齊（上限 100 筆），
// 沒有 page_info 時 [PageInfo.fromResponse] 視為沒有下一頁，之後後端補上分頁不必改前端。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/admin_models.dart';
import '../models/page_info.dart';

typedef AdminPage<T> = ({List<T> items, PageInfo pageInfo});

class AdminService {
  static List<T> _list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) => [
    for (final e in ApiClient.unwrapList(json, key))
      parse(e as Map<String, dynamic>),
  ];

  // ── 檢舉佇列（內部管理.md §8.1）──────────────────────────────

  static Future<AdminPage<AdminReport>> fetchReports({
    String status = 'pending',
    String? cursor,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.adminForumReports,
      query: {
        'status': status,
        ...PageInfo.query(cursor: cursor),
      },
    );
    return (
      items: _list(json, 'reports', AdminReport.fromJson),
      pageInfo: PageInfo.fromResponse(json),
    );
  }

  /// 檢舉一審。[action] 為 `dismiss`（駁回）或 `action`（判定成立）；
  /// 個人檔案檢舉判定成立時可帶 [resetFields]（不帶＝後端預設三項全部）。
  static Future<AdminResolveResult> resolveReport(
    int id,
    String action, {
    List<String>? resetFields,
  }) async {
    final json = await ApiClient.post(ApiConfig.adminForumReportResolve(id), {
      'action': action,
      'reset_fields': ?resetFields,
    });
    return AdminResolveResult.fromJson(json);
  }

  // ── 違規區（內部管理.md §8.6～§8.7）──────────────────────────

  static Future<AdminPage<AdminCase>> fetchCases({
    String status = 'pending',
    String? cursor,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.adminModerationCases,
      query: {
        'status': status,
        ...PageInfo.query(cursor: cursor),
      },
    );
    return (
      items: _list(json, 'cases', AdminCase.fromJson),
      pageInfo: PageInfo.fromResponse(json),
    );
  }

  // ── 直接處置（內部管理.md §8.3、§8.5、§8.5.1）──────────────────────
  //
  // 下架與重設都不當下記違規：內容隱藏並開案進違規區，等另一位管理員二審。
  // 理由必填（去空白後 1～500 字），這裡只去空白，長度由畫面先擋。

  static Future<AdminResolveResult> _removal(String path, String reason) async {
    final json = await ApiClient.post(path, {'reason': reason.trim()});
    return AdminResolveResult.fromJson(json);
  }

  static Future<AdminResolveResult> removePost(int id, String reason) =>
      _removal(ApiConfig.adminForumPostRemove(id), reason);

  static Future<AdminResolveResult> removeComment(int id, String reason) =>
      _removal(ApiConfig.adminForumCommentRemove(id), reason);

  static Future<AdminResolveResult> removeEvent(int id, String reason) =>
      _removal(ApiConfig.adminEventRemove(id), reason);

  /// 重設他人個人檔案。[fields] 為 [adminProfileFields] 的鍵；空集合＝後端預設三項全部。
  static Future<AdminResolveResult> resetProfile(
    int uid,
    String reason, {
    Set<String> fields = const {},
  }) async {
    final json = await ApiClient.post(ApiConfig.adminUserProfileReset(uid), {
      'reason': reason.trim(),
      if (fields.isNotEmpty) 'fields': fields.toList(),
    });
    return AdminResolveResult.fromJson(json);
  }

  /// 置頂／取消置頂論壇貼文，回傳更新後的 `is_pinned`。
  static Future<bool> pinPost(int id, {required bool pinned}) async {
    final json = await ApiClient.post(ApiConfig.adminForumPostPin(id), {
      'pinned': pinned,
    });
    return json['is_pinned'] == true;
  }

  /// 解鎖被鎖的帳號（誤判救援），[note] 選填。
  static Future<void> unlockUser(int uid, {String? note}) async {
    final trimmed = note?.trim();
    await ApiClient.post(ApiConfig.adminUserUnlock(uid), {
      if (trimmed != null && trimmed.isNotEmpty) 'admin_note': trimmed,
    });
  }

  // ── 禁言（安全防護.md「後台端點」）────────────────────────────

  /// 目前有效（未翻案、未到期）的禁言。
  static Future<List<AdminMute>> fetchMutes() async {
    final json = await ApiClient.get(ApiConfig.adminMutes);
    return _list(json, 'mutes', AdminMute.fromJson);
  }

  /// 提前解除禁言；禁言尚未到期時後端會推播通知當事人。
  static Future<void> liftMute(int id) async {
    await ApiClient.post(ApiConfig.adminMuteLift(id));
  }

  // ── 髒話詞庫 ──────────────────────────────────────────────────

  static Future<List<AdminBannedWord>> fetchBannedWords() async {
    final json = await ApiClient.get(ApiConfig.adminBannedWords);
    return _list(json, 'words', AdminBannedWord.fromJson);
  }

  /// 新增一個詞（後端轉小寫、正規化）。回傳 `created`：false 代表詞庫已有，沒有變動。
  static Future<bool> addBannedWord(String word) async {
    final json = await ApiClient.post(ApiConfig.adminBannedWords, {
      'word': word.trim(),
    });
    return json['created'] != false;
  }

  static Future<void> deleteBannedWord(int id) async {
    await ApiClient.delete(ApiConfig.adminBannedWord(id));
  }

  // ── 題目錯誤回報（內部管理.md §7）──────────────────────────────

  /// [status] 為空字串或 null 代表全部；後端排序待處理優先、其次新到舊。
  static Future<AdminPage<AdminQuestionReport>> fetchQuestionReports({
    String? status,
    String? cursor,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.adminQuestionReports,
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        ...PageInfo.query(cursor: cursor),
      },
    );
    return (
      items: _list(json, 'reports', AdminQuestionReport.fromJson),
      pageInfo: PageInfo.fromResponse(json),
    );
  }

  /// 標記處理進度：`pending`／`reviewed`／`resolved`。
  static Future<void> updateQuestionReport(int id, String status) async {
    await ApiClient.patch(ApiConfig.adminQuestionReport(id), {
      'status': status,
    });
  }

  /// 二次審核。[decision] 為 `confirm`（確認違規）或 `overturn`（撤銷）；
  /// [note] 選填、500 字內。須由開案以外的另一位管理員操作。
  static Future<AdminReviewResult> reviewCase(
    int id,
    String decision, {
    String? note,
  }) async {
    final trimmed = note?.trim();
    final json = await ApiClient.post(ApiConfig.adminModerationCaseReview(id), {
      'decision': decision,
      if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
    });
    return AdminReviewResult.fromJson(json);
  }
}
