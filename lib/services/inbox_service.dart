// 站內收件匣：列表與標記已讀。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §1、§2。
//
// 這兩支只驗登入、不擋唯讀，被鎖帳號也能用。標已讀後一律重抓未讀數，
// 各入口的紅點才會跟著變。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/inbox_models.dart';
import '../models/page_info.dart';
import 'notification_summary_service.dart';

class InboxService {
  /// [category] 為 null 取全部分類；[cursor] 原樣帶上一頁的 `page_info.next_cursor`。
  static Future<InboxPage> fetch({String? category, String? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.inbox,
      query: {
        'category': ?category,
        ...PageInfo.query(cursor: cursor),
      },
    );
    return InboxPage.fromJson(data);
  }

  /// 把指定的幾則標為已讀（後端一次上限 100 筆）。
  static Future<void> markRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await ApiClient.post(ApiConfig.inboxRead, {'ids': ids});
    NotificationSummaryService.refresh();
  }

  /// 全部標為已讀；給 [category] 時只清那一類。
  static Future<void> markAllRead({String? category}) async {
    await ApiClient.post(ApiConfig.inboxRead, {
      'all': true,
      'category': ?category,
    });
    NotificationSummaryService.refresh();
  }
}
