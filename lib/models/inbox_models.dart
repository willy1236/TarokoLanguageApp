// 站內收件匣的資料模型。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md §0、§1、§6。
//
// 論壇、活動、審核、官方公告四類通知都存在收件匣；好友邀請與私訊不在這裡。

import 'forum_models.dart';
import 'page_info.dart';

int? _int(Object? v) => v == null ? null : int.tryParse('$v');

/// 收件匣分類（`category`）。畫面的「全部」分頁以 null 表示。
abstract final class InboxCategory {
  static const forum = 'forum';
  static const event = 'event';
  static const moderation = 'moderation';
  static const announcement = 'announcement';
}

class InboxItem {
  final int id;
  final String category;
  final String kind;
  final String title;

  /// 論壇回覆的內文是目前的貼文標題，貼文已刪除時為 null。
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  final int? postId;
  final int? commentId;
  final int? eventId;

  /// 審核類的違規案件 id；有值才有處置詳情可看。
  final int? caseId;

  /// 官方公告的圖片。限時網址（約 15 分鐘），過期就重抓列表，不存到本機。
  final String? imageUrl;

  /// 論壇回覆的回覆者，其他類別為 null。
  final ForumAuthor? actor;

  /// 對象目前的狀態：`ok`／`deleted`／`removed`／`cancelled`。
  final String targetState;

  const InboxItem({
    required this.id,
    required this.category,
    required this.kind,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.eventId,
    this.caseId,
    this.imageUrl,
    this.actor,
    this.targetState = 'ok',
  });

  factory InboxItem.fromJson(Map<String, dynamic> j) {
    final actor = j['actor'];
    return InboxItem(
      id: _int(j['id']) ?? 0,
      category: j['category'] as String? ?? '',
      kind: j['kind'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String?,
      isRead: j['is_read'] == true,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
      postId: _int(j['post_id']),
      commentId: _int(j['comment_id']),
      eventId: _int(j['event_id']),
      caseId: _int(j['case_id']),
      imageUrl: j['image_url'] as String?,
      actor: actor is Map<String, dynamic> ? ForumAuthor.fromJson(actor) : null,
      targetState: j['target_state'] as String? ?? 'ok',
    );
  }

  InboxItem markedRead() => InboxItem(
    id: id,
    category: category,
    kind: kind,
    title: title,
    body: body,
    isRead: true,
    createdAt: createdAt,
    postId: postId,
    commentId: commentId,
    eventId: eventId,
    caseId: caseId,
    imageUrl: imageUrl,
    actor: actor,
    targetState: targetState,
  );
}

/// 收件匣各類未讀數（summary 的 `inbox`、列表的 `unread`），各項由後端封頂 100。
class InboxUnread {
  final int forum;
  final int event;
  final int moderation;
  final int announcement;
  final int total;

  const InboxUnread({
    this.forum = 0,
    this.event = 0,
    this.moderation = 0,
    this.announcement = 0,
    this.total = 0,
  });

  static const empty = InboxUnread();

  factory InboxUnread.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return empty;
    int count(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return InboxUnread(
      forum: count('forum'),
      event: count('event'),
      moderation: count('moderation'),
      announcement: count('announcement'),
      total: count('total'),
    );
  }

  /// [category] 為 null（全部）時回總數。
  int of(String? category) => switch (category) {
    null => total,
    InboxCategory.forum => forum,
    InboxCategory.event => event,
    InboxCategory.moderation => moderation,
    InboxCategory.announcement => announcement,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is InboxUnread &&
      other.forum == forum &&
      other.event == event &&
      other.moderation == moderation &&
      other.announcement == announcement &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(forum, event, moderation, announcement, total);
}

class InboxPage {
  final List<InboxItem> items;
  final PageInfo pageInfo;

  const InboxPage({required this.items, required this.pageInfo});

  factory InboxPage.fromJson(Map<String, dynamic> j) => InboxPage(
    items: [
      for (final e in j['items'] as List<dynamic>? ?? const [])
        InboxItem.fromJson(e as Map<String, dynamic>),
    ],
    pageInfo: PageInfo.fromResponse(j),
  );
}

// ── 點一則通知之後要做什麼 ────────────────────────────────────────

/// 點選收件匣一則通知的去向，由 [inboxTargetFor] 決定，畫面只負責照著做。
sealed class InboxTarget {
  const InboxTarget();
}

/// 開貼文，[commentId] 有值時捲到該留言。
class InboxOpenPost extends InboxTarget {
  final int postId;
  final int? commentId;
  const InboxOpenPost(this.postId, {this.commentId});
}

class InboxOpenEvent extends InboxTarget {
  final int eventId;
  const InboxOpenEvent(this.eventId);
}

/// 開處置詳情頁。
class InboxOpenCase extends InboxTarget {
  final int caseId;
  const InboxOpenCase(this.caseId);
}

class InboxOpenAnnouncement extends InboxTarget {
  const InboxOpenAnnouncement();
}

/// 對象已不存在：不開頁（會 404），只提示 [message]。
class InboxGone extends InboxTarget {
  final String message;
  const InboxGone(this.message);
}

/// 沒有可以去的頁面，只顯示這則的內文。[refreshMe] 為 true 時另外重抓
/// `/api/me`（帳號權限變更，入口要跟著變）。
class InboxShowBody extends InboxTarget {
  final bool refreshMe;
  const InboxShowBody({this.refreshMe = false});
}

InboxTarget inboxTargetFor(InboxItem item) {
  final deleted = item.targetState == 'deleted';
  final removed = item.targetState == 'removed';
  switch (item.category) {
    case InboxCategory.forum:
      final postId = item.postId;
      if (removed) return const InboxGone('貼文已被下架');
      if (deleted || postId == null) return const InboxGone('貼文已被刪除');
      return InboxOpenPost(postId, commentId: item.commentId);
    case InboxCategory.event:
      final eventId = item.eventId;
      if (removed || item.kind == 'event_removed') {
        return const InboxGone('該活動已被下架');
      }
      if (deleted || item.kind == 'event_deleted' || eventId == null) {
        return const InboxGone('該活動已被刪除');
      }
      return InboxOpenEvent(eventId);
    case InboxCategory.moderation:
      final caseId = item.caseId;
      if (caseId != null) return InboxOpenCase(caseId);
      return InboxShowBody(refreshMe: item.kind == 'account_role');
    case InboxCategory.announcement:
      return const InboxOpenAnnouncement();
    default:
      // 這版不認得的分類：至少讓人讀得到內文。
      return const InboxShowBody();
  }
}
