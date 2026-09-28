// 點好友相關通知後導到對應畫面（main.dart 註冊給 FcmService.onFriendPushTapped）。
//   friend_request → 好友邀請頁
//   friend_message → 與對方的聊天室（已在最上層就重載，不重複疊頁）
//   friend_accepted／羈絆展示 → 對方公開頁
// payload 只帶 uid，聊天室與公開頁要的暱稱、好友碼由好友列表查；查不到（已不是
// 好友或查詢失敗）就導到好友邀請頁，不報錯。

import 'package:flutter/material.dart';

import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../chat/chat_screen.dart';
import 'friend_requests_screen.dart';
import 'public_profile_screen.dart';

Future<void> openFriendPush(NavigatorState nav, String type, int uid) async {
  // 只有聊天室就在最上層才算「已開著」。它可能被通話、響鈴畫面蓋住，
  // 那時 pop 回聊天室會拆掉通話，改為照常疊一頁。
  if (type == 'friend_message' &&
      _topRouteName(nav) == ChatScreen.routeNameFor(uid)) {
    ChatScreen.refreshIfOpen(uid);
    return;
  }
  if (type == 'friend_request') {
    _openRequests(nav);
    return;
  }

  Friendship? friend;
  try {
    friend = await FriendService.findFriend(uid);
  } catch (e) {
    debugPrint('openFriendPush: 查詢好友失敗：$e');
  }
  if (!nav.mounted) return;
  if (friend == null) {
    _openRequests(nav);
    return;
  }
  final friendCode = friend.friendCode;
  if (type == 'friend_message') {
    nav.push(
      ChatScreen.route(
        partnerUid: friend.uid,
        partnerNickname: friend.nickname,
        partnerAvatarUrl: friend.avatarUrl,
        avatarId: friend.avatarId,
        frameId: friend.frameId,
        friendCode: friendCode,
      ),
    );
    return;
  }
  if (friendCode == null) {
    _openRequests(nav);
    return;
  }
  nav.push(
    MaterialPageRoute(
      builder: (_) => PublicProfileScreen(friendCode: friendCode),
    ),
  );
}

/// 最上層 route 的名稱。popUntil 的 predicate 對最上層立刻回 true，不會 pop 任何頁。
String? _topRouteName(NavigatorState nav) {
  String? name;
  nav.popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}

void _openRequests(NavigatorState nav) {
  nav.push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
}
