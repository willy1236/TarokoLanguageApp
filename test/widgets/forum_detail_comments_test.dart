// 貼文詳情的留言列表：本地插入、分頁「載入更多」、整頁重載交錯時，
// 留言不重複、不亂序，過期的請求結果不會接到新列表上。
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

/// 照後端規則分頁的假論壇：`id > cursor`、由舊到新、每頁 [pageSize] 則第一層留言，
/// 回覆跟著所屬的第一層留言同頁回來。
class _FakeForum {
  _FakeForum(this.roots);

  final List<int> roots;
  final Map<int, int> replyParent = {};
  static const pageSize = 2;
  int nextId = 100;

  /// 讓指定請求晚點回應，用來重現競態。回傳 null 代表立即回應。
  Future<void>? Function(Uri url)? holdFor;
  final List<Uri> commentRequests = [];

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
      'next_cursor': hasMore ? slice.last : null,
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
      await holdFor?.call(request.url);
      final cursor = int.tryParse(request.url.queryParameters['cursor'] ?? '');
      return jsonResponse(page(cursor));
    }
    if (path.endsWith('/posts/$_postId')) {
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

Future<void> _scrollToBottom(WidgetTester tester) async {
  _reachBottom(tester);
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapScreen(const ForumDetailScreen(postId: _postId)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

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
    expect(_visibleComments(tester), [
      '留言1',
      '留言2',
      '留言3',
      '留言4',
      '留言100',
    ]);
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

  testWidgets('「載入更多」途中整頁重載，舊的那頁不接到新列表，之後仍能載入更多', (
    tester,
  ) async {
    final forum = _FakeForum([1, 2, 3, 4, 5, 6]);
    ApiClient.httpClient = forum.client();
    await _openDetail(tester);

    final stale = Completer<void>();
    forum.holdFor = (url) =>
        url.queryParameters['cursor'] == '2' ? stale.future : null;
    _reachBottom(tester);
    await tester.pumpAndSettle();
    expect(forum.commentRequests.last.queryParameters['cursor'], '2');

    forum.holdFor = null;
    ForumDetailScreen.refreshIfOpen(_postId);
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言2']);

    // 舊的那頁晚回來：不能再接上去，也不能動到新列表的游標。
    stale.complete();
    await tester.pumpAndSettle();
    expect(_visibleComments(tester), ['留言1', '留言2']);

    await _scrollToBottom(tester);
    expect(forum.commentRequests.last.queryParameters['cursor'], '2');
    expect(_visibleComments(tester), ['留言1', '留言2', '留言3', '留言4']);
  });
}
