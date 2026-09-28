// 所有紅點徽章的未讀數，一支 GET /api/notifications/summary 取回
// （見 Truku_backend 說明文件/前端交接/總覽.md §4.3）。
//
// App 開啟、回前景、看完通知／私訊／好友邀請後呼叫 [refresh]，
// 各畫面監聽 [notifier] 畫徽章，不再各自打論壇／活動通知清單取未讀數。

import 'package:flutter/foundation.dart';

import '../core/constants/api.dart';
import '../core/network/api_client.dart';

class NotificationSummary {
  /// 各項皆由後端封頂 100；等於 [cap] 時顯示「99+」。
  static const int cap = 100;

  final int forum;
  final int events;
  final int messages;
  final int friendRequests;
  final int total;

  const NotificationSummary({
    this.forum = 0,
    this.events = 0,
    this.messages = 0,
    this.friendRequests = 0,
    this.total = 0,
  });

  static const empty = NotificationSummary();

  factory NotificationSummary.fromJson(Map<String, dynamic> json) =>
      NotificationSummary(
        forum: (json['forum'] as num?)?.toInt() ?? 0,
        events: (json['events'] as num?)?.toInt() ?? 0,
        messages: (json['messages'] as num?)?.toInt() ?? 0,
        friendRequests: (json['friend_requests'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  /// 廣場活動分頁（論壇＋活動通知）。
  int get plaza => forum + events;

  /// 好友分頁（私訊＋待回覆的好友邀請）。
  int get friends => messages + friendRequests;

  @override
  bool operator ==(Object other) =>
      other is NotificationSummary &&
      other.forum == forum &&
      other.events == events &&
      other.messages == messages &&
      other.friendRequests == friendRequests &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(forum, events, messages, friendRequests, total);
}

/// 徽章文字：超過 99（含後端封頂的 100）顯示「99+」。
String badgeLabel(int count) => count > 99 ? '99+' : '$count';

class NotificationSummaryService {
  static final ValueNotifier<NotificationSummary> notifier = ValueNotifier(
    NotificationSummary.empty,
  );

  static Future<void>? _inFlight;

  /// 請求進行中又被要求刷新：那個請求的結果可能早於新事件，完成後要再抓一次。
  static bool _stale = false;

  /// 重新取未讀數。進行中又被呼叫時不另發請求，完成後再補抓一次（多次呼叫
  /// 合併成一次）；失敗時保留舊值（紅點拿不到不該干擾主要內容）。
  static Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _stale = true;
      return inFlight;
    }
    return _inFlight = _fetchUntilFresh();
  }

  static Future<void> _fetchUntilFresh() async {
    try {
      do {
        _stale = false;
        await _fetch();
      } while (_stale);
    } finally {
      _inFlight = null;
    }
  }

  static Future<void> _fetch() async {
    try {
      final data = await ApiClient.get(ApiConfig.notificationsSummary);
      notifier.value = NotificationSummary.fromJson(data);
    } catch (e) {
      debugPrint('NotificationSummaryService.refresh 失敗（保留舊值）：$e');
    }
  }

  /// 登出時清空，避免下一位登入者看到前一個帳號的紅點。
  static void clear() => notifier.value = NotificationSummary.empty;
}
