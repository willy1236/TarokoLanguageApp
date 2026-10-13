// 聊天室清單要畫的項目：訊息與換日分隔。清單是 reverse 的 ListView，
// 項目也照新到舊排，index 0 在畫面最下方。

import '../../core/utils/date_format.dart';
import '../../models/friend_message_model.dart';

sealed class ChatItem {
  const ChatItem();
}

class ChatMessageItem extends ChatItem {
  final FriendMessage message;
  const ChatMessageItem(this.message);
}

/// 畫在 [day] 那天第一則（最舊一則）的上方。
class ChatDayDivider extends ChatItem {
  final DateTime day;
  const ChatDayDivider(this.day);
}

/// [messages] 新到舊。相鄰兩則不同天時，在較新那則之後（畫面上方）插分隔；
/// 最舊一則上方的分隔只在 [reachedOldest]（已載到最早）時插，否則往上
/// 載入的下一頁可能還有同一天的訊息，會重複出現同一天。
List<ChatItem> buildChatItems(
  List<FriendMessage> messages, {
  required bool reachedOldest,
}) {
  final items = <ChatItem>[];
  for (var i = 0; i < messages.length; i++) {
    final at = messages[i].createdAt;
    items.add(ChatMessageItem(messages[i]));
    final isOldest = i == messages.length - 1;
    if (isOldest
        ? reachedOldest
        : !isSameLocalDay(at, messages[i + 1].createdAt)) {
      items.add(ChatDayDivider(at));
    }
  }
  return items;
}
