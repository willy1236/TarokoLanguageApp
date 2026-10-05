// 貼文詳情的留言列表：本地插入、分頁「載入更多」、整頁重載交錯時，
// 留言不重複、不亂序，過期的請求結果不會接到新列表上；停在頁內收到回覆推播時，
// 浮出「有新回覆」提示，點了才整頁重載。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';

import '../helpers/widget_test_helpers.dart';

const _postId = 7;

Map<String, dynamic> _postJson({int commentCount = 0}) => {
  'id': _postId,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '貼文',
  'body': '內文',
  'like_count': 0,
  'comment_count': commentCount,
  'is_pinned': false,
  'is_liked': false,
  'is_bookmarked': false,
  'images': <String>[],
  'tags': <Map<String, dynamic>>[],
  'created_at': '2026-08-01T11:00:00.000Z',
  'updated_at': '2026-08-01T11:00:00.000Z',
  'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
};

Map<String, dynamic> _commentJson(int id, {int? parent}) => {
  'id': id,
  'post_id': _postId,
  'parent_comment_id': parent,
  'body': '留言$id',
  'like_count': 0,
  'is_liked': false,
  'is_deleted': false,
  'created_at': '2026-08-01T11:00:00.000Z',
  'author': {'uid': 9, 'display_name': 'Yudaw', 'avatar_url': null},
};

/// 照後端規則分頁的假論壇：由舊到新、每頁 [pageSize] 則第一層留言，
/// 回覆跟著所屬的第一層留言同頁回來。游標是不透明字串（`after:<id>`），
/// App 自己用留言 id 組出來的游標對不上，會被當成第一頁。
class _FakeForum {
  _FakeForum(this.roots);

  final List<int> roots;
  final Map<int, int> replyParent = {};
  static const pageSize = 2;
  int nextId = 100;

  /// 讓指定請求晚點回應，用來重現競態。回傳 null 代表立即回應。
  Future<void>? Function(Uri url)? holdFor;
  final List<Uri> commentRequests = [];
  int postRequests = 0;
  int _inFlight = 0;
  int maxInFlight = 0;

  static String cursorAfter(int id) => 'after:$id';

  Map<String, dynamic> page(int? cursor) {
    final sorted = [...roots]..sort();
    final after = sorted.where((id) => cursor == null || id > cursor).toList();
    final slice = after.take(pageSize).toList();
    final hasMore = after.length > slice.length;
    return {
      'comments': [for (final id in slice) _commentJson(id)],
      'replies': [
        for (final e in replyParent.entries)
          if (slice.contains(e.value)) _commentJson(e.key, parent: e.value),
      ],
      'page_info': {
        'next_cursor': hasMore ? cursorAfter(slice.last) : null,
        'has_more': hasMore,
      },
    };
  }

  MockClient client() => MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/comments') && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = nextId++;
      final parent = body['parent_comment_id'] as int?;
      if (parent == null) {
        roots.add(id);
      } else {
        replyParent[id] = parent;
      }
      return jsonResponse({'comment': _commentJson(id, parent: parent)});
    }
    if (path.endsWith('/comments')) {
      commentRequests.add(request.url);
      _inFlight++;
      if (_inFlight > maxInFlight) maxInFlight = _inFlight;
      await holdFor?.call(request.url);
      _inFlight--;
      final raw = request.url.queryParameters['cursor'];
      final cursor = raw != null && raw.startsWith('after:')
          ? int.parse(raw.substring('after:'.length))
          : null;
      return jsonResponse(page(cursor));
    }
    if (path.endsWith('/posts/$_postId')) {
      postRequests++;
      return jsonResponse({'post': _postJson(commentCount: roots.length)});
    }
    return jsonResponse({}, status: 404);
  });
}

/// 畫面上留言出現的順序（只看本測試產生的「留言N」文字）。
List<String> _visibleComments(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => RegExp(r'^留言\d+$').hasMatch(s))
    .toList();

/// 送出「捲到底」的捲動通知，觸發「載入更多」。
/// 不用真的拖曳：畫面設得夠高讓所有留言都建出來方便檢查，列表就捲不動了。
void _reachBottom(WidgetTester tester) {
  final listener = tester.widget<NotificationListener<ScrollNotification>>(
    find
        .ancestor(
          of: find.byType(ListView),
          matching: find.byType(NotificationListener<ScrollNotification>),
        )
        .first,
  );
  listener.onNotification!(
    ScrollStartNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 0,
        pixels: 0,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      ),
      context: tester.element(find.byType(ListView)),
    ),
  );
}

/// 畫面上那份詳情頁所在的 route（推播重載與頁內提示的登記 key）。
Route<dynamic> _detailRoute(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byType(ForumDetailScreen)))!;

Future<void> _scrollToBottom(WidgetTester tester) async {
  _reachBottom(tester);
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapScreen(const ForumDetailScreen(postId: _postId)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

  group('從回覆通知進來（focusCommentId）', () {
    Future<void> open(WidgetTester tester, int focus) async {
      // 畫面矮到一頁放不下：不捲就看不到後面的留言。
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapScreen(ForumDetailScreen(postId: _postId, focusCommentId: focus)),
      );
      await tester.pumpAndSettle();
    }

    bool onScreen(WidgetTester tester, String text) {
      final finder = find.text(text);
      if (finder.evaluate().isEmpty) return false;
      final rect = tester.getRect(finder);
      return rect.top >= 0 && rect.bottom <= 400;
    }

    testWidgets('留言在後面的分頁：往後載到那一頁並捲到它', (tester) async {
      final forum = _FakeForum([1, 2, 3, 4, 5, 6]);
      ApiClient.httpClient = forum.client();

      await open(tester, 5);

      expect(forum.commentRequests, hasLength(3));
      expect(onScreen(tester, '留言5'), isTrue);
    });

    testWidgets('回覆掛在第一層留言下，也捲得到', (tester) async {
      final forum = _FakeForum([1, 2, 3, 4])..replyParent[50] = 4;
      ApiClient.httpClient = forum.client();

      await open(tester, 50);

      expect(onScreen(tester, '留言50'), isTrue);
    });

    testWidgets('頁面開著時點了另一則回覆的通知：重載並捲到新的那則', (tester) async {
      final forum = _FakeForum([1, 2, 3, 4, 5, 6]);
      ApiClient.httpClient = forum.client();
      await open(tester, 1);
      expect(onScreen(tester, '留言6'), isFalse);

      ForumDetailScreen.refreshRoute(_detailRoute(tester), focusCommentId: 6);
      await tester.pumpAndSettle();

      expect(onScreen(tester, '留言6'), isTrue);
    });

    testWidgets('重載沒帶留言時照舊停在頂端', (tester) async {
      final forum = _FakeForum([1, 2, 3, 4, 5, 6]);
      ApiClient.httpClient = forum.client();
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapScreen(const ForumDetailScreen(postId: _postId)),
      );
      await tester.pumpAndSettle();
      final requests = forum.commentRequests.length;

      ForumDetailScreen.refreshRoute(_detailRoute(tester));
      await tester.pumpAndSettle();

      expect(forum.commentRequests, hasLength(requests + 1));
      expect(onScreen(tester, '留言1'), isTrue);
    });

    testWidgets('留言已不存在：載完可載的分頁後停在頂端，不報錯', (tester) async {
      final forum = _FakeForum([1, 2, 3]);
      ApiClient.httpClient = forum.client();

      await open(tester, 999);

      expect(forum.commentRequests, hasLength(2));
      expect(find.text('貼文'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('留言沒載完時送出第一層留言，載完後只出現一次且照時間排序', (tester) async {
    final forum = _FakeForum([1, 2, 3, 4]);
    ApiClient.httpClient = forum.client();
    await _openDetail(tester);
    expect(_visibleComments(tester), ['留言1', '留言2']);

    await tester.enterText(find.byType(TextField), '新的');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言2', '留言100']);

    await _scrollToBottom(tester);
    await _scrollToBottom(tester);
    expect(_visibleComments(tester), ['留言1', '留言2', '留言3', '留言4', '留言100']);
  });

  testWidgets('送出第二層回覆時行為不變', (tester) async {
    final forum = _FakeForum([1]);
    ApiClient.httpClient = forum.client();
    await _openDetail(tester);

    await tester.tap(find.text('回覆').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '回你');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言100']);
    expect(forum.replyParent, {100: 1});
  });

  testWidgets('「載入更多」途中整頁重載，舊的那頁不接到新列表，之後仍能載入更多', (tester) async {
    final forum = _FakeForum([1, 2, 3, 4, 5, 6]);
    ApiClient.httpClient = forum.client();
    await _openDetail(tester);

    final stale = Completer<void>();
    forum.holdFor = (url) =>
        url.queryParameters['cursor'] == 'after:2' ? stale.future : null;
    _reachBottom(tester);
    await tester.pumpAndSettle();
    expect(forum.commentRequests.last.queryParameters['cursor'], 'after:2');

    forum.holdFor = null;
    ForumDetailScreen.refreshRoute(_detailRoute(tester));
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言2']);

    // 舊的那頁晚回來：不能再接上去，也不能動到新列表的游標。
    stale.complete();
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言2']);

    await _scrollToBottom(tester);
    expect(forum.commentRequests.last.queryParameters['cursor'], 'after:2');
    expect(_visibleComments(tester), ['留言1', '留言2', '留言3', '留言4']);
  });

  group('停在頁內收到回覆推播', () {
    Finder chip(int n) => find.text('有 $n 則新回覆');

    testWidgets('浮出提示並累加數量，點了才載入新留言，提示消失', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);
      final requestsBefore = forum.commentRequests.length;

      forum.roots.addAll([2, 3]);
      expect(
        ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(chip(1), findsOneWidget);
      expect(
        ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_comment'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(chip(2), findsOneWidget);

      // 提示只是提示：沒點之前不會自己重載。
      expect(forum.commentRequests.length, requestsBefore);
      expect(_visibleComments(tester), ['留言1']);

      await tester.tap(chip(2));
      await tester.pumpAndSettle();
      expect(_visibleComments(tester), ['留言1', '留言2']);
      expect(find.textContaining('則新回覆'), findsNothing);
    });

    testWidgets('離開頁面後不再接手推播', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navKey, home: const Text('列表')),
      );
      navKey.currentState!.push(ForumDetailScreen.route(postId: _postId));
      await tester.pumpAndSettle();
      final route = _detailRoute(tester);
      ForumDetailScreen.notifyNewReply(route, 'reply_post');
      await tester.pumpAndSettle();
      expect(chip(1), findsOneWidget);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(ForumDetailScreen.notifyNewReply(route, 'reply_post'), isFalse);

      navKey.currentState!.push(ForumDetailScreen.route(postId: _postId));
      await tester.pumpAndSettle();
      expect(find.textContaining('則新回覆'), findsNothing);
    });
  });

  group('點提示一律整頁重載', () {
    Future<void> tapChip(WidgetTester tester) async {
      await tester.tap(find.textContaining('則新回覆'));
      await tester.pumpAndSettle();
    }

    testWidgets('已載完時收到回覆貼文：從第一頁重載，新留言出現在列表中', (tester) async {
      final forum = _FakeForum([1, 2]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);
      final posts = forum.postRequests;
      final comments = forum.commentRequests.length;

      forum.roots.add(3);
      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      await tester.pumpAndSettle();
      await tapChip(tester);

      expect(forum.postRequests, posts + 1);
      expect(forum.commentRequests, hasLength(comments + 1));
      expect(
        forum.commentRequests.last.queryParameters.containsKey('cursor'),
        isFalse,
      );
      expect(find.text('留言 3'), findsOneWidget);
      expect(find.textContaining('則新回覆'), findsNothing);

      await _scrollToBottom(tester);
      expect(_visibleComments(tester), ['留言1', '留言2', '留言3']);
    });

    testWidgets('重載後把新的留言數回報給列表頁', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      final reported = <int>[];
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapScreen(
          ForumDetailScreen(
            postId: _postId,
            onPostChanged: (p) => reported.add(p.commentCount),
          ),
        ),
      );
      await tester.pumpAndSettle();

      forum.roots.add(2);
      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      await tester.pumpAndSettle();
      await tapChip(tester);

      expect(reported, [2]);
    });

    testWidgets('還沒載完時收到回覆貼文：提示請使用者往下載入', (tester) async {
      final forum = _FakeForum([1, 2, 3]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);

      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      await tester.pumpAndSettle();
      expect(find.text('有 1 則新回覆，往下載入就看得到'), findsOneWidget);

      await _scrollToBottom(tester);
      expect(_visibleComments(tester), ['留言1', '留言2', '留言3']);
    });

    testWidgets('自己剛送出的留言比推播來的那則新：重載後兩則都在、各一次', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);

      forum.roots.add(101);
      forum.nextId = 102;
      await tester.enterText(find.byType(TextField), '我的');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(_visibleComments(tester), ['留言1', '留言102']);

      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      await tester.pumpAndSettle();
      await tapChip(tester);
      await _scrollToBottom(tester);
      expect(_visibleComments(tester), ['留言1', '留言101', '留言102']);
    });

    testWidgets('推播帶來的那則已被刪除：只重載一次，不會一直重試', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);
      final posts = forum.postRequests;

      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      await tester.pumpAndSettle();
      await tapChip(tester);
      await tester.pumpAndSettle();

      expect(forum.postRequests, posts + 1);
      expect(_visibleComments(tester), ['留言1']);
    });

    testWidgets('同時累積回覆貼文和回覆留言：整頁重載', (tester) async {
      final forum = _FakeForum([1]);
      ApiClient.httpClient = forum.client();
      await _openDetail(tester);
      final posts = forum.postRequests;

      forum.roots.add(2);
      forum.replyParent[3] = 1;
      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_post');
      ForumDetailScreen.notifyNewReply(_detailRoute(tester), 'reply_comment');
      await tester.pumpAndSettle();
      await tapChip(tester);

      expect(forum.postRequests, posts + 1);
      expect(_visibleComments(tester), ['留言1', '留言3', '留言2']);
    });
  });
}
