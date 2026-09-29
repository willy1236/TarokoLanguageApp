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
  final int unreadCount;
  final ConversationPreview? lastMessage;

  const Conversation({
    this.nickname,
    required this.friendCode,
    this.avatarUrl,
    this.avatarId,
    this.frameId,
    required this.unreadCount,
    this.lastMessage,
  });

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
