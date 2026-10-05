// FCM 推播：要權限、取得裝置 token、上傳後端、處理前景/背景/點擊通知。
//
// 與後端搭配（Truku_backend backend/routes/events.ts、push.ts）：
//   - 登入後把 token 上傳 POST /api/devices（req 需帶 JWT，故必須登入後才呼叫）
//   - 登出前 DELETE /api/devices 移除
//   - 提醒推播的 data payload：{ type: 'event_reminder', event_id, reminder_id }
//   - 活動被刪除：{ type: 'event_deleted', event_id }，說明文字在 notification
//     的 title／body（「您參加的{活動名稱}已被發起人刪除」）；活動已不存在，
//     點擊不導頁，只跳提示（見 onEventDeletedTapped）。
//   - 視訊配對推播的 data payload（issue #10，見 backend/routes/video.ts）：
//     { type: 'video_matched', session_id, channel }
//     { type: 'video_session_ended', session_id }
//     注意：video_matched payload 只有 session_id/channel，沒有
//     peer_friend_code/expires_at，不足以組出完整 VideoSession —— 收到後一律當「觸發
//     訊號」，由畫面端另外呼叫 VideoService.fetchCurrentSession() 取得權威資料，
//     不要直接拿 payload 欄位組物件（避免輪詢與 FCM 兩條路徑組出不一致的結果）。
//   - 站內收件匣（見 Truku_backend 說明文件/API/收件匣與申訴.md）：論壇回覆、審核
//     推播多帶 inbox_id，點開時一併標已讀；審核推播帶 case_id 時開處置詳情頁；
//     官方公告 { type: 'announcement', announcement_id } 開收件匣的公告分頁。
//     收件匣類推播一到就重抓未讀數。
//   - 通話事件（video_matched、video_session_ended、friend_call_*）同一則也會經
//     即時連線送出（見 Truku_backend API/即時連線.md「通話事件」）。前景推播、點通知、
//     即時連線三個來源走同一個入口 _handleCallEvent，以 type＋call_id／session_id
//     去重，先到的處理、後到的略過。
//
// 使用方式（之後在 UI/啟動流程接）：
//   main() 啟動時：await FcmService.init();
//   登入成功後：   await FcmService.registerDevice();
//   登出前：       await FcmService.unregisterDevice();
//
// 注意：iOS 需另外設定 APNs 憑證與 GoogleService-Info.plist，本階段先只支援 Android。
// Web/桌面版不支援推播（見 PlatformFeatures.supportsPush），三個入口都直接略過。

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/platform/platform_features.dart';
import '../main.dart';
import '../models/friend_model.dart';
import 'account_lock_controller.dart';
import 'auth_service.dart';
import 'directed_call_service.dart';
import 'event_service.dart';
import 'inbox_service.dart';
import 'notification_summary_service.dart';
import 'user_service.dart';

/// 活動被發起人刪除的推播內容。[title]／[body] 是後端寫好的通知文字，缺少時為預設值。
typedef EventDeletedNotice = ({int? eventId, String title, String body});

/// 通話事件從哪裡來：決定沒有畫面接手時要不要彈通知、點通知時改走冷啟動導頁。
enum _CallEventSource { foregroundPush, openedPush, socket }

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

  /// 點擊「活動已被刪除」通知（背景、冷啟動、前景本機通知）。不導頁，由 UI 層
  /// （main.dart）跳提示，參數是要顯示的說明文字。
  static void Function(String message)? onEventDeletedTapped;

  static const String _eventDeletedPayloadPrefix = 'event_deleted:';
  static const String _eventDeletedFallbackMessage = '您參加的活動已被發起人刪除';

  static final List<void Function(int? eventId)> _eventDeletedListeners = [];

  /// 前景收到活動被刪除的推播時通知開著的畫面（我參加的活動、該活動詳情頁）。
  /// 多個畫面可同時登記，各自在 dispose 時 [removeEventDeletedListener]。
  static void addEventDeletedListener(void Function(int? eventId) listener) {
    _eventDeletedListeners.add(listener);
  }

  static void removeEventDeletedListener(void Function(int? eventId) listener) {
    _eventDeletedListeners.remove(listener);
  }

  @visibleForTesting
  static void dispatchEventDeleted(int? eventId) {
    for (final listener in List.of(_eventDeletedListeners)) {
      listener(eventId);
    }
  }

  /// 冷啟動／背景點擊通知時收到 video_matched。全域註冊一次（main.dart），
  /// 用 navigatorKey 直接導頁到通話等待/通話畫面。
  static void Function(int? sessionId, String? channel)?
  onVideoMatchedColdStart;

  /// 前景收到 video_matched 時觸發，只在配對等待畫面開著時有意義，由
  /// VideoWaitingScreen 在 initState/dispose 掛上/清空——收到後應立即重新查詢
  /// GET /api/video/session/current 取得權威資料，不要直接用 payload 欄位。
  static void Function(int? sessionId, String? channel)?
  onVideoMatchedForeground;

  /// 收到 video_session_ended（前景/背景點擊/冷啟動皆可能觸發）。由
  /// VideoCallScreen 在 initState/dispose 掛上/清空；若收到時不在通話畫面可
  /// 忽略或僅記錄 log。
  static void Function(int? sessionId)? onVideoSessionEnded;

  /// 點擊論壇回覆通知時的導頁 callback。由 UI 層設定（用 navigatorKey 導到貼文詳情）。
  /// [commentId] 是那則回覆，貼文頁開啟後捲過去；舊推播沒帶時為 null。
  static void Function(int postId, int? commentId)? onForumReplyTapped;

  /// 點擊帶 case_id 的審核通知：由 UI 層設定，開處置詳情頁。
  static void Function(int caseId)? onModerationCaseTapped;

  /// 點擊官方公告通知：由 UI 層設定，開收件匣的 [category] 分頁。
  static void Function(String category)? onInboxTapped;

  /// 會進站內收件匣的推播類型：收到就重抓未讀數，紅點才跟得上。
  static const _inboxPushTypes = {
    'reply_post',
    'reply_comment',
    'event_reminder',
    'event_cancelled',
    'event_deleted',
    'tribe_event',
    'moderation',
    'account_role',
    'announcement',
  };

  static const String _announcementPayload = 'inbox:announcement';

  /// 由 UI 層注入：前景收到論壇回覆推播時先交給該貼文開著的詳情頁，回傳 true
  /// 代表畫面已接手（改在頁內提示），就不彈通知列／SnackBar，避免蓋住留言輸入列。
  /// [type] 是 'reply_post' 或 'reply_comment'。
  static bool Function(int postId, String type)? onForumReplyWhileOpen;

  /// 收到好友定向來電推播時觸發（前景收到、或背景點擊通知開啟時皆會呼叫）。
  /// 由 UI 層設定，導向 IncomingCallScreen。響鈴逾時（60 秒）由後端控管，
  /// 這裡不做額外過期判斷；若使用者開啟時來電已結束，畫面內操作會收到
  /// CALL_NOT_RINGING 並顯示錯誤。
  static void Function(IncomingCall call)? onFriendCallIncoming;

  /// 前景收到 friend_call_cancelled（撥出方在接通前取消）時觸發。由
  /// IncomingCallScreen 在 initState/dispose 掛上/清空——收到後應重新查詢
  /// 來電狀態，不要直接用 payload 判斷。
  static void Function(int callId)? onFriendCallCancelled;

  /// 撥出中收到 friend_call_accepted／friend_call_declined。由
  /// DirectedCallWaitingScreen 在 initState/dispose 掛上/清空——收到後立即查詢
  /// 來電狀態，不直接用 payload 導頁。
  static void Function(int callId)? onFriendCallAccepted;
  static void Function(int callId)? onFriendCallDeclined;

  /// 收到 friend_call_ended（好友通話中對方掛斷或封鎖，前景或點擊通知皆會觸發）。
  /// 由 VideoCallScreen 在好友通話時於 initState/dispose 掛上/清空；沒有訂閱者
  /// 代表使用者不在通話畫面，直接忽略。
  static void Function(int callId)? onFriendCallEnded;

  /// 點擊好友相關通知（私訊、好友邀請、接受邀請、羈絆展示）。由 UI 層設定導頁；
  /// [friendCode] 是對方的好友碼。
  static void Function(String type, String friendCode)? onFriendPushTapped;

  static const _friendPushTypes = {
    'friend_message',
    'friend_request',
    'friend_accepted',
    'friend_bond_showcase_requested',
    'friend_bond_showcase_confirmed',
  };

  /// App 被完全關閉、靠點擊通知冷啟動時拿到的訊息。此時 runApp() 尚未執行，
  /// navigatorKey 還沒掛上 Navigator，不能立即導頁，先暫存；等 SplashScreen
  /// 完成起始路由跳轉後再呼叫 [consumePendingInitialMessage] 處理，
  /// 避免被 splash 的 pushReplacementNamed 蓋掉（見 splash_screen.dart）。
  static RemoteMessage? _pendingInitialMessage;

  /// App 啟動時呼叫一次：註冊背景 handler、掛前景/點擊監聽。通知權限不在這裡要，
  /// 等使用者同意條款、進到首頁後才由 [requestPermission] 詢問。
  /// 不在這裡上傳 token —— 上傳需要 JWT，登入成功後再呼叫 [registerDevice]。
  static Future<void> init() async {
    if (!PlatformFeatures.supportsPush) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

  /// 詢問通知權限。系統只會在尚未決定時跳窗，之後重複呼叫不會再打擾使用者。
  static Future<void> requestPermission() async {
    if (!PlatformFeatures.supportsPush) return;
    await _fm.requestPermission();
  }

  /// 初始化系統通知列（Android channel + 點擊回呼）。iOS 走最小設定，
  /// 本階段推播只支援 Android（見檔案頂部註解）。
  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('video:')) {
          onVideoMatchedColdStart?.call(
            int.tryParse(payload.substring('video:'.length)),
            null,
          );
          return;
        }
        if (payload.startsWith(_forumPayloadPrefix)) {
          final forum = parseForumNotificationPayload(payload);
          if (forum != null) {
            _openForumReply(
              forum.postId,
              forum.inboxId,
              commentId: forum.commentId,
            );
          }
          return;
        }
        if (payload == _announcementPayload) {
          onInboxTapped?.call('announcement');
          return;
        }
        if (payload.startsWith(_eventDeletedPayloadPrefix)) {
          final text = payload.substring(_eventDeletedPayloadPrefix.length);
          onEventDeletedTapped?.call(
            text.isNotEmpty ? text : _eventDeletedFallbackMessage,
          );
          return;
        }
        onReminderTapped?.call(int.tryParse(payload));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            '活動提醒',
            description: '活動提醒與取消通知',
            importance: Importance.high,
          ),
        );
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
    if (!PlatformFeatures.supportsPush) return;
    final token = await _fm.getToken();
    if (token == null) return;
    _lastToken = token;
    await _uploadIfLoggedIn(token);
  }

  /// 登出前呼叫：從後端移除本裝置 token，並刪掉本機 token。
  static Future<void> unregisterDevice() async {
    if (!PlatformFeatures.supportsPush) return;
    // 取 token 或向後端註銷失敗都不阻斷登出流程，本機 token 照樣刪除。
    try {
      final token = _lastToken ?? await _fm.getToken();
      if (token != null) await EventService.unregisterDevice(token);
    } catch (e) {
      debugPrint('FcmService: 註銷裝置失敗（忽略）：$e');
    }
    await deleteLocalToken();
  }

  /// 只刪本機 FCM token，不通知後端。JWT 已失效無法註銷時用：後端留著的
  /// 舊 token 推播會失敗並自行清除，這台手機不會再收到舊帳號的推播。
  static Future<void> deleteLocalToken() async {
    if (!PlatformFeatures.supportsPush) return;
    _lastToken = null;
    try {
      await _fm.deleteToken();
    } catch (e) {
      debugPrint('FcmService: 刪除本機 token 失敗（忽略）：$e');
    }
  }

  static Future<void> _uploadIfLoggedIn(String token) async {
    if (!await AuthService.isLoggedIn()) return;
    final platform = PlatformFeatures.devicePlatform;
    try {
      await EventService.registerDevice(token, platform);
    } catch (_) {
      // 上傳失敗不影響 App 運作；下次 refresh 或重登會再試
    }
  }

  /// 解析提醒/取消通知的 payload，非提醒相關類型回傳 null。
  static (String type, int? eventId)? _parseReminderPayload(
    Map<String, dynamic> data,
  ) {
    final type = data['type'];
    if (type != 'event_reminder' && type != 'event_cancelled') return null;
    final eventId = int.tryParse(data['event_id']?.toString() ?? '');
    if (eventId == null) {
      debugPrint('FcmService: event_id 缺失或無法解析，忽略：${data['event_id']}');
    }
    return (type as String, eventId);
  }

  /// 解析活動被刪除通知，非此類型回傳 null。後端送出的 data：
  /// { type: 'event_deleted', event_id }，說明文字在 notification 的 title／body。
  @visibleForTesting
  static EventDeletedNotice? parseEventDeleted(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    if (data['type'] != 'event_deleted') return null;
    return (
      eventId: int.tryParse(data['event_id']?.toString() ?? ''),
      title: title ?? '活動已刪除',
      body: body ?? '',
    );
  }

  static String _eventDeletedText(EventDeletedNotice notice) =>
      notice.body.isNotEmpty ? notice.body : _eventDeletedFallbackMessage;

  /// 解析論壇回覆通知的 payload，非論壇類型回傳 null。
  /// 後端送出的 data：{ type: 'reply_post' | 'reply_comment', post_id, comment_id }；
  /// 舊推播可能沒有 comment_id，此時 commentId 為 null。
  @visibleForTesting
  static ({int postId, String type, int? commentId})? parseForumPayload(
    Map<String, dynamic> data,
  ) {
    final type = data['type'];
    if (type != 'reply_post' && type != 'reply_comment') return null;
    final postId = int.tryParse(data['post_id']?.toString() ?? '');
    if (postId == null) {
      debugPrint('FcmService: post_id 缺失或無法解析，忽略：${data['post_id']}');
      return null;
    }
    return (
      postId: postId,
      type: type as String,
      commentId: int.tryParse(data['comment_id']?.toString() ?? ''),
    );
  }

  /// 事件通知的 payload 是純數字的 event_id，論壇加前綴區分兩者。
  static const _forumPayloadPrefix = 'forum:';

  /// 前景論壇回覆本機通知的 payload：`forum:<post_id>:<inbox_id|空>:<comment_id|空>`。
  @visibleForTesting
  static String forumNotificationPayload(
    int postId, {
    int? inboxId,
    int? commentId,
  }) => '$_forumPayloadPrefix$postId:${inboxId ?? ''}:${commentId ?? ''}';

  /// 解析 [forumNotificationPayload]；也認舊版的 `forum:<post_id>` 與
  /// `forum:<post_id>:<inbox_id>`（更新前彈出、還留在通知列的通知）。
  /// 不是論壇 payload 或 post_id 無法解析時回傳 null。
  @visibleForTesting
  static ({int postId, int? inboxId, int? commentId})?
  parseForumNotificationPayload(String payload) {
    if (!payload.startsWith(_forumPayloadPrefix)) return null;
    final parts = payload.substring(_forumPayloadPrefix.length).split(':');
    final postId = int.tryParse(parts.first);
    if (postId == null) return null;
    int? at(int i) => parts.length > i ? int.tryParse(parts[i]) : null;
    return (postId: postId, inboxId: at(1), commentId: at(2));
  }

  /// 推播對應的收件匣那一則（論壇回覆、審核類才有），沒有回傳 null。
  @visibleForTesting
  static int? parseInboxId(Map<String, dynamic> data) =>
      int.tryParse(data['inbox_id']?.toString() ?? '');

  /// 審核推播對應的違規案件，沒有（例如解除禁言）回傳 null。
  @visibleForTesting
  static int? parseModerationCaseId(Map<String, dynamic> data) =>
      data['type'] == 'moderation'
      ? int.tryParse(data['case_id']?.toString() ?? '')
      : null;

  /// 點了推播就等於看過收件匣那一則。失敗不影響導頁，下次進收件匣再對齊。
  static void _markInboxRead(int? inboxId) {
    if (inboxId == null) return;
    unawaited(
      InboxService.markRead([inboxId]).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('FcmService: 標記收件匣已讀失敗：$e'),
      ),
    );
  }

  static void _openForumReply(int postId, int? inboxId, {int? commentId}) {
    _markInboxRead(inboxId);
    onForumReplyTapped?.call(postId, commentId);
  }

  static void _openModerationCase(int caseId, int? inboxId) {
    _markInboxRead(inboxId);
    onModerationCaseTapped?.call(caseId);
  }

  /// 解析好友相關通知，非此類型回傳 null。私訊與邀請的對方在 from_friend_code，
  /// 邀請被接受與羈絆展示在 friend_code；缺少時 friendCode 為 null。
  @visibleForTesting
  static ({String type, String? friendCode})? parseFriendPush(
    Map<String, dynamic> data,
  ) {
    final type = data['type'];
    if (!_friendPushTypes.contains(type)) return null;
    final code = data['from_friend_code'] ?? data['friend_code'];
    return (
      type: type as String,
      friendCode: code is String && code.isNotEmpty ? code : null,
    );
  }

  /// 用 call_id 查目前來電中吻合的那一通，取得暱稱/頭像等展示欄位。
  /// 找不到（已被取消/接聽/逾時）時回傳 null，呼叫端應忽略。
  static Future<IncomingCall?> _fetchIncomingCall(int callId) async {
    try {
      final calls = await DirectedCallService.getIncomingCalls();
      for (final call in calls) {
        if (call.callId == callId) return call;
      }
    } catch (e) {
      debugPrint('FcmService: 查詢來電詳情失敗：$e');
    }
    return null;
  }

  static const _callEventTypes = {
    'video_matched',
    'video_session_ended',
    'friend_call_incoming',
    'friend_call_accepted',
    'friend_call_declined',
    'friend_call_cancelled',
    'friend_call_ended',
  };

  /// 最近處理過的通話事件（type:id），只留最後 [_maxHandledCallEvents] 筆。
  static final Set<String> _handledCallEvents = <String>{};
  static const _maxHandledCallEvents = 50;

  /// 正在查來電資料的 call_id。查詢期間同一通的其他來源先略過。
  static final Set<int> _incomingInFlight = <int>{};

  /// 查詢期間又有來源送來同一通：這次查不到就再查一次，不讓後到的來源白白被擋掉。
  static final Set<int> _incomingRetry = <int>{};

  @visibleForTesting
  static void resetHandledCallEvents() {
    _handledCallEvents.clear();
    _incomingInFlight.clear();
    _incomingRetry.clear();
  }

  static void _rememberCallEvent(String key) {
    _handledCallEvents.add(key);
    if (_handledCallEvents.length > _maxHandledCallEvents) {
      _handledCallEvents.remove(_handledCallEvents.first);
    }
  }

  /// 即時連線收到的通話事件（main.dart 掛上）。與推播走同一個入口，
  /// 兩邊都收到同一則時只處理先到的。
  static void handleSocketCallEvent(Map<String, dynamic> data) =>
      _handleCallEvent(data, _CallEventSource.socket);

  /// 是通話事件就處理並回傳 true（處理過的同一則略過）。
  /// 即時連線來的事件沒有畫面接手時不記下，留給隨後的推播彈通知。
  /// 來電要查到來電資料才算處理過（見 [_handleIncomingCall]）。
  static bool _handleCallEvent(
    Map<String, dynamic> data,
    _CallEventSource source,
  ) {
    final type = data['type'];
    if (type is! String || !_callEventTypes.contains(type)) return false;
    final id =
        (type.startsWith('video_') ? data['session_id'] : data['call_id'])
            ?.toString();
    final key = id == null || id.isEmpty ? null : '$type:$id';
    if (key != null && _handledCallEvents.contains(key)) return true;
    if (type == 'friend_call_incoming') {
      final callId = int.tryParse(id ?? '');
      if (callId != null && key != null) {
        unawaited(_handleIncomingCall(callId, key));
      }
      return true;
    }
    final delivered = _dispatchCallEvent(type, data, source);
    if (key != null && (delivered || source != _CallEventSource.socket)) {
      _rememberCallEvent(key);
    }
    return true;
  }

  /// 查到來電資料才記為處理過並開響鈴畫面；查詢失敗或已不在響鈴就不記，
  /// 讓後到的來源（例如即時連線先到但查詢失敗，隨後的推播）再查一次。
  /// 查詢期間同一通的其他來源不重複查，只在這次查不到時再補查一次。
  static Future<void> _handleIncomingCall(int callId, String key) async {
    if (!_incomingInFlight.add(callId)) {
      _incomingRetry.add(callId);
      return;
    }
    try {
      while (true) {
        final call = await _fetchIncomingCall(callId);
        if (_handledCallEvents.contains(key)) return;
        if (call != null) {
          _rememberCallEvent(key);
          onFriendCallIncoming?.call(call);
          return;
        }
        if (!_incomingRetry.remove(callId)) return;
      }
    } finally {
      _incomingInFlight.remove(callId);
      _incomingRetry.remove(callId);
    }
  }

  /// 交給對應的畫面回呼，有人接手回傳 true。前景推播的視訊事件沒人接手時
  /// 改彈本地通知；即時連線不彈，交給隨後的推播。來電另由 [_handleIncomingCall] 處理。
  static bool _dispatchCallEvent(
    String type,
    Map<String, dynamic> data,
    _CallEventSource source,
  ) {
    final callId = int.tryParse(data['call_id']?.toString() ?? '');
    final sessionId = int.tryParse(data['session_id']?.toString() ?? '');
    bool deliver(void Function(int)? handler, int? id) {
      if (handler == null || id == null) return false;
      handler(id);
      return true;
    }

    switch (type) {
      case 'video_matched':
        final channel = data['channel']?.toString();
        if (source == _CallEventSource.openedPush) {
          onVideoMatchedColdStart?.call(sessionId, channel);
          return true;
        }
        final handler = onVideoMatchedForeground;
        if (handler != null) {
          handler(sessionId, channel);
          return true;
        }
        if (source == _CallEventSource.foregroundPush) {
          _showVideoNotification(sessionId, matched: true);
        }
        return false;
      case 'video_session_ended':
        final handler = onVideoSessionEnded;
        if (handler != null) {
          handler(sessionId);
          return true;
        }
        if (source == _CallEventSource.foregroundPush) {
          _showVideoNotification(sessionId, matched: false);
        }
        return false;
      case 'friend_call_accepted':
        return deliver(onFriendCallAccepted, callId);
      case 'friend_call_declined':
        return deliver(onFriendCallDeclined, callId);
      case 'friend_call_cancelled':
        return deliver(onFriendCallCancelled, callId);
      case 'friend_call_ended':
        return deliver(onFriendCallEnded, callId);
    }
    return false;
  }

  @visibleForTesting
  static void handleForegroundMessage(RemoteMessage message) =>
      _onForegroundMessage(message);

  @visibleForTesting
  static void handleOpenedMessage(RemoteMessage message) =>
      _handleOpened(message);

  static void _onForegroundMessage(RemoteMessage message) {
    if (_inboxPushTypes.contains(message.data['type'])) {
      NotificationSummaryService.refresh();
    }
    if (message.data['type'] == 'moderation') {
      _applyModerationLock(message.data);
      _showModerationNotice(message);
      return;
    }
    if (message.data['type'] == 'announcement') {
      _onForegroundAnnouncement(message);
      return;
    }
    if (_applyAccountRole(message.data)) {
      final text = message.notification?.body ?? message.notification?.title;
      if (text != null && text.isNotEmpty) {
        scaffoldMessengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
      return;
    }

    if (_handleCallEvent(message.data, _CallEventSource.foregroundPush)) {
      return;
    }

    // 好友相關：App 開著時只更新紅點與未讀數，不彈提示。
    if (parseFriendPush(message.data) != null) {
      NotificationSummaryService.refresh();
      return;
    }

    final forum = parseForumPayload(message.data);
    if (forum != null) {
      final forumPostId = forum.postId;
      final commentId = forum.commentId;
      final inboxId = parseInboxId(message.data);
      // 人就在那一頁：改由頁內提示，不再彈通知。
      final handled = onForumReplyWhileOpen?.call(forumPostId, forum.type);
      if (handled == true) return;
      final title = message.notification?.title ?? '有人回覆你';
      final body = message.notification?.body ?? '';
      unawaited(
        _localNotifications.show(
          id: message.hashCode,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: _reminderAndroidDetails,
          ),
          payload: forumNotificationPayload(
            forumPostId,
            inboxId: inboxId,
            commentId: commentId,
          ),
        ),
      );
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(body.isNotEmpty ? body : title),
            action: SnackBarAction(
              label: '查看',
              onPressed: () =>
                  _openForumReply(forumPostId, inboxId, commentId: commentId),
            ),
          ),
        );
      return;
    }

    final deleted = parseEventDeleted(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    if (deleted != null) {
      _onForegroundEventDeleted(message.hashCode, deleted);
      return;
    }

    final parsed = _parseReminderPayload(message.data);
    if (parsed == null) return;
    final (_, eventId) = parsed;

    final title = message.notification?.title ?? '活動提醒';
    final body = message.notification?.body ?? '';

    unawaited(
      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _reminderAndroidDetails,
        ),
        payload: eventId?.toString(),
      ),
    );

    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(body.isNotEmpty ? body : title),
          action: eventId == null
              ? null
              : SnackBarAction(
                  label: '查看',
                  onPressed: () => onReminderTapped?.call(eventId),
                ),
        ),
      );

    onReminderReceivedForOpenScreen?.call(eventId);
  }

  /// 前景收到活動被刪除：彈本機通知與 SnackBar（沒有「查看」，活動已不存在），
  /// 再交給開著的畫面各自處理。
  static void _onForegroundEventDeleted(
    int notificationId,
    EventDeletedNotice notice,
  ) {
    final text = _eventDeletedText(notice);
    unawaited(
      _localNotifications.show(
        id: notificationId,
        title: notice.title,
        body: text,
        notificationDetails: const NotificationDetails(
          android: _reminderAndroidDetails,
        ),
        payload: '$_eventDeletedPayloadPrefix$text',
      ),
    );
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
    dispatchEventDeleted(notice.eventId);
  }

  /// 帳號角色被管理員變更（type: account_role）：重抓 /api/me，
  /// 「發起活動」「管理後台」入口監聽 userNotifier，不必重開 App 就跟著變。
  /// 回傳是否為這類推播。
  static bool _applyAccountRole(Map<String, dynamic> data) {
    if (data['type'] != 'account_role') return false;
    unawaited(
      UserService.fetchMe(forceRefresh: true).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('角色變更後重抓 /api/me 失敗：$e'),
      ),
    );
    return true;
  }

  /// 前景收到官方公告：彈本機通知與 SnackBar，「查看」開收件匣的公告分頁。
  static void _onForegroundAnnouncement(RemoteMessage message) {
    final title = message.notification?.title ?? '官方公告';
    final body = message.notification?.body ?? '';
    unawaited(
      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _reminderAndroidDetails,
        ),
        payload: _announcementPayload,
      ),
    );
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(title),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => onInboxTapped?.call('announcement'),
          ),
        ),
      );
  }

  /// 依審核推播更新唯讀狀態；解除時重抓 /api/me，讓個人頁等畫面拿到最新資料。
  static void _applyModerationLock(Map<String, dynamic> data) {
    if (accountLockController.applyModerationPush(data) != false) return;
    unawaited(
      UserService.fetchMe(forceRefresh: true).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('解鎖後重抓 /api/me 失敗：$e'),
      ),
    );
  }

  /// 處置通知（內容被隱藏、個人檔案被重設、確認違規、禁言／解除禁言、申訴結果）。
  /// title／body 已是後端寫好的完整中文說明，直接彈對話框顯示，
  /// 不走 SnackBar——理由較長，且當事人需要確實看到。
  /// 有對應案件時多一顆「查看詳情」開處置詳情頁。
  static void _showModerationNotice(RemoteMessage message) {
    final data = message.data;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final title = message.notification?.title ?? '內容審核通知';
    final body = message.notification?.body ?? '';
    // 撤銷處置且目標是貼文：提供回到該貼文的入口。
    final restoredPostId =
        data['action'] == 'case_overturned' && data['target_type'] == 'post'
        ? int.tryParse(data['target_id']?.toString() ?? '')
        : null;
    final caseId = parseModerationCaseId(data);
    final inboxId = parseInboxId(data);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            if (restoredPostId != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForumReply(restoredPostId, inboxId);
                },
                child: const Text('查看貼文'),
              ),
            if (caseId != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openModerationCase(caseId, inboxId);
                },
                child: const Text('查看詳情'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _markInboxRead(inboxId);
              },
              child: const Text('我知道了'),
            ),
          ],
        ),
      ),
    );
  }

  /// 前景收到視訊配對相關推播、但等待／通話畫面沒開著時彈的本地通知；畫面
  /// 開著時由畫面處理，不彈通知打擾。配對結束也要彈：少了這則，對方掛斷時
  /// 不在通話畫面的使用者完全不會被告知通話已結束。
  static void _showVideoNotification(int? sessionId, {required bool matched}) {
    unawaited(
      _localNotifications.show(
        id: sessionId ?? DateTime.now().millisecondsSinceEpoch,
        title: matched ? '找到語伴了！' : '視訊練習已結束',
        body: matched ? '點開始你們的視訊練習' : '這次的通話已經結束了',
        notificationDetails: const NotificationDetails(
          android: _reminderAndroidDetails,
        ),
        payload: matched ? 'video:$sessionId' : 'video_ended:$sessionId',
      ),
    );
  }

  static void _handleOpened(RemoteMessage message) {
    if (_inboxPushTypes.contains(message.data['type'])) {
      NotificationSummaryService.refresh();
    }
    if (message.data['type'] == 'moderation') {
      _applyModerationLock(message.data);
      final caseId = parseModerationCaseId(message.data);
      final inboxId = parseInboxId(message.data);
      if (caseId != null) {
        _openModerationCase(caseId, inboxId);
      } else {
        // 沒有案件可看（例如解除禁言）：通知列已顯示過，點開後再顯示一次完整說明。
        _markInboxRead(inboxId);
        _showModerationNotice(message);
      }
      return;
    }
    if (message.data['type'] == 'announcement') {
      onInboxTapped?.call('announcement');
      return;
    }
    // 通知列已顯示過內容，點開只需讓入口跟上新角色。
    if (_applyAccountRole(message.data)) return;

    if (_handleCallEvent(message.data, _CallEventSource.openedPush)) return;

    final friendPush = parseFriendPush(message.data);
    if (friendPush != null) {
      final code = friendPush.friendCode;
      if (code != null) onFriendPushTapped?.call(friendPush.type, code);
      return;
    }

    final forum = parseForumPayload(message.data);
    if (forum != null) {
      _openForumReply(
        forum.postId,
        parseInboxId(message.data),
        commentId: forum.commentId,
      );
      return;
    }
    final deleted = parseEventDeleted(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    if (deleted != null) {
      onEventDeletedTapped?.call(_eventDeletedText(deleted));
      return;
    }
    final parsed = _parseReminderPayload(message.data);
    if (parsed == null) return;
    final (_, eventId) = parsed;
    onReminderTapped?.call(eventId);
  }
}
