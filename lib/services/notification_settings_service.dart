// 推播設定：目前只有「你的部落有新活動」一項可關，其他推播後端不提供關閉。
// 規格：Truku_backend 說明文件/API/00_核心與認證.md §2.4d

import '../core/constants/api.dart';
import '../core/network/api_client.dart';

class NotificationSettingsService {
  /// 是否接收部落新活動推播。後端預設開啟，欄位缺少時同樣視為開啟。
  static Future<bool> fetchTribeEvents() async {
    final data = await ApiClient.get(ApiConfig.meNotificationSettings);
    return _tribeEvents(data);
  }

  /// 回傳後端確認後的值。
  static Future<bool> setTribeEvents(bool enabled) async {
    final data = await ApiClient.patch(ApiConfig.meNotificationSettings, {
      'tribe_events': enabled,
    });
    return _tribeEvents(data);
  }

  static bool _tribeEvents(Map<String, dynamic> data) =>
      data['tribe_events'] != false;
}
