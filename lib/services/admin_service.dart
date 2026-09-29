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
      query: {'status': status, ...PageInfo.query(cursor: cursor)},
    );
    return (
      items: _list(json, 'reports', AdminReport.fromJson),
      pageInfo: PageInfo.fromResponse(json),
    );
  }
}
