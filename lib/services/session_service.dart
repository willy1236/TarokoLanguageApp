// 本機完整登出：註銷 FCM token → 清使用者快取 → 登出 Firebase／清 JWT。
// 任一步失敗都不擋後續步驟，否則使用者會卡在已登入狀態且沒有退路。

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'fcm_service.dart';
import 'user_service.dart';

class SessionService {
  /// [unregisterDevice] 為 false 時略過 FCM 註銷：刪除帳號後 token 已被後端撤銷、
  /// 刪除中帳號的 token 會被狀態閘擋下，這兩種情況打註銷只會觸發全域錯誤導頁
  /// （後端刪除帳號時已一併清掉推播 token）。
  static Future<void> signOut({bool unregisterDevice = true}) async {
    if (unregisterDevice) {
      // 需 JWT，故在 signOut 之前。失敗時最壞情況是這台裝置仍留著 token，
      // 後端推播時會因 token 失效自行清除。
      try {
        await FcmService.unregisterDevice();
      } catch (e) {
        debugPrint('SessionService: 註銷裝置 FCM token 失敗（忽略）：$e');
      }
    }
    UserService.clearCache();
    try {
      await AuthService.signOut();
    } catch (e) {
      debugPrint('SessionService: signOut 失敗（忽略）：$e');
    }
  }
}
