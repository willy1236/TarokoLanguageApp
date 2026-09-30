// 收件匣畫面：預選分類、點一則的去向、標已讀、全部已讀只清當前分類。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';
import 'package:flutter_application_1/screens/inbox/announcement_detail_screen.dart';
import 'package:flutter_application_1/screens/inbox/inbox_screen.dart';
import 'package:flutter_application_1/screens/moderation/moderation_case_screen.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _item(
  int id, {
  required String category,
  required String kind,
  String title = '標題',
  String? body = '內文',
  bool isRead = false,
  int? postId,
  int? commentId,
  int? eventId,
  int? caseId,
  String? imageUrl,
  Map<String, dynamic>? actor,
  String targetState = 'ok',
}) => {
  'id': id,
  'category': category,
  'kind': kind,
  'title': title,
  'body': body,
  'is_read': isRead,
  'created_at': '2026-09-30T08:00:00Z',
  'post_id': postId,
  'comment_id': commentId,
  'event_id': eventId,
  'case_id': caseId,
  'image_url': imageUrl,
  'actor': actor,
  'target_state': targetState,
};

final _reply = _item(
  1,
  category: 'forum',
  kind: 'reply_comment',
  title: '有人回覆你的留言',
  body: '求救！！',
  postId: 13,
  commentId: 8,
  actor: {'display_name': 'Kenny', 'friend_code': 'TRZUZZM9'},
);
final _removedEvent = _item(
  2,
  category: 'event',
  kind: 'event_removed',
  title: '您參加的部落走讀已下架',
  eventId: 55,
  targetState: 'removed',
);
final _reminder = _item(
  3,
  category: 'event',
  kind: 'event_reminder',
  title: '活動提醒',
  eventId: 43,
);
final _announcement = _item(
  4,
  category: 'announcement',
  kind: 'announcement',
  title: '系統維護公告',
  body: '週六凌晨維護',
);
final _role = _item(
  5,
  category: 'moderation',
  kind: 'account_role',
  title: '帳號權限已變更',
  body: '你現在是活動發起人',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;
  late List<Map<String, dynamic>> items;
  late Map<String, dynamic> unread;

  setUp(() {
    stubCommonChannels();
    seen = [];
    items = [_reply, _removedEvent, _reminder, _announcement, _role];
    unread = {
      'forum': 1,
      'event': 2,
      'moderation': 1,
      'announcement': 1,
      'total': 5,
    };
    ApiClient.httpClient = MockClient((request) async {
      seen.add(request);
      switch (request.url.path) {
        case '/api/inbox':
          final category = request.url.queryParameters['category'];
          return jsonResponse({
            'items': [
              for (final i in items)
                if (category == null || i['category'] == category) i,
            ],
            'unread': unread,
            'page_info': {'next_cursor': null, 'has_more': false},
          });
        case '/api/inbox/read':
          return jsonResponse({'ok': true, 'marked': 1});
        case '/api/notifications/summary':
          return jsonResponse({'inbox': unread, 'total': unread['total']});
        case '/api/shop/items':
          return jsonResponse({'items': []});
        case '/api/me':
          return jsonResponse({'uid': 1, 'created_at': '2026-01-01T00:00:00Z'});
      }
      return errorResponse('NOT_FOUND', status: 404);
    });
  });
  tearDown(() {
    restoreHttp();
    NotificationSummaryService.clear();
    UserService.clearCache();
  });

  Future<void> open(WidgetTester tester, {String? category}) async {
    await tester.pumpWidget(wrapScreen(InboxScreen(initialCategory: category)));
    await tester.pumpAndSettle();
  }

  List<http.Request> requests(String path) =>
      seen.where((r) => r.url.path == path).toList();

  List<Object?> readBodies() => [
    for (final r in requests('/api/inbox/read')) jsonDecode(r.body),
  ];

  testWidgets('預選分類：從活動鈴鐺進來只抓活動類，切到全部才抓全部', (tester) async {
    await open(tester, category: 'event');

    expect(requests('/api/inbox').single.url.queryParameters, {
      'category': 'event',
    });
    expect(find.text('活動提醒'), findsOneWidget);
    expect(find.text('系統維護公告'), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(requests('/api/inbox').last.url.queryParameters, isEmpty);
    expect(find.text('系統維護公告'), findsOneWidget);
  });

  testWidgets('論壇回覆顯示回覆者暱稱；點了標已讀並開貼文、帶留言 id', (tester) async {
    await open(tester, category: 'forum');

    expect(find.textContaining('Kenny', findRichText: true), findsOneWidget);
    expect(find.text('求救！！'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-unread')), findsOneWidget);

    await tester.tap(find.text('求救！！'));
    await tester.pumpAndSettle();

    expect(readBodies(), [
      {
        'ids': [1],
      },
    ]);
    final detail = tester.widget<ForumDetailScreen>(
      find.byType(ForumDetailScreen),
    );
    expect(detail.postId, 13);
    expect(detail.focusCommentId, 8);
  });

  testWidgets('活動已被下架：不開詳情頁，只提示，照樣標已讀', (tester) async {
    await open(tester, category: 'event');

    await tester.tap(find.text('您參加的部落走讀已下架'));
    await tester.pumpAndSettle();

    expect(find.text('該活動已被下架'), findsOneWidget);
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(readBodies(), [
      {
        'ids': [2],
      },
    ]);
  });

  testWidgets('活動提醒：開活動詳情', (tester) async {
    await open(tester, category: 'event');

    await tester.tap(find.text('活動提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<EventDetailScreen>(find.byType(EventDetailScreen)).eventId,
      43,
    );
  });

  testWidgets('公告：開公告內容頁，顯示標題與內文', (tester) async {
    await open(tester, category: 'announcement');

    await tester.tap(find.text('系統維護公告'));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
    expect(find.text('週六凌晨維護'), findsOneWidget);
  });

  testWidgets('帳號權限變更：只顯示內文並重抓 /api/me', (tester) async {
    await open(tester, category: 'moderation');

    await tester.tap(find.text('帳號權限已變更'));
    await tester.pumpAndSettle();

    expect(find.text('知道了'), findsOneWidget);
    expect(requests('/api/me'), hasLength(1));
  });

  testWidgets('審核通知有 case_id：開處置詳情頁', (tester) async {
    items = [
      _item(
        6,
        category: 'moderation',
        kind: 'case_confirmed',
        title: '違規已確認',
        caseId: 31,
      ),
    ];
    await open(tester, category: 'moderation');

    await tester.tap(find.text('違規已確認'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ModerationCaseScreen>(find.byType(ModerationCaseScreen))
          .caseId,
      31,
    );
  });

  testWidgets('全部已讀只清當前分類；「全部」分頁清全部', (tester) async {
    await open(tester, category: 'event');

    await tester.tap(find.text('全部已讀'));
    await tester.pumpAndSettle();
    expect(readBodies().last, {'all': true, 'category': 'event'});
    expect(find.byKey(const ValueKey('inbox-unread')), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部已讀'));
    await tester.pumpAndSettle();
    expect(readBodies().last, {'all': true});
  });

  testWidgets('已讀的那則不重複標記', (tester) async {
    items = [
      {..._announcement, 'is_read': true},
    ];
    await open(tester, category: 'announcement');

    await tester.tap(find.text('系統維護公告'));
    await tester.pumpAndSettle();

    expect(requests('/api/inbox/read'), isEmpty);
  });

  testWidgets('沒有通知時顯示空狀態，沒有未讀時「全部已讀」停用', (tester) async {
    items = [];
    unread = {'total': 0};
    await open(tester);

    expect(find.text('還沒有通知'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '全部已讀'))
          .onPressed,
      isNull,
    );
  });
}
