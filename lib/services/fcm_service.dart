// FCM 推播：要權限、取得裝置 token、上傳後端、處理前景/背景/點擊通知。
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

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
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
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static String? _lastToken;

  static const String _reminderChannelId = 'event_reminder_channel';
  static const AndroidNotificationDetails _reminderAndroidDetails =
      AndroidNotificationDetails(
    _reminderChannelId,
    '活動提醒',
    channelDescription: '活動提醒與取消通知',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// 點擊提醒通知時的導頁 callback。由 UI 層設定（用 navigatorKey 導到活動詳情）。
  /// 參數為 payload 裡的 event_id（可能為 null）。
  static void Function(int? eventId)? onReminderTapped;

  /// 前景收到「目前正開著的活動」的新提醒推播時觸發，讓該頁即時刷新提醒紀錄。
  /// 由 EventDetailScreen 在 initState/dispose 掛上/清空。
  static void Function(int? eventId)? onReminderReceivedForOpenScreen;

  /// 點擊論壇回覆通知時的導頁 callback。由 UI 層設定（用 navigatorKey 導到貼文詳情）。
  static void Function(int postId)? onForumReplyTapped;

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
    await _initLocalNotifications();

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

  /// 初始化系統通知列（Android channel + 點擊回呼）。iOS 走最小設定，
  /// 本階段推播只支援 Android（見檔案頂部註解）。
  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('forum:')) {
          final postId = int.tryParse(payload.substring('forum:'.length));
          if (postId != null) onForumReplyTapped?.call(postId);
          return;
        }
        onReminderTapped?.call(int.tryParse(payload));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _reminderChannelId,
      '活動提醒',
      description: '活動提醒與取消通知',
      importance: Importance.high,
    ));
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

  /// 解析提醒/取消通知的 payload，非提醒相關類型回傳 null。
  static (String type, int? eventId)? _parseReminderPayload(
      Map<String, dynamic> data) {
    final type = data['type'];
    if (type != 'event_reminder' && type != 'event_cancelled') return null;
    final eventId = int.tryParse(data['event_id']?.toString() ?? '');
    if (eventId == null) {
      debugPrint('FcmService: event_id 缺失或無法解析，忽略：${data['event_id']}');
    }
    return (type as String, eventId);
  }

  /// 解析論壇回覆通知的 payload，非論壇類型回傳 null。
  /// 後端送出的 data：{ type: 'reply_post' | 'reply_comment', post_id, comment_id }
  static int? _parseForumPayload(Map<String, dynamic> data) {
    final type = data['type'];
    if (type != 'reply_post' && type != 'reply_comment') return null;
    final postId = int.tryParse(data['post_id']?.toString() ?? '');
    if (postId == null) {
      debugPrint('FcmService: post_id 缺失或無法解析，忽略：${data['post_id']}');
    }
    return postId;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final forumPostId = _parseForumPayload(message.data);
    if (forumPostId != null) {
      final title = message.notification?.title ?? '有人回覆你';
      final body = message.notification?.body ?? '';
      unawaited(_localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(android: _reminderAndroidDetails),
        // 事件通知的 payload 是純數字的 event_id，論壇加前綴區分兩者。
        payload: 'forum:$forumPostId',
      ));
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(body.isNotEmpty ? body : title),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => onForumReplyTapped?.call(forumPostId),
          ),
        ));
      return;
    }

    final parsed = _parseReminderPayload(message.data);
    if (parsed == null) return;
    final (_, eventId) = parsed;

    final title = message.notification?.title ?? '活動提醒';
    final body = message.notification?.body ?? '';

    unawaited(_localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(android: _reminderAndroidDetails),
      payload: eventId?.toString(),
    ));

    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(body.isNotEmpty ? body : title),
        action: eventId == null
            ? null
            : SnackBarAction(label: '查看', onPressed: () => onReminderTapped?.call(eventId)),
      ));

    onReminderReceivedForOpenScreen?.call(eventId);
  }

  static void _handleOpened(RemoteMessage message) {
    final forumPostId = _parseForumPayload(message.data);
    if (forumPostId != null) {
      onForumReplyTapped?.call(forumPostId);
      return;
    }
    final parsed = _parseReminderPayload(message.data);
    if (parsed == null) return;
    final (_, eventId) = parsed;
    onReminderTapped?.call(eventId);
  }
}
