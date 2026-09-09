// 好友/聊天/通話服務。Stage 2 先加公開個人檔案查詢，Stage 3 加好友關係與封鎖；
// 通話/聊天端點在後續階段（Stage 5/6）陸續擴充於此檔案。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/friend_message_model.dart';
import '../models/friend_model.dart';
import '../models/public_profile_model.dart';

class ChatMessagePage {
  final List<FriendMessage> messages;
  final int? nextCursor;

  const ChatMessagePage({required this.messages, this.nextCursor});
}

class FriendService {
  static Future<PublicProfile> getPublicProfile(String friendCode) async {
    final data = await ApiClient.get(ApiConfig.publicProfile(friendCode));
    return PublicProfile.fromJson(data);
  }

  /// 送出好友邀請。用好友碼（公開檔案「加好友」）或 uid（通話中「加好友」）擇一。
  /// 回傳後端實際狀態：'pending'（已送出）或 'accepted'（對方先前已邀請我，互相邀請即成立）。
  static Future<String> sendRequest({String? friendCode, int? uid}) async {
    final data = await ApiClient.post(ApiConfig.friendRequests, {
      if (friendCode != null) 'friend_code': friendCode,
      if (uid != null) 'uid': uid,
    });
    return data['status'] as String? ?? 'pending';
  }

  static Future<List<FriendRequest>> getIncomingRequests() async {
    final data = await ApiClient.get(ApiConfig.friendRequests);
    return ApiClient.unwrapList(data, 'requests')
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> acceptRequest(int uid) async {
    await ApiClient.post(ApiConfig.friendRequestAccept(uid));
  }

  static Future<void> declineRequest(int uid) async {
    await ApiClient.post(ApiConfig.friendRequestDecline(uid));
  }

  static Future<List<Friendship>> getFriends() async {
    final data = await ApiClient.get(ApiConfig.friends);
    return ApiClient.unwrapList(data, 'friends')
        .map((e) => Friendship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 解除好友，或取消我送出的邀請（後端同一個端點依現況處理）。
  static Future<void> removeFriend(int uid) async {
    await ApiClient.delete(ApiConfig.friendDetail(uid));
  }

  static Future<void> blockUser(int uid) async {
    await ApiClient.post(ApiConfig.friendBlocks, {'uid': uid});
  }

  static Future<void> unblockUser(int uid) async {
    await ApiClient.delete(ApiConfig.friendBlockDetail(uid));
  }

  static Future<List<BlockedUser>> getBlockedUsers() async {
    final data = await ApiClient.get(ApiConfig.friendBlocks);
    return ApiClient.unwrapList(data, 'blocks')
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 同意展示與此好友的羈絆（雙方皆同意才會出現在雙方公開檔案上）。
  static Future<Showcase> setShowcase(int uid) async {
    final data = await ApiClient.post(ApiConfig.friendShowcase(uid));
    return Showcase.fromJson(data);
  }

  /// 單方撤回展示同意，不需對方確認。
  static Future<void> unsetShowcase(int uid) async {
    await ApiClient.delete(ApiConfig.friendShowcase(uid));
  }

  static Future<FriendMessage> sendMessage(int uid, String body) async {
    final data = await ApiClient.post(ApiConfig.friendMessagesSend(uid), {'body': body});
    return FriendMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  static Future<List<Conversation>> getConversations() async {
    final data = await ApiClient.get(ApiConfig.friendConversations);
    return ApiClient.unwrapList(data, 'conversations')
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 依 cursor（訊息 id）往舊訊息分頁；cursor 為 null 取最新一頁。
  static Future<ChatMessagePage> getMessages(int uid, {int? cursor, int limit = 30}) async {
    final data = await ApiClient.get(
      ApiConfig.friendMessages(uid),
      query: {'limit': '$limit', if (cursor != null) 'cursor': '$cursor'},
    );
    final messages = ApiClient.unwrapList(data, 'messages')
        .map((e) => FriendMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChatMessagePage(messages: messages, nextCursor: (data['next_cursor'] as num?)?.toInt());
  }

  static Future<int> markRead(int uid) async {
    final data = await ApiClient.post(ApiConfig.friendMessagesRead(uid));
    return (data['marked'] as num?)?.toInt() ?? 0;
  }

  static Future<void> reportMessage(int id, String reason) async {
    await ApiClient.post(ApiConfig.friendMessageReport(id), {'reason': reason});
  }
}
