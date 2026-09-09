// 好友/聊天/通話服務。Stage 2 先加公開個人檔案查詢，Stage 3 加好友關係與封鎖；
// 通話/聊天端點在後續階段（Stage 5/6）陸續擴充於此檔案。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/friend_model.dart';
import '../models/public_profile_model.dart';

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
}
