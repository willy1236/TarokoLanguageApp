// 一對一聊天訊息與對話清單（見 Truku_backend backend/routes/friendMessages.ts）。

class FriendMessage {
  final int id;

  /// 是不是我傳的（後端算好，不再帶雙方 uid）。
  final bool mine;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const FriendMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  FriendMessage markedRead(DateTime at) => FriendMessage(
    id: id,
    mine: mine,
    body: body,
    createdAt: createdAt,
    readAt: at,
  );

  static int _toInt(dynamic v) => switch (v) {
    num n => n.toInt(),
    String s => int.tryParse(s) ?? 0,
    _ => 0,
  };

  factory FriendMessage.fromJson(Map<String, dynamic> j) => FriendMessage(
    id: _toInt(j['id']),
    mine: j['mine'] as bool? ?? false,
    body: j['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    readAt: j['read_at'] == null
        ? null
        : DateTime.tryParse(j['read_at'].toString()),
  );
}

/// 通話結果，後端依「誰在看」算好（Truku_backend backend/callLog.ts）：
/// 撥出方沒接通一律是 [cancelled]（含被拒接），被打的人是 [missed] 或自己按的 [declined]。
enum FriendCallKind { completed, cancelled, missed, declined }

/// 聊天室的 `calls` 與對話列表的 `last_call`。
class FriendCall {
  final int id;
  final FriendCallKind kind;

  /// 我是撥出方：泡泡靠右。
  final bool mine;

  /// 撥出時間，與訊息一起依時間排序。
  final DateTime createdAt;

  /// 通話秒數，只有 [FriendCallKind.completed] 有值。
  final int? durationSec;

  /// 還沒看過的未接來電，只有 [FriendCallKind.missed] 可能為 true。
  final bool isUnread;

  const FriendCall({
    required this.id,
    required this.kind,
    required this.mine,
    required this.createdAt,
    this.durationSec,
    this.isUnread = false,
  });

  /// `kind` 不認得（後端日後新增的結果）或 `created_at` 解析不了回 null，
  /// 呼叫端略過不顯示：沒有時間就排不進聊天室與列表。
  static FriendCall? fromJson(Map<String, dynamic> j) {
    final kind = FriendCallKind.values.asNameMap()[j['kind']];
    final createdAt = DateTime.tryParse(j['created_at']?.toString() ?? '');
    if (kind == null || createdAt == null) return null;
    return FriendCall(
      id: FriendMessage._toInt(j['id']),
      kind: kind,
      mine: j['mine'] as bool? ?? false,
      createdAt: createdAt,
      durationSec: (j['duration_sec'] as num?)?.toInt(),
      isUnread: j['is_unread'] == true,
    );
  }

  /// 解析 `calls` 陣列，略過格式不對與不認得的。
  static List<FriendCall> listFromJson(dynamic list) => [
    if (list is List)
      for (final e in list)
        if (e is Map<String, dynamic>) ?FriendCall.fromJson(e),
  ];
}

/// GET /api/friends/messages 每筆對話的最後一則訊息預覽。
class ConversationPreview {
  final String body;
  final DateTime createdAt;
  final bool mine;

  const ConversationPreview({
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> j) =>
      ConversationPreview(
        body: j['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        mine: j['mine'] as bool? ?? false,
      );
}

class Conversation {
  final String? nickname;

  /// 對話對象的好友碼，開聊天室用。
  final String friendCode;
  final String? avatarUrl;
  final String? avatarId;
  final String? frameId;

  /// 未讀訊息加上未讀的未接來電（後端已合計）。
  final int unreadCount;
  final ConversationPreview? lastMessage;

  /// 最後一通電話；只打過電話、沒傳過訊息的對話 [lastMessage] 為 null。
  final FriendCall? lastCall;

  /// 最後一則訊息或最後一通電話較晚的時間，舊回應沒有時見 [activityAt]。
  final DateTime? lastActivityAt;

  /// 對象是刪除中或被鎖帳號：暱稱是後端的替代文字、頭像為 null，不能傳訊。
  final bool unavailable;

  const Conversation({
    this.nickname,
    required this.friendCode,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    required this.unreadCount,
    this.lastMessage,
    this.lastCall,
    this.lastActivityAt,
    this.unavailable = false,
  });

  /// 最後活動是通話：同一時間以訊息為準（同後端）。
  bool get lastIsCall {
    final call = lastCall;
    if (call == null) return false;
    final message = lastMessage;
    return message == null || call.createdAt.isAfter(message.createdAt);
  }

  /// 列表排序與右側時間用；舊回應沒有 `last_activity_at` 時退回最後一則訊息或通話。
  DateTime? get activityAt =>
      lastActivityAt ??
      (lastIsCall ? lastCall!.createdAt : lastMessage?.createdAt);

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
    lastMessage: j['last_message'] is Map<String, dynamic>
        ? ConversationPreview.fromJson(
            j['last_message'] as Map<String, dynamic>,
          )
        : null,
    lastCall: j['last_call'] is Map<String, dynamic>
        ? FriendCall.fromJson(j['last_call'] as Map<String, dynamic>)
        : null,
    lastActivityAt: DateTime.tryParse(j['last_activity_at']?.toString() ?? ''),
    unavailable: j['unavailable'] == true,
  );
}

/// GET /api/friends/:friend_code/messages 的 `partner`：聊天室對象的公開資料。
class ChatPartner {
  final String? nickname;
  final String friendCode;
  final String? avatarUrl;
  final String? avatarId;
  final String? frameId;

  /// 同 [Conversation.unavailable]。
  final bool unavailable;

  const ChatPartner({
    this.nickname,
    required this.friendCode,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    this.unavailable = false,
  });

  factory ChatPartner.fromJson(Map<String, dynamic> j) => ChatPartner(
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    avatarId: j['avatar_id'] as String?,
    frameId: j['frame_id'] as String?,
    unavailable: j['unavailable'] == true,
  );
}

/// 把重連後重抓的最新一頁 [latest] 併進已載入的 [loaded]（兩者皆新到舊）。
/// 同 id 以 [latest] 為準（已讀狀態可能更新），已載入的舊訊息保留。
/// 兩者接不起來代表中間有缺口，回 null，由呼叫端改用整頁替換。
List<FriendMessage>? mergeLatestMessages(
  List<FriendMessage> loaded,
  List<FriendMessage> latest,
) {
  if (loaded.isEmpty) return List.of(latest);
  // 最新一頁最舊的一則仍比已載入的最新一則新：兩段之間可能漏了訊息。
  if (latest.isNotEmpty && latest.last.id > loaded.first.id) return null;
  final byId = {
    for (final m in loaded) m.id: m,
    for (final m in latest) m.id: m,
  };
  return byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
}

/// 重連或推播後重抓的最新一頁通話 [latest] 併進已載入的 [loaded]：同一通以
/// [latest] 為準（未讀狀態可能變了），其餘保留，新到舊。訊息接不起來而整頁
/// 替換時（[mergeLatestMessages] 回 null），通話也改用 [latest] 整份替換。
List<FriendCall> mergeLatestCalls(
  List<FriendCall> loaded,
  List<FriendCall> latest,
) {
  final byId = {
    for (final c in loaded) c.id: c,
    for (final c in latest) c.id: c,
  };
  return byId.values.toList()..sort(compareCallsNewestFirst);
}

/// 通話新到舊；同一秒依 id。
int compareCallsNewestFirst(FriendCall a, FriendCall b) {
  final byTime = b.createdAt.compareTo(a.createdAt);
  return byTime != 0 ? byTime : b.id.compareTo(a.id);
}
