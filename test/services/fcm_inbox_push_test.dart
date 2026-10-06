// 收件匣相關推播：payload 依 收件匣與申訴.md §0、§4.2、§5.1 與
// 內部管理.md §8.7.1 手寫。
// 審核推播帶 case_id 開處置詳情、帶 inbox_id 標已讀；公告推播開收件匣公告分頁；
// 申訴成立解除停權時解除唯讀；收件匣類推播一到就重抓未讀數。

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/main.dart'
    show navigatorKey, scaffoldMessengerKey;
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/fcm_service.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

RemoteMessage _moderation(Map<String, dynamic> extra) => RemoteMessage(
  data: {'type': 'moderation', ...extra},
  notification: const RemoteNotification(title: '違規已確認', body: '第 1 次違規'),
);

Widget _app() => MaterialApp(
  navigatorKey: navigatorKey,
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const Scaffold(body: SizedBox()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;
  late List<int> openedCases;
  late List<int> openedPosts;
  late List<int?> openedComments;
  late List<String> openedInbox;

  setUp(() {
    stubCommonChannels();
    seen = [];
    openedCases = [];
    openedPosts = [];
    openedComments = [];
    openedInbox = [];
    FcmService.onModerationCaseTapped = openedCases.add;
    FcmService.onForumReplyTapped = (postId, commentId) {
      openedPosts.add(postId);
      openedComments.add(commentId);
    };
    FcmService.onInboxTapped = openedInbox.add;
    installMockClient({
      '/api/inbox/read': {'ok': true, 'marked': 1},
      '/api/notifications/summary': {
        'inbox': {'moderation': 1, 'total': 1},
        'total': 1,
      },
      '/api/me': {'uid': 1, 'created_at': '2026-01-01T00:00:00Z'},
    }, onRequest: seen.add);
  });

  tearDown(() {
    restoreHttp();
    FcmService.onModerationCaseTapped = null;
    FcmService.onForumReplyTapped = null;
    FcmService.onInboxTapped = null;
    accountLockController.setLocked(false);
    NotificationSummaryService.clear();
    UserService.clearCache();
  });

  List<Object?> readBodies() => [
    for (final r in seen.where((r) => r.url.path == '/api/inbox/read'))
      jsonDecode(r.body),
  ];

  int summaryRequests() =>
      seen.where((r) => r.url.path == '/api/notifications/summary').length;

  test('解析 inbox_id 與 case_id：都是字串，缺少或不是數字回 null', () {
    expect(FcmService.parseInboxId({'inbox_id': '901'}), 901);
    expect(FcmService.parseInboxId({}), isNull);
    expect(FcmService.parseInboxId({'inbox_id': 'x'}), isNull);
    expect(
      FcmService.parseModerationCaseId({'type': 'moderation', 'case_id': '31'}),
      31,
    );
    expect(FcmService.parseModerationCaseId({'type': 'moderation'}), isNull);
    // 別種推播就算帶了 case_id 也不算。
    expect(
      FcmService.parseModerationCaseId({'type': 'reply_post', 'case_id': '31'}),
      isNull,
    );
  });

  testWidgets('背景點審核推播：有 case_id 開處置詳情並標已讀，不彈對話框', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleOpenedMessage(
      _moderation({
        'action': 'case_confirmed',
        'case_id': '31',
        'inbox_id': '901',
      }),
    );
    await tester.pumpAndSettle();

    expect(openedCases, [31]);
    expect(readBodies(), [
      {
        'ids': [901],
      },
    ]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('背景點審核推播：沒有 case_id 照舊彈說明對話框，有 inbox_id 仍標已讀', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleOpenedMessage(
      _moderation({'action': 'mute_lifted', 'inbox_id': '902'}),
    );
    await tester.pumpAndSettle();

    expect(openedCases, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('查看詳情'), findsNothing);
    expect(readBodies(), [
      {
        'ids': [902],
      },
    ]);
  });

  testWidgets('前景收到審核推播：有 case_id 時對話框多一顆「查看詳情」，點了開詳情並標已讀', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(
      _moderation({
        'action': 'case_opened',
        'case_id': '31',
        'inbox_id': '901',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('第 1 次違規'), findsOneWidget);
    expect(openedCases, isEmpty);

    await tester.tap(find.text('查看詳情'));
    await tester.pumpAndSettle();

    expect(openedCases, [31]);
    expect(readBodies(), [
      {
        'ids': [901],
      },
    ]);
  });

  testWidgets('前景審核對話框按「我知道了」：不開詳情，但標已讀', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(
      _moderation({
        'action': 'case_opened',
        'case_id': '31',
        'inbox_id': '901',
      }),
    );
    await tester.pumpAndSettle();
    expect(readBodies(), isEmpty);

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    expect(openedCases, isEmpty);
    expect(readBodies(), [
      {
        'ids': [901],
      },
    ]);
  });

  testWidgets('背景點論壇回覆推播：照舊開貼文，帶 inbox_id 時一併標已讀', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleOpenedMessage(
      const RemoteMessage(
        data: {
          'type': 'reply_post',
          'post_id': '13',
          'comment_id': '8',
          'inbox_id': '6',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(openedPosts, [13]);
    expect(readBodies(), [
      {
        'ids': [6],
      },
    ]);

    seen.clear();
    FcmService.handleOpenedMessage(
      const RemoteMessage(data: {'type': 'reply_post', 'post_id': '14'}),
    );
    await tester.pumpAndSettle();

    expect(openedPosts, [13, 14]);
    // 帶 comment_id 的捲到那則；舊推播沒帶就停在頂端。
    expect(openedComments, [8, null]);
    expect(readBodies(), isEmpty);
  });

  test('解析論壇回覆推播：comment_id 是字串，缺少或不是數字為 null', () {
    expect(
      FcmService.parseForumPayload({
        'type': 'reply_comment',
        'post_id': '13',
        'comment_id': '8',
      }),
      (postId: 13, type: 'reply_comment', commentId: 8),
    );
    expect(
      FcmService.parseForumPayload({'type': 'reply_post', 'post_id': '13'}),
      (postId: 13, type: 'reply_post', commentId: null),
    );
    expect(
      FcmService.parseForumPayload({'type': 'reply_post', 'post_id': 'x'}),
      isNull,
    );
    expect(FcmService.parseForumPayload({'type': 'announcement'}), isNull);
  });

  test('論壇本機通知 payload：新格式來回一致，舊格式仍讀得懂', () {
    for (final (inboxId, commentId) in [
      (6, 8),
      (null, 8),
      (6, null),
      (null, null),
    ]) {
      final payload = FcmService.forumNotificationPayload(
        13,
        inboxId: inboxId,
        commentId: commentId,
      );
      expect(FcmService.parseForumNotificationPayload(payload), (
        postId: 13,
        inboxId: inboxId,
        commentId: commentId,
      ), reason: payload);
    }
    expect(FcmService.parseForumNotificationPayload('forum:13'), (
      postId: 13,
      inboxId: null,
      commentId: null,
    ));
    expect(FcmService.parseForumNotificationPayload('forum:13:6'), (
      postId: 13,
      inboxId: 6,
      commentId: null,
    ));
    expect(FcmService.parseForumNotificationPayload('forum:x:6'), isNull);
    expect(FcmService.parseForumNotificationPayload('42'), isNull);
  });

  testWidgets('點公告推播：開收件匣的公告分頁', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleOpenedMessage(
      const RemoteMessage(
        data: {'type': 'announcement', 'announcement_id': '3'},
      ),
    );
    await tester.pumpAndSettle();

    expect(openedInbox, ['announcement']);
  });

  testWidgets('申訴成立且解除停權：解除唯讀並重抓 /api/me', (tester) async {
    accountLockController.setLocked(true);
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(
      _moderation({
        'action': 'appeal_accepted',
        'case_id': '31',
        'account_unlocked': 'true',
      }),
    );
    await tester.pumpAndSettle();

    expect(accountLockController.locked, isFalse);
    expect(seen.where((r) => r.url.path == '/api/me'), hasLength(1));
  });

  testWidgets('申訴駁回：只顯示通知，唯讀狀態不變', (tester) async {
    accountLockController.setLocked(true);
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(
      _moderation({'action': 'appeal_rejected', 'case_id': '31'}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(accountLockController.locked, isTrue);
    expect(seen.where((r) => r.url.path == '/api/me'), isEmpty);
  });

  testWidgets('收件匣類推播一到就重抓未讀數；好友來電這類不屬於收件匣的不重抓', (tester) async {
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(
      _moderation({'action': 'case_opened', 'case_id': '31'}),
    );
    await tester.pumpAndSettle();
    expect(summaryRequests(), 1);
    expect(NotificationSummaryService.notifier.value.inbox.moderation, 1);

    FcmService.handleForegroundMessage(
      const RemoteMessage(data: {'type': 'friend_call_ended', 'call_id': '1'}),
    );
    await tester.pumpAndSettle();
    expect(summaryRequests(), 1);
  });
}
