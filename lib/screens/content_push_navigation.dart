// 點活動提醒、論壇回覆、審核、官方公告通知後導到對應頁面（main.dart 註冊給 FcmService）。
//
// 目標頁就是最上層的整頁（上面只蓋著 dialog 也算）時就地重載，否則照常疊一份
// 新的。不 pop 回已開著的那份：它可能被通話、響鈴畫面蓋住，pop 會拆掉通話。
// 判斷方式與私訊通知（friend_push_navigation.dart）相同。

import 'package:flutter/widgets.dart';

import '../core/navigation/route_stack.dart';
import 'events/event_detail_screen.dart';
import 'forum/forum_detail_screen.dart';
import 'inbox/inbox_screen.dart';
import 'moderation/moderation_case_screen.dart';

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

/// 點論壇回覆通知：開貼文並捲到 [commentId] 那則留言（舊推播沒帶時停在頂端）。
void openForumReplyPush(RouteStack routes, int postId, {int? commentId}) {
  final top = routes.topPage;
  if (top != null &&
      top.settings.name == ForumDetailScreen.routeNameFor(postId)) {
    ForumDetailScreen.refreshRoute(top, focusCommentId: commentId);
    return;
  }
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openForumReplyPush: Navigator 尚未掛上，導頁被忽略');
    return;
  }
  nav.push(ForumDetailScreen.route(postId: postId, focusCommentId: commentId));
}

/// 點帶 case_id 的審核通知：開處置詳情頁；人已在那一頁就地重載，不再疊一份。
void openModerationCasePush(RouteStack routes, int caseId) {
  final top = routes.topPage;
  if (top != null &&
      top.settings.name == ModerationCaseScreen.routeNameFor(caseId)) {
    ModerationCaseScreen.refreshRoute(top);
    return;
  }
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openModerationCasePush: Navigator 尚未掛上，導頁被忽略');
    return;
  }
  nav.push(ModerationCaseScreen.route(caseId));
}

/// 點官方公告通知：開收件匣並停在 [category] 分頁。
void openInboxPush(RouteStack routes, String category) {
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openInboxPush: Navigator 尚未掛上，導頁被忽略');
    return;
  }
  nav.push(InboxScreen.route(initialCategory: category));
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
