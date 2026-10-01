// 活動 + 提醒 + 裝置推播 API 呼叫。
//
// 沿用共用的 ApiClient（自動帶 JWT、401 自動導回登入、統一 {error:{code,message}}
// 錯誤解析）。對應後端 Truku_backend backend/routes/events.ts。
//
// 端點：
//   GET    /api/events                    活動列表（只回尚未開始的活動）
//   GET    /api/events/mine               我發起的活動
//   GET    /api/events/joined             我參加的活動（tab=active|ended）
//   POST   /api/events                    發起活動（限 organizer/admin）
//   GET    /api/events/:id                活動詳情 + 參加者
//   PATCH  /api/events/:id                編輯活動（僅發起人）
//   DELETE /api/events/:id                軟刪除活動（僅發起人，限未開始）
//   POST   /api/events/:id/join           參加
//   DELETE /api/events/:id/join           退出
//   POST   /api/events/:id/cancel         取消活動（僅發起人，須填理由）
//   POST   /api/events/:id/reminders      建立提醒（僅發起人）
//   GET    /api/events/:id/reminders      列出提醒
//   DELETE /api/reminders/:id             取消未發送提醒
//   POST   /api/devices                   上傳/更新 FCM token
//   DELETE /api/devices                   移除 FCM token
//   POST   / DELETE /api/events/:id/like     按讚 / 取消（任何活動狀態皆可）
//   POST   / DELETE /api/events/:id/bookmark 收藏 / 取消
//   GET    /api/events/likes              我按讚過的活動
//   GET    /api/events/bookmarks          我收藏的活動
//   POST   /api/events/:id/images         上傳活動圖片（僅發起人，multipart）
//   DELETE /api/events/:id/images/:imgId  刪除一張活動圖片（僅發起人）

import 'dart:typed_data';

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/event_draft.dart';
import '../models/event_model.dart';
import '../models/page_info.dart';

/// 活動列表的一頁。只要第一頁的呼叫端（首頁、廣場）取 [events] 即可。
typedef EventPage = ({List<EventSummary> events, PageInfo pageInfo});

class EventService {
  /// 每場活動最多幾張圖片、每張多大（後端同樣限制）。
  static const int imageMaxCount = 6;
  static const int imageMaxBytes = 5 * 1024 * 1024;

  // ── 活動 ────────────────────────────────────────────────────

  /// 活動列表：只含尚未開始的活動，依開始時間升冪（後端已不分 scope）。
  /// 回傳 events[]（含 participantCount / isJoined / 即時狀態）。
  static Future<EventPage> fetchEvents({String? cursor, int limit = 20}) =>
      _fetchPage(ApiConfig.events, cursor: cursor, limit: limit);

  /// 關鍵字／時間區間／部落搜尋，三個維度皆選填、可任意組合。range 篩「未來 N 內
  /// 即將舉辦」（跟 videos/articles 篩「最近發布」語意相反，見後端 events.ts）。
  static Future<EventPage> searchEvents({
    String? q,
    String? range,
    int? tribeId,
    String? cursor,
    int limit = 20,
  }) {
    final trimmed = q?.trim();
    return _fetchPage(
      ApiConfig.eventSearch,
      cursor: cursor,
      limit: limit,
      filters: {
        'q': ?(trimmed != null && trimmed.isNotEmpty ? trimmed : null),
        'range': ?range,
        'tribe_id': ?tribeId?.toString(),
      },
    );
  }

  /// 我發起的活動。
  static Future<EventPage> fetchMyEvents({String? cursor, int limit = 20}) =>
      _fetchPage(ApiConfig.eventsMine, cursor: cursor, limit: limit);

  /// 我參加的活動（含自己發起的）。[tab]：'active'（即將開始與進行中，開始時間升冪）
  /// 或 'ended'（已結束與已取消，開始時間降冪）。
  static Future<EventPage> fetchJoinedEvents({
    required String tab,
    String? cursor,
    int limit = 20,
  }) => _fetchPage(
    ApiConfig.eventsJoined,
    cursor: cursor,
    limit: limit,
    filters: {'tab': tab},
  );

  /// 發起活動。後端（v2）五個必填欄位：title / description / location（地點名稱）/
  /// address（詳細地址）/ startsAt（需未來、1 年內）。contact 為選填。
  /// 回傳新活動的 id，與這次部落推播是否因 24 小時內已推滿 3 次而沒送出
  /// （`tribe_notify_limited`，回應沒有此欄位時視為 false）。
  ///
  /// 注意：後端限定 organizer / admin 角色才能發起，一般 user 會收到 403
  /// FORBIDDEN「需要活動主辦權限」。
  static Future<({int id, bool tribeNotifyLimited})> createEvent(
    EventDraft draft,
  ) async {
    final data = await ApiClient.post(ApiConfig.events, draft.toCreateBody());
    return (
      id: asEventInt(data['id'])!,
      tribeNotifyLimited: data['tribe_notify_limited'] == true,
    );
  }

  /// 活動詳情（含參加者清單）。
  static Future<EventDetail> fetchEventDetail(int eventId) async {
    final data = await ApiClient.get(ApiConfig.eventDetail(eventId));
    return EventDetail.fromJson(data);
  }

  /// 參加活動。[contactEmail] 為後端必填欄位（供主辦聯繫用，可與帳號 email 不同）。
  static Future<void> joinEvent(
    int eventId, {
    required String contactEmail,
  }) async {
    await ApiClient.post(ApiConfig.eventJoin(eventId), {
      'contact_email': contactEmail.trim(),
    });
  }

  /// 匯出報名名單 CSV（僅發起人；回傳的字串已含 UTF-8 BOM，可直接寫檔）。
  static Future<String> exportRoster(int eventId) async {
    return ApiClient.getRaw(ApiConfig.eventExport(eventId));
  }

  /// 退出活動（發起人不可退出，後端會擋）。
  static Future<void> leaveEvent(int eventId) async {
    await ApiClient.delete(ApiConfig.eventJoin(eventId));
  }

  /// 取消活動（僅發起人；須填理由，後端會推播通知所有參加者）。
  static Future<void> cancelEvent(int eventId, String reason) async {
    await ApiClient.post(ApiConfig.eventCancel(eventId), {'reason': reason});
  }

  /// 編輯活動（僅發起人）。
  ///
  /// 只送 [EventDraft.editableFields] 中與 [original] 不同的欄位；文字清空送
  /// 空字串，名額留空送 null（不限名額）。starts_at / registration_deadline 不可改。
  /// **title/location/address 不可為空**（後端回 400），[EventDraft.validate] 已擋住。
  /// 活動已取消或已開始時後端回 409 EVENT_CLOSED / EVENT_ENDED。
  static Future<void> updateEvent(
    int eventId,
    EventDraft draft,
    EventDetail original,
  ) async {
    final body = draft.toPatchBody(original);
    if (body.isEmpty) return; // 後端對空 body 回 400，沒有變更就不必送出
    await ApiClient.patch(ApiConfig.eventDetail(eventId), body);
  }

  /// 軟刪除活動（僅發起人；後端限未開始的活動才可刪除）。
  /// 回傳後端推播通知了幾位報名者（`notified`）；欄位缺少時視為 0。
  static Future<int> deleteEvent(int eventId) async {
    final data = await ApiClient.delete(ApiConfig.eventDetail(eventId));
    return int.tryParse(data['notified']?.toString() ?? '') ?? 0;
  }

  // ── 圖片（僅發起人；任何狀態的活動都可以，已刪除的除外）───────────

  /// 上傳圖片（已在 App 端壓成 JPEG，見 pickImagesForUpload）。一次全部成功或
  /// 全部失敗；回傳該活動目前全部的圖片，依上傳順序，第一張是封面。
  static Future<List<EventImage>> uploadImages(
    int eventId,
    List<Uint8List> jpegs,
  ) async {
    final data = await ApiClient.postMultipart(
      ApiConfig.eventImages(eventId),
      fields: const {},
      files: [
        for (var i = 0; i < jpegs.length; i++)
          MultipartFileData(
            field: 'images',
            bytes: jpegs[i],
            filename: 'event_${eventId}_$i.jpg',
            mimeType: 'image/jpeg',
          ),
      ],
    );
    return EventImage.listFromJson(data['images']);
  }

  /// 刪除一張圖片，回傳剩下的全部圖片。那張已經不在（IMAGE_NOT_FOUND，例如在
  /// 別台裝置刪過）也算成功，改從活動詳情取目前的圖片。
  static Future<List<EventImage>> deleteImage(int eventId, int imageId) async {
    try {
      final data = await ApiClient.delete(
        ApiConfig.eventImage(eventId, imageId),
      );
      return EventImage.listFromJson(data['images']);
    } on ApiException catch (e) {
      if (e.code != 'IMAGE_NOT_FOUND') rethrow;
      return (await fetchEventDetail(eventId)).images;
    }
  }

  // ── 按讚／收藏 ──────────────────────────────────────────────
  // 任何活動狀態（含 cancelled/已結束）皆可操作；讚數為即時 COUNT，非反正規化。

  /// 回傳後端算出的真實計數，呼叫端不要自行累加——樂觀更新只是暫時值。
  static Future<({bool liked, int likeCount})> likeEvent(
    int eventId, {
    required bool like,
  }) async {
    final path = ApiConfig.eventLike(eventId);
    final data = like
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return (
      liked: data['liked'] == true,
      likeCount: int.tryParse(data['like_count']?.toString() ?? '') ?? 0,
    );
  }

  static Future<bool> bookmarkEvent(int eventId, {required bool add}) async {
    final path = ApiConfig.eventBookmark(eventId);
    final data = add
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return data['bookmarked'] == true;
  }

  static Future<EventPage> fetchLikedEvents({String? cursor, int limit = 20}) =>
      _fetchPage(ApiConfig.eventLikes, cursor: cursor, limit: limit);

  static Future<EventPage> fetchBookmarkedEvents({
    String? cursor,
    int limit = 20,
  }) => _fetchPage(ApiConfig.eventBookmarks, cursor: cursor, limit: limit);

  /// 所有活動列表端點共用：帶 cursor／limit 與各自的篩選條件，解析 events 與 page_info。
  static Future<EventPage> _fetchPage(
    String path, {
    required String? cursor,
    required int limit,
    Map<String, String> filters = const {},
  }) async {
    final data = await ApiClient.get(
      path,
      query: {
        ...filters,
        ...PageInfo.query(cursor: cursor, limit: limit),
      },
    );
    final list = data['events'] as List<dynamic>? ?? const [];
    return (
      events: list
          .map((e) => EventSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      pageInfo: PageInfo.fromResponse(data),
    );
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
