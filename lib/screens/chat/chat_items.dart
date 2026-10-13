// 聊天室清單要畫的項目：訊息、通話紀錄與換日分隔。清單是 reverse 的
// ListView，項目也照新到舊排，index 0 在畫面最下方。

import '../../core/utils/date_format.dart';
import '../../models/friend_message_model.dart';

sealed class ChatItem {
  const ChatItem();
}

class ChatMessageItem extends ChatItem {
  final FriendMessage message;
  const ChatMessageItem(this.message);
}

class ChatCallItem extends ChatItem {
  final FriendCall call;
  const ChatCallItem(this.call);
}

/// 畫在 [day] 那天第一則（最舊一則）的上方。
class ChatDayDivider extends ChatItem {
  final DateTime day;
  const ChatDayDivider(this.day);
}

/// 訊息與通話依 `createdAt` 合併成新到舊；同一秒訊息排在較新那側，同類依 id。
/// 相鄰兩項不同天時，在較新那項之後（畫面上方）插分隔；最舊一項上方的分隔
/// 只在 [reachedOldest]（已載到最早）時插，否則往上載入的下一頁可能還有
/// 同一天的項目，會重複出現同一天。
List<ChatItem> buildChatItems(
  List<FriendMessage> messages,
  List<FriendCall> calls, {
  required bool reachedOldest,
}) {
  final entries = <ChatItem>[
    for (final m in messages) ChatMessageItem(m),
    for (final c in calls) ChatCallItem(c),
  ]..sort(_newestFirst);
  final items = <ChatItem>[];
  for (var i = 0; i < entries.length; i++) {
    final at = _createdAt(entries[i]);
    items.add(entries[i]);
    final isOldest = i == entries.length - 1;
    if (isOldest
        ? reachedOldest
        : !isSameLocalDay(at, _createdAt(entries[i + 1]))) {
      items.add(ChatDayDivider(at));
    }
  }
  return items;
}

DateTime _createdAt(ChatItem item) => switch (item) {
  ChatMessageItem(:final message) => message.createdAt,
  ChatCallItem(:final call) => call.createdAt,
  ChatDayDivider(:final day) => day,
};

int _newestFirst(ChatItem a, ChatItem b) {
  final byTime = _createdAt(b).compareTo(_createdAt(a));
  if (byTime != 0) return byTime;
  return switch ((a, b)) {
    (ChatMessageItem(message: final x), ChatMessageItem(message: final y)) =>
      y.id.compareTo(x.id),
    (ChatCallItem(call: final x), ChatCallItem(call: final y)) =>
      y.id.compareTo(x.id),
    (ChatMessageItem(), _) => -1,
    _ => 1,
  };
}

/// 通話泡泡的文字：「視訊通話 05:32」（滿 1 小時「1:02:03」）、「已取消」、
/// 「未接視訊通話」、「已拒接」。
String callLabel(FriendCall call) => switch (call.kind) {
  FriendCallKind.completed =>
    '視訊通話 ${formatCallDuration(call.durationSec ?? 0)}',
  FriendCallKind.cancelled => '已取消',
  FriendCallKind.missed => '未接視訊通話',
  FriendCallKind.declined => '已拒接',
};

/// 通話秒數轉「分:秒」，滿 1 小時為「時:分:秒」。
String formatCallDuration(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
