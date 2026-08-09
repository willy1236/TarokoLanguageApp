// 活動 + 提醒 + 裝置推播 API 呼叫。
//
// 沿用共用的 ApiClient（自動帶 JWT、401 自動導回登入、統一 {error:{code,message}}
// 錯誤解析）。對應後端 Truku_backend backend/routes/events.ts。
//
// 端點：
//   GET    /api/events                    活動列表（scope=upcoming|all）
//   GET    /api/events/mine               我發起的活動
//   POST   /api/events                    發起活動（限 organizer/admin）
//   GET    /api/events/:id                活動詳情 + 參加者
//   POST   /api/events/:id/join           參加
//   DELETE /api/events/:id/join           退出
//   POST   /api/events/:id/cancel         取消活動（僅發起人，須填理由）
//   POST   /api/events/:id/reminders      建立提醒（僅發起人）
//   GET    /api/events/:id/reminders      列出提醒
//   DELETE /api/reminders/:id             取消未發送提醒
//   POST   /api/devices                   上傳/更新 FCM token
//   DELETE /api/devices                   移除 FCM token

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/event_model.dart';

class EventService {
  // ── 活動 ────────────────────────────────────────────────────

  /// 活動列表。[scope]：'upcoming'（預設，即將到來）或 'all'（全部）。
  /// 後端分頁，回傳 events[]（含 participantCount / isJoined / 即時狀態）。
  static Future<List<EventSummary>> fetchEvents({
    String scope = 'upcoming',
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await ApiClient.get(ApiConfig.events, query: {
      'scope': scope,
      'page': '$page',
      'page_size': '$pageSize',
    });
    final list = data['events'] as List<dynamic>? ?? const [];
    return list
        .map((e) => EventSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 我的活動（我發起的 + 我參加的）。
  static Future<List<EventSummary>> fetchMyEvents() async {
    final data = await ApiClient.get(ApiConfig.eventsMine);
    final list = data['events'] as List<dynamic>? ?? const [];
    return list
        .map((e) => EventSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 發起活動。後端（v2）五個必填欄位：title / description / location（地點名稱）/
  /// address（詳細地址）/ startsAt（需未來、1 年內）。contact 為選填。
  /// 回傳新活動的 id。
  ///
  /// 注意：後端限定 organizer / admin 角色才能發起，一般 user 會收到 403
  /// FORBIDDEN「需要活動主辦權限」。
  static Future<int> createEvent({
    required String title,
    required String description,
    required String location,
    required String address,
    required DateTime startsAt,
    DateTime? registrationDeadline,
    String? contactEmail,
    String? contactPhone,
    String? reminderNote,
    int? maxParticipants,
    String? category,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      'address': address,
      'starts_at': startsAt.toUtc().toIso8601String(),
    };
    if (registrationDeadline != null) {
      body['registration_deadline'] =
          registrationDeadline.toUtc().toIso8601String();
    }
    if (contactEmail != null && contactEmail.trim().isNotEmpty) {
      body['contact_email'] = contactEmail.trim();
    }
    if (contactPhone != null && contactPhone.trim().isNotEmpty) {
      body['contact_phone'] = contactPhone.trim();
    }
    if (reminderNote != null && reminderNote.trim().isNotEmpty) {
      body['reminder_note'] = reminderNote.trim();
    }
    if (maxParticipants != null) body['max_participants'] = maxParticipants;
    if (category != null && category.trim().isNotEmpty) {
      body['category'] = category.trim();
    }
    final data = await ApiClient.post(ApiConfig.events, body);
    return asEventInt(data['id'])!;
  }

  /// 活動詳情（含參加者清單）。
  static Future<EventDetail> fetchEventDetail(int eventId) async {
    final data = await ApiClient.get(ApiConfig.eventDetail(eventId));
    return EventDetail.fromJson(data);
  }

  /// 參加活動。
  static Future<void> joinEvent(int eventId) async {
    await ApiClient.post(ApiConfig.eventJoin(eventId));
  }

  /// 退出活動（發起人不可退出，後端會擋）。
  static Future<void> leaveEvent(int eventId) async {
    await ApiClient.delete(ApiConfig.eventJoin(eventId));
  }

  /// 取消活動（僅發起人；須填理由，後端會推播通知所有參加者）。
  static Future<void> cancelEvent(int eventId, String reason) async {
    await ApiClient.post(ApiConfig.eventCancel(eventId), {'reason': reason});
  }

  // ── 提醒 ────────────────────────────────────────────────────

  /// 建立提醒（僅發起人）。[scheduledAt] 留 null = 立即發送（帶現在時間，
  /// 後端下一輪派送即送出）。
  static Future<EventReminder> createReminder(
    int eventId, {
    required String message,
    DateTime? scheduledAt,
  }) async {
    final when = (scheduledAt ?? DateTime.now()).toUtc().toIso8601String();
    final data = await ApiClient.post(ApiConfig.eventReminders(eventId), {
      'message': message,
      'scheduled_at': when,
    });
    return EventReminder.fromJson(data);
  }

  /// 列出某活動的所有提醒。
  static Future<List<EventReminder>> fetchReminders(int eventId) async {
    final data = await ApiClient.get(ApiConfig.eventReminders(eventId));
    final list = data['reminders'] as List<dynamic>? ?? const [];
    return list
        .map((e) => EventReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 取消尚未發送的提醒（僅發起人）。
  static Future<void> cancelReminder(int reminderId) async {
    await ApiClient.delete(ApiConfig.reminderDetail(reminderId));
  }

  // ── 裝置推播 token ──────────────────────────────────────────

  /// 上傳/更新本裝置的 FCM token。[platform] 為 'ios' 或 'android'。
  static Future<void> registerDevice(String fcmToken, String platform) async {
    await ApiClient.post(ApiConfig.devices, {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  /// 登出時移除本裝置 token。
  static Future<void> unregisterDevice(String fcmToken) async {
    await ApiClient.delete(ApiConfig.devices, {'fcm_token': fcmToken});
  }
}
