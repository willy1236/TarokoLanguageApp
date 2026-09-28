// 點活動提醒、論壇回覆通知後導到對應詳情頁（main.dart 註冊給 FcmService）。
//
// 目標頁就是最上層的整頁（上面只蓋著 dialog 也算）時就地重載，否則照常疊一份
// 新的。不 pop 回已開著的那份：它可能被通話、響鈴畫面蓋住，pop 會拆掉通話。
// 判斷方式與私訊通知（friend_push_navigation.dart）相同。

import 'package:flutter/widgets.dart';

import '../core/navigation/route_stack.dart';
import 'events/event_detail_screen.dart';
import 'forum/forum_detail_screen.dart';

/// 點活動提醒／取消通知。
void openEventPush(RouteStack routes, int eventId) {
  final top = routes.topPage;
  if (top != null &&
      top.settings.name == EventDetailScreen.routeNameFor(eventId)) {
    EventDetailScreen.refreshRoute(top);
    return;
  }
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openEventPush: Navigator 尚未掛上，導頁被忽略');
    return;
  }
  nav.push(EventDetailScreen.route(eventId));
}

/// 點論壇回覆通知。
void openForumReplyPush(RouteStack routes, int postId) {
  final top = routes.topPage;
  if (top != null &&
      top.settings.name == ForumDetailScreen.routeNameFor(postId)) {
    ForumDetailScreen.refreshRoute(top);
    return;
  }
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openForumReplyPush: Navigator 尚未掛上，導頁被忽略');
    return;
  }
  nav.push(ForumDetailScreen.route(postId: postId));
}

/// 前景收到論壇回覆推播：人正看著該貼文（最上層的整頁）時改在頁內提示並回傳
/// true；貼文被別的頁蓋住或沒開著時回傳 false，由呼叫端照常彈通知。
bool showForumReplyInPage(RouteStack routes, int postId, String type) {
  final top = routes.topPage;
  if (top == null ||
      top.settings.name != ForumDetailScreen.routeNameFor(postId)) {
    return false;
  }
  return ForumDetailScreen.notifyNewReply(top, type);
}
