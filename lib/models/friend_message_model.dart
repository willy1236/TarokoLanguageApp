// 一對一聊天訊息與對話清單（見 Truku_backend backend/routes/friendMessages.ts）。

class FriendMessage {
  final int id;
  final int senderUid;
  final int recipientUid;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const FriendMessage({
    required this.id,
    required this.senderUid,
    required this.recipientUid,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory FriendMessage.fromJson(Map<String, dynamic> j) => FriendMessage(
    id: (j['id'] as num?)?.toInt() ?? 0,
    senderUid: (j['sender_uid'] as num?)?.toInt() ?? 0,
    recipientUid: (j['recipient_uid'] as num?)?.toInt() ?? 0,
    body: j['body'] as String? ?? '',
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    readAt: j['read_at'] == null ? null : DateTime.tryParse(j['read_at'].toString()),
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

  factory ConversationPreview.fromJson(Map<String, dynamic> j) => ConversationPreview(
    body: j['body'] as String? ?? '',
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    mine: j['mine'] as bool? ?? false,
  );
}

class Conversation {
  final int partnerUid;
  final String? nickname;
  final String? friendCode;
  final String? avatarUrl;
  final int unreadCount;
  final ConversationPreview? lastMessage;

  const Conversation({
    required this.partnerUid,
    this.nickname,
    this.friendCode,
    this.avatarUrl,
    required this.unreadCount,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    partnerUid: (j['partner_uid'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String?,
    friendCode: j['friend_code'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
    lastMessage: j['last_message'] is Map<String, dynamic>
        ? ConversationPreview.fromJson(j['last_message'] as Map<String, dynamic>)
        : null,
  );
}
