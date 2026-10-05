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

/// [SessionService.restore] 的結果。
enum RestoreResult {
  /// 本機有可用的 JWT（原本就有效，或剛續期成功）。
  loggedIn,

  /// 沒有登入，或續期被拒絕、已完整登出。
  loggedOut,

  /// JWT 已過期、續期時連不上伺服器；登入狀態保留，等網路恢復再試。
  offline,
}

class SessionService {
  // 測試接縫：AuthService／FcmService 都是靜態方法，測試以這些欄位換成假實作。
  @visibleForTesting
  static Future<RefreshOutcome> Function() refreshSession =
      AuthService.refreshSession;
  @visibleForTesting
  static Future<void> Function() unregisterDeviceToken =
      FcmService.unregisterDevice;
  @visibleForTesting
  static Future<void> Function() deleteLocalToken = FcmService.deleteLocalToken;
  @visibleForTesting
  static Future<void> Function() clearAuth = AuthService.signOut;

  /// 啟動時呼叫：本機 JWT 有效回 [RestoreResult.loggedIn]。JWT 已過期時先用
  /// 仍登入中的 Firebase 帳號換新 JWT，成功回 loggedIn；被拒絕才完整登出後回
  /// [RestoreResult.loggedOut]，確保這台手機不再收到舊帳號的推播。連不上時
  /// 什麼都不清、回 [RestoreResult.offline]，網路恢復後再呼叫一次即可：
  /// 登出 Firebase 後要重選 Google 帳號，不該因為暫時收訊差就付這個代價。
  /// 只在啟動時續期：使用中 API 回 401 照舊強制登出，後端對已撤銷的 token
  /// 也回 TOKEN_EXPIRED，續期會讓「登出所有裝置」失效。
  static Future<RestoreResult> restore() async {
    if (await AuthService.isLoggedIn()) return RestoreResult.loggedIn;
    if (await AuthService.currentToken() == null) {
      return RestoreResult.loggedOut;
    }
    switch (await refreshSession()) {
      case RefreshOutcome.ok:
        return RestoreResult.loggedIn;
      case RefreshOutcome.offline:
        return RestoreResult.offline;
      case RefreshOutcome.rejected:
        await signOut(unregisterDevice: false);
        return RestoreResult.loggedOut;
    }
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
        await unregisterDeviceToken();
      } catch (e) {
        debugPrint('SessionService: 註銷裝置 FCM token 失敗（忽略）：$e');
      }
    } else {
      await deleteLocalToken();
    }
    UserService.clearCache();
    NotificationSummaryService.clear();
    accountLockController.setLocked(false);
    try {
      await clearAuth();
    } catch (e) {
      debugPrint('SessionService: signOut 失敗（忽略）：$e');
    }
  }
}
