// 點好友相關通知後導到對應畫面（main.dart 註冊給 FcmService.onFriendPushTapped）。
//   friend_request → 好友邀請頁
//   friend_message → 與對方的聊天室（已在最上層就重載，不重複疊頁）
//   friend_accepted／羈絆展示 → 對方公開頁
// payload 只帶好友碼，聊天室要的暱稱、頭像由好友列表查。私訊不論對方是不是
// 好友都開聊天室：陌生人可以先傳幾則破冰訊息（好友社交串接指南 §87），查不到
// 或查詢失敗時不帶暱稱頭像，由聊天室從訊息 API 的 partner 補上。
// 其他類型已不是好友就導到好友邀請頁，查詢失敗則不導頁、提示稍後再試。

import 'package:flutter/material.dart';

import '../../core/navigation/route_stack.dart';
import '../../main.dart' show scaffoldMessengerKey;
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../chat/chat_screen.dart';
import 'friend_requests_screen.dart';
import 'public_profile_screen.dart';

Future<void> openFriendPush(
  RouteStack routes,
  String type,
  String friendCode,
) async {
  final nav = routes.navigator;
  if (nav == null) return;
  // 只有聊天室是最上層的整頁才算「已開著」（上面只蓋著 dialog 也算）。它可能
  // 被通話、響鈴畫面蓋住，那時 pop 回聊天室會拆掉通話，改為照常疊一頁。
  final top = routes.topPage;
  if (type == 'friend_message' &&
      top != null &&
      top.settings.name == ChatScreen.routeNameFor(friendCode)) {
    ChatScreen.refreshRoute(top);
    return;
  }
  if (type == 'friend_request') {
    _openRequests(nav);
    return;
  }

  final Friendship? friend;
  try {
    friend = await FriendService.findFriend(friendCode);
  } catch (e) {
    debugPrint('openFriendPush: 查詢好友失敗：$e');
    if (type == 'friend_message') {
      if (nav.mounted) nav.push(ChatScreen.route(friendCode: friendCode));
      return;
    }
    // 查不到好友資料不代表已不是好友，不導到邀請頁，只提示稍後再試。
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('無法開啟，請稍後再試')));
    return;
  }
  if (!nav.mounted) return;
  if (type == 'friend_message' && friend == null) {
    // 陌生人的破冰私訊：直接開聊天室才看得到那則訊息。
    nav.push(ChatScreen.route(friendCode: friendCode));
    return;
  }
  if (friend == null) {
    _openRequests(nav);
    return;
  }
  if (type == 'friend_message') {
    nav.push(
      ChatScreen.route(
        friendCode: friend.friendCode,
        partnerNickname: friend.nickname,
        partnerAvatarUrl: friend.avatarUrl,
        avatarId: friend.avatarId,
        frameId: friend.frameId,
      ),
    );
    return;
  }
  final code = friend.friendCode;
  nav.push(
    MaterialPageRoute(builder: (_) => PublicProfileScreen(friendCode: code)),
  );
}

void _openRequests(NavigatorState nav) {
  nav.push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
}
