// 登入狀態的收口：啟動時還原（restore）與本機完整登出（signOut）。
// 登出：關聊天連線 → 註銷／刪除 FCM token → 清使用者快取 → 清 JWT、登出 Firebase。
// 任一步失敗都不擋後續步驟，否則使用者會卡在已登入狀態且沒有退路。

import 'package:flutter/foundation.dart';

import 'account_lock_controller.dart';
import 'auth_service.dart';
import 'chat_socket_service.dart';
import 'fcm_service.dart';
import 'notification_summary_service.dart';
import 'user_service.dart';

class SessionService {
  /// 啟動時呼叫：本機 JWT 有效回 true。JWT 已過期就完整登出後回 false，
  /// 確保這台手機不再收到舊帳號的推播。
  static Future<bool> restore() async {
    if (await AuthService.isLoggedIn()) return true;
    if (await AuthService.currentToken() == null) return false;
    await signOut(unregisterDevice: false);
    return false;
  }

  /// [unregisterDevice] 為 false 時不打後端註銷、只刪本機 FCM token：JWT 已失效
  /// （強制登出、啟動時過期）、刪除帳號後 token 已被後端撤銷、刪除中帳號的
  /// token 會被狀態閘擋下，這些情況打註銷只會失敗或觸發全域錯誤導頁。
  /// 本機 token 刪掉後，後端留著的舊 token 推播會失敗並自行清除。
  static Future<void> signOut({bool unregisterDevice = true}) async {
    chatController.disconnect();
    if (unregisterDevice) {
      // 需 JWT，故在 signOut 之前。失敗時最壞情況是這台裝置仍留著 token，
      // 後端推播時會因 token 失效自行清除。
      try {
        await FcmService.unregisterDevice();
      } catch (e) {
        debugPrint('SessionService: 註銷裝置 FCM token 失敗（忽略）：$e');
      }
    } else {
      await FcmService.deleteLocalToken();
    }
    UserService.clearCache();
    NotificationSummaryService.clear();
    accountLockController.setLocked(false);
    try {
      await AuthService.signOut();
    } catch (e) {
      debugPrint('SessionService: signOut 失敗（忽略）：$e');
    }
  }
}
