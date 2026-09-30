// 管理員後台的 API 呼叫。規格：Truku_backend 說明文件/API/內部管理.md。
//
// 所有端點都要 role == 'admin'，其他角色回 403 ADMIN_ONLY（由畫面端的
// handleAdminError 統一處理）。錯誤訊息原樣交給畫面顯示，這裡不改寫。
// 列表回 `(items, pageInfo)`：後端多數後台列表目前一次給齊（上限 100 筆），
// 沒有 page_info 時 [PageInfo.fromResponse] 視為沒有下一頁，之後後端補上分頁不必改前端。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/admin_models.dart';
import '../models/millet_transaction.dart';
import '../models/page_info.dart';
import '../shared/utils/birth_date.dart';

typedef AdminPage<T> = ({List<T> items, PageInfo pageInfo});

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

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

  // ── 使用者與角色（內部管理.md §8.9、§8.10）───────────────────────
  //
  // 後台端點只收 uid；手上只有好友碼時一律先經 [lookupUser] 轉換。

  /// 以好友碼查使用者（不分大小寫）。每次查詢後端都會記一筆操作紀錄。
  static Future<AdminUserLookup> lookupUser(String friendCode) async {
    final json = await ApiClient.get(
      ApiConfig.adminUsersLookup,
      query: {'friend_code': friendCode.trim()},
    );
    return AdminUserLookup.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// 目前的管理員與活動發起人，管理員在前。
  static Future<List<AdminRoleUser>> fetchRoleUsers() async {
    final json = await ApiClient.get(ApiConfig.adminUsersRoles);
    return _list(json, 'users', AdminRoleUser.fromJson);
  }

  /// 變更角色，[reason] 必填 1～200 字（長度由畫面先擋）。
  static Future<AdminRoleChange> setRole(
    int uid,
    String role,
    String reason,
  ) async {
    final json = await ApiClient.patch(ApiConfig.adminUserRole(uid), {
      'role': role,
      'reason': reason.trim(),
    });
    return AdminRoleChange.fromJson(json);
  }

  /// 更正出生日期，[reason] 必填 1～500 字。更正後未滿 18 歲的人後端會移出隨機配對佇列。
  static Future<AdminBirthDateResult> updateBirthDate(
    int uid,
    DateTime birthDate,
    String reason,
  ) async {
    final json = await ApiClient.patch(ApiConfig.adminUserBirthDate(uid), {
      'birth_date': formatApiDate(birthDate),
      'reason': reason.trim(),
    });
    return AdminBirthDateResult.fromJson(json);
  }

  /// 更正族群／部落，整組覆寫。[reason] 必填 1～500 字。
  /// 原住民要給 [ethnicGroup] 與屬於該族群的 [tribeId]；非原住民只送身分與理由
  /// （後端會一併清空族群、部落、族語名）。
  static Future<AdminIdentityResult> updateIdentity(
    int uid, {
    required bool isIndigenous,
    String? ethnicGroup,
    int? tribeId,
    required String reason,
  }) async {
    final json = await ApiClient.patch(ApiConfig.adminUserIdentity(uid), {
      'is_indigenous': isIndigenous,
      if (isIndigenous) 'ethnic_group': ethnicGroup,
      if (isIndigenous) 'tribe_id': tribeId,
      'reason': reason.trim(),
    });
    return AdminIdentityResult.fromJson(json);
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

  // ── 小米幣查帳（內部管理.md §4、§5）唯讀，不寫操作紀錄 ─────────────────

  /// 任一使用者的小米幣明細，形狀同使用者自己的明細。
  static Future<MilletTransactionListResult> fetchMilletTransactions(
    int uid, {
    String? cursor,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.adminMilletTransactions,
      query: {
        'uid': '$uid',
        ...PageInfo.query(cursor: cursor),
      },
    );
    return MilletTransactionListResult.fromJson(json);
  }

  /// 帳本加總是否等於目前餘額。
  static Future<AdminMilletReconcile> reconcileMillet(int uid) async {
    final json = await ApiClient.get(
      ApiConfig.adminMilletReconcile,
      query: {'uid': '$uid'},
    );
    return AdminMilletReconcile.fromJson(json);
  }

  // ── 文章（文章模組.md §5）─────────────────────────────────────
  //
  // 後端沒有列出草稿／已下架文章的端點，App 內只找得到已發布的文章。
  // 封面圖只收已在雲端儲存的 HTTPS 網址，沒有上傳。

  /// 建立文章，回傳新文章 id。[publish] 為 true 時一次建立並發布
  /// （`status: published`），不會留下發布失敗的孤兒草稿；false 存為草稿。
  static Future<int> createArticle({
    required String title,
    required String category,
    required String contentMd,
    String? summary,
    String? coverImageUrl,
    String? author,
    int? tribeId,
    required bool publish,
  }) async {
    String? blankToNull(String? v) =>
        v == null || v.trim().isEmpty ? null : v.trim();
    final json = await ApiClient.post(ApiConfig.adminArticles, {
      'title': title.trim(),
      'category': category,
      'content_md': contentMd,
      'summary': ?blankToNull(summary),
      'cover_image_url': ?blankToNull(coverImageUrl),
      'author': ?blankToNull(author),
      'tribe_id': ?tribeId,
      'status': publish ? 'published' : 'draft',
    });
    return _int(json['id']) ?? 0;
  }

  /// 編輯文章：只送有改的欄位（`title`／`summary`／`content_md`／
  /// `cover_image_url`／`category`／`tribe_id`），清空封面或摘要請傳 null 值。
  static Future<void> updateArticle(int id, Map<String, Object?> fields) async {
    await ApiClient.patch(ApiConfig.adminArticle(id), fields);
  }

  /// `draft`／`archived` → `published`（冪等）。
  static Future<void> publishArticle(int id) async {
    await ApiClient.post(ApiConfig.adminArticlePublish(id));
  }

  static Future<void> archiveArticle(int id) async {
    await ApiClient.post(ApiConfig.adminArticleArchive(id));
  }

  // ── 條款（同意條款.md §3）─────────────────────────────────────

  /// 發布新版條款，回傳後端自動遞增後的版本號。發布後所有使用者下次都要重新同意。
  static Future<int> publishTerms(
    String docType,
    String title,
    String contentMd,
  ) async {
    final json = await ApiClient.post(ApiConfig.adminTerms, {
      'doc_type': docType,
      'title': title.trim(),
      'content_md': contentMd.trim(),
    });
    return _int(json['version']) ?? 0;
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
