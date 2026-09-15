// 搜尋輔助：我的最近搜尋、熱門關鍵字、清空歷史
// （見 Truku_backend 說明文件/前端交接/總覽.md §4.3、backend/routes/search.ts）。
// 歷史由後端在四支搜尋端點自動記錄，前端不需上報。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';

/// 對應後端 search_history.module 的值（與四支搜尋端點一一對應）。
enum SearchModule {
  forum('forum'),
  events('events'),
  articles('articles'),
  videos('videos');

  final String value;
  const SearchModule(this.value);
}

class SearchAssistService {
  /// 最近搜尋（後端去重後最新 10 筆，新到舊）。
  static Future<List<String>> history(SearchModule module) async {
    final data = await ApiClient.get(
      ApiConfig.searchHistory,
      query: {'module': module.value},
    );
    return ApiClient.unwrapList(data, 'history')
        .map((e) => (e as Map<String, dynamic>)['q'] as String? ?? '')
        .where((q) => q.isNotEmpty)
        .toList();
  }

  /// 近 30 天熱門關鍵字（跨使用者、至少 3 次才入榜）。
  static Future<List<String>> popular(SearchModule module) async {
    final data = await ApiClient.get(
      ApiConfig.searchPopular,
      query: {'module': module.value},
    );
    return ApiClient.unwrapList(data, 'popular')
        .map((e) => e is Map ? (e['q'] as String? ?? '') : e.toString())
        .where((q) => q.isNotEmpty)
        .toList();
  }

  /// 清空我的所有搜尋歷史（後端不分模組）。
  static Future<void> clearHistory() => ApiClient.delete(ApiConfig.searchHistory);
}
