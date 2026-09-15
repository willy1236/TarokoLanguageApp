// App 圖示紅點（badge）。後端推播會帶未讀總數（iOS aps.badge／Android notificationCount），
// 系統自動畫在圖示上；但 iOS 不會自己消，App 回前景時要主動歸零
// （見 Truku_backend 說明文件/前端交接/總覽.md §4.3）。
//
// Android 的數字跟著通知走，通知被清掉時啟動器會自己更新，不需要處理；
// Web／Windows 沒有 App 圖示紅點。

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

class AppBadge {
  static Future<void> clear() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (e) {
      debugPrint('AppBadge.clear 失敗（忽略）：$e');
    }
  }
}
