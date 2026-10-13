// 「已隱藏的貼文」頁（決策紀錄 A47）：列出、分頁、空狀態、錯誤重試、取消隱藏，
// 以及從詳情返回時依最後狀態決定去留（取消後又重新隱藏的要保留）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';
import 'package:flutter_application_1/screens/forum/forum_hidden_posts_screen.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _postJson(int id, {bool isHidden = true}) => {
  'id': id,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '隱藏的貼文 $id',
  'body': '內文',
  'like_count': 0,
  'comment_count': 0,
  'is_pinned': false,
  'is_liked': false,
  'is_bookmarked': false,
  'is_hidden': isHidden,
  'reported_by_me': false,
  'images': <String>[],
  'tags': <Map<String, dynamic>>[],
  'created_at': '2026-08-01T11:00:00.000Z',
  'updated_at': '2026-08-01T11:00:00.000Z',
  'author': {
    'uid': 8,
    'display_name': 'Pisaw',
    'avatar_url': null,
    'friend_code': 'AUTH2345',
  },
};

/// 假後端：隱藏清單、貼文詳情、留言、隱藏／取消隱藏。
class _FakeApi {
  _FakeApi({List<int>? ids, this.nextCursor}) : ids = ids ?? [1];

  final List<int> ids;
  final String? nextCursor;
  final Set<int> hidden = {};
  int listStatus = 200;
  int unhideStatus = 200;
  final List<String?> listCursors = [];
  final List<String> hideCalls = [];

  MockClient client() {
    hidden.addAll(ids);
    return MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/forum/hidden-posts') {
        final cursor = request.url.queryParameters['cursor'];
        listCursors.add(cursor);
        if (listStatus != 200) {
          return errorResponse('INTERNAL', status: listStatus, message: '壞了');
        }
        if (cursor != null) {
          return jsonResponse({
            'posts': [_postJson(100)],
            'next_cursor': null,
            'page_info': {'next_cursor': null, 'has_more': false},
          });
        }
        return jsonResponse({
          'posts': [for (final id in ids) _postJson(id)],
          'next_cursor': nextCursor,
          'page_info': {
            'next_cursor': nextCursor,
            'has_more': nextCursor != null,
          },
        });
      }
      final hide = RegExp(r'^/api/forum/posts/(\d+)/hide$').firstMatch(path);
      if (hide != null) {
        final id = int.parse(hide.group(1)!);
        hideCalls.add('${request.method} $id');
        if (request.method == 'DELETE') {
          if (unhideStatus != 200) {
            return errorResponse(
              'INTERNAL',
              status: unhideStatus,
              message: '取消失敗',
            );
          }
          hidden.remove(id);
          return jsonResponse({'is_hidden': false});
        }
        hidden.add(id);
        return jsonResponse({'is_hidden': true});
      }
      if (path.endsWith('/comments')) {
        return jsonResponse({
          'comments': <Object>[],
          'replies': <Object>[],
          'page_info': {'next_cursor': null, 'has_more': false},
        });
      }
      final detail = RegExp(r'^/api/forum/posts/(\d+)$').firstMatch(path);
      if (detail != null) {
        final id = int.parse(detail.group(1)!);
        return jsonResponse({
          'post': _postJson(id, isHidden: hidden.contains(id)),
        });
      }
      return http.Response('not found', 404);
    });
  }
}

Future<void> _pumpScreen(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ApiClient.httpClient = api.client();
  await tester.pumpWidget(const MaterialApp(home: ForumHiddenPostsScreen()));
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  expect(find.byType(ForumDetailScreen), findsOneWidget);
}

Future<void> _tapDetailMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _popDetail(WidgetTester tester, [Object? result]) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop(result);
  await tester.pumpAndSettle();
  expect(find.byType(ForumDetailScreen), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

  testWidgets('列出隱藏的貼文，每筆都有「取消隱藏」', (tester) async {
    final api = _FakeApi(ids: [1, 2]);
    await _pumpScreen(tester, api);

    expect(find.text('已隱藏的貼文'), findsOneWidget);
    expect(find.text('隱藏的貼文 1'), findsOneWidget);
    expect(find.text('隱藏的貼文 2'), findsOneWidget);
    expect(find.text('取消隱藏'), findsNWidgets(2));
    expect(api.listCursors, [null]);
  });

  testWidgets('沒有隱藏任何貼文時顯示空狀態', (tester) async {
    await _pumpScreen(tester, _FakeApi(ids: []));

    expect(find.text('沒有隱藏的貼文'), findsOneWidget);
    expect(find.text('在貼文的選單按「隱藏這篇貼文」，就會列在這裡。'), findsOneWidget);
  });

  testWidgets('載入失敗顯示重試，按下後重新載入', (tester) async {
    final api = _FakeApi()..listStatus = 500;
    await _pumpScreen(tester, api);
    expect(find.text('重試'), findsOneWidget);

    api.listStatus = 200;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('隱藏的貼文 1'), findsOneWidget);
  });

  testWidgets('往下捲到底會帶游標載下一頁', (tester) async {
    final api = _FakeApi(ids: List.generate(20, (i) => i + 1), nextCursor: '9');
    await _pumpScreen(tester, api);

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    expect(api.listCursors, [null, '9']);
    expect(find.text('隱藏的貼文 100', skipOffstage: false), findsOneWidget);
  });

  testWidgets('按「取消隱藏」送出 DELETE，成功後立刻移除並提示', (tester) async {
    final api = _FakeApi(ids: [1, 2]);
    await _pumpScreen(tester, api);

    await tester.tap(find.text('取消隱藏').first);
    await tester.pumpAndSettle();

    expect(api.hideCalls, ['DELETE 1']);
    expect(find.text('隱藏的貼文 1'), findsNothing);
    expect(find.text('隱藏的貼文 2'), findsOneWidget);
    expect(find.text('已取消隱藏'), findsOneWidget);
  });

  testWidgets('取消隱藏失敗時保留該筆並提示錯誤', (tester) async {
    final api = _FakeApi()..unhideStatus = 500;
    await _pumpScreen(tester, api);

    await tester.tap(find.text('取消隱藏'));
    await tester.pumpAndSettle();

    expect(find.text('隱藏的貼文 1'), findsOneWidget);
    expect(find.text('取消失敗'), findsOneWidget);
  });

  group('從詳情返回', () {
    testWidgets('詳情選單顯示「取消隱藏」；取消後返回，清單已移除該筆', (tester) async {
      final api = _FakeApi(ids: [1, 2]);
      await _pumpScreen(tester, api);

      await _openDetail(tester, '隱藏的貼文 1');
      await _tapDetailMenu(tester, '取消隱藏');
      // 取消隱藏後留在詳情頁，清單要等返回才處理。
      expect(find.byType(ForumDetailScreen), findsOneWidget);
      await _popDetail(tester);

      expect(find.text('隱藏的貼文 1'), findsNothing);
      expect(find.text('隱藏的貼文 2'), findsOneWidget);
    });

    testWidgets('詳情取消隱藏後又重新隱藏，返回時保留該筆', (tester) async {
      final api = _FakeApi(ids: [1, 2]);
      await _pumpScreen(tester, api);

      await _openDetail(tester, '隱藏的貼文 1');
      await _tapDetailMenu(tester, '取消隱藏');
      await _tapDetailMenu(tester, '隱藏這篇貼文');

      expect(find.byType(ForumDetailScreen), findsNothing);
      expect(api.hideCalls, ['DELETE 1', 'POST 1']);
      expect(find.text('隱藏的貼文 1'), findsOneWidget);
    });

    testWidgets('詳情取消隱藏後改檢舉，返回時移除該筆（隱藏紀錄已刪）', (tester) async {
      await _pumpScreen(tester, _FakeApi(ids: [1, 2]));

      await _openDetail(tester, '隱藏的貼文 1');
      await _tapDetailMenu(tester, '取消隱藏');
      // 檢舉成功同樣以 removedFromFeed 返回，這裡直接模擬，不走檢舉面板。
      await _popDetail(tester, const ForumDetailResult.removedFromFeed());

      expect(find.text('隱藏的貼文 1'), findsNothing);
      expect(find.text('隱藏的貼文 2'), findsOneWidget);
    });

    testWidgets('什麼都沒改直接返回，清單不變', (tester) async {
      await _pumpScreen(tester, _FakeApi(ids: [1, 2]));

      await _openDetail(tester, '隱藏的貼文 1');
      await _popDetail(tester);

      expect(find.text('隱藏的貼文 1'), findsOneWidget);
    });

    testWidgets('貼文已刪除時移除該筆', (tester) async {
      await _pumpScreen(tester, _FakeApi(ids: [1, 2]));

      await _openDetail(tester, '隱藏的貼文 1');
      await _popDetail(tester, const ForumDetailResult(deleted: true));

      expect(find.text('隱藏的貼文 1'), findsNothing);
    });

    testWidgets('在詳情檢舉（從動態拿掉）時保留該筆，仍在隱藏清單', (tester) async {
      await _pumpScreen(tester, _FakeApi(ids: [1, 2]));

      await _openDetail(tester, '隱藏的貼文 1');
      await _popDetail(tester, const ForumDetailResult.removedFromFeed());

      expect(find.text('隱藏的貼文 1'), findsOneWidget);
    });
  });
}
