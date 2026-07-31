// FCM 推播：要權限、取得裝置 token、上傳後端、處理前景/點擊通知。
//
// 與後端搭配（Truku_backend backend/routes/events.ts、push.ts）：
//   - 登入後把 token 上傳 POST /api/devices（req 需帶 JWT，故必須登入後才呼叫）
//   - 登出前 DELETE /api/devices 移除
//   - 提醒推播的 data payload：{ type: 'event_reminder', event_id, reminder_id }
//
// 使用方式（之後在 UI/啟動流程接）：
//   main() 啟動時：await FcmService.init();
//   登入成功後：   await FcmService.registerDevice();
//   登出前：       await FcmService.unregisterDevice();
//
// 注意：iOS 需另外設定 APNs 憑證與 GoogleService-Info.plist，本階段先只支援 Android。

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import 'event_service.dart';

/// 背景/App 被系統回收時收到訊息的處理器。必須是頂層函式並標註 vm:entry-point。
/// 通知列的顯示由系統處理，這裡通常不需額外動作。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 需要在背景做事（例如本地記錄）時再補；顯示通知由系統負責。
}

class FcmService {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;
  static String? _lastToken;

  /// 點擊提醒通知時的導頁 callback。由 UI 層設定（用 navigatorKey 導到活動詳情）。
  /// 參數為 payload 裡的 event_id（可能為 null）。
  static void Function(int? eventId)? onReminderTapped;

  /// App 被完全關閉、靠點擊通知冷啟動時拿到的訊息。此時 runApp() 尚未執行，
  /// navigatorKey 還沒掛上 Navigator，不能立即導頁，先暫存；等 SplashScreen
  /// 完成起始路由跳轉後再呼叫 [consumePendingInitialMessage] 處理，
  /// 避免被 splash 的 pushReplacementNamed 蓋掉（見 splash_screen.dart）。
  static RemoteMessage? _pendingInitialMessage;

  /// App 啟動時呼叫一次：註冊背景 handler、要通知權限、掛前景/點擊監聽。
  /// 不在這裡上傳 token —— 上傳需要 JWT，登入成功後再呼叫 [registerDevice]。
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _fm.requestPermission();

    // 前景收到訊息
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    // 背景中點擊通知開啟 App
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    // App 被完全關閉、由點擊通知啟動：先暫存，等 UI 掛好再處理。
    _pendingInitialMessage = await _fm.getInitialMessage();

    // token 會定期更換，換了要重新上傳
    _fm.onTokenRefresh.listen((token) {
      _lastToken = token;
      _uploadIfLoggedIn(token);
    });
  }

  /// 由 SplashScreen 在完成起始路由跳轉（pushReplacementNamed）之後呼叫，
  /// 處理冷啟動時暫存的通知，並清空暫存避免重複觸發。
  static void consumePendingInitialMessage() {
    final message = _pendingInitialMessage;
    if (message == null) return;
    _pendingInitialMessage = null;
    _handleOpened(message);
  }

  /// 登入成功後呼叫：取得 FCM token 並上傳後端。
  static Future<void> registerDevice() async {
    final token = await _fm.getToken();
    if (token == null) return;
    _lastToken = token;
    await _uploadIfLoggedIn(token);
  }

  /// 登出前呼叫：從後端移除本裝置 token，並刪掉本機 token。
  static Future<void> unregisterDevice() async {
    final token = _lastToken ?? await _fm.getToken();
    if (token != null) {
      try {
        await EventService.unregisterDevice(token);
      } catch (_) {
        // 移除失敗不阻斷登出流程
      }
    }
    try {
      await _fm.deleteToken();
    } catch (_) {}
    _lastToken = null;
  }

  static Future<void> _uploadIfLoggedIn(String token) async {
    if (!await AuthService.isLoggedIn()) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await EventService.registerDevice(token, platform);
    } catch (_) {
      // 上傳失敗不影響 App 運作；下次 refresh 或重登會再試
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    // 前景時系統預設不跳通知列。要在 App 內呈現（SnackBar / 本地通知）時，
    // 於 UI 對話補上；這裡先保留 hook。
  }

  static void _handleOpened(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    // 提醒與取消通知都導到活動詳情頁。
    if (type == 'event_reminder' || type == 'event_cancelled') {
      final eventId = int.tryParse(data['event_id']?.toString() ?? '');
      if (eventId == null) {
        debugPrint('FcmService: event_id 缺失或無法解析，忽略導頁：${data['event_id']}');
      }
      onReminderTapped?.call(eventId);
    }
  }
}
