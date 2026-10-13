// 在貼文詳情檢舉貼文或留言：送出成功後那一筆立刻從眼前消失（決策紀錄 A47）；
// 關掉面板或送出失敗時畫面不變。檢舉過的貼文選單顯示不可點的「已檢舉」。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';

import '../helpers/widget_test_helpers.dart';

const _postId = 7;
const _successText = '已收到檢舉，這則內容不會再顯示給你';

Map<String, dynamic> _postJson({bool reportedByMe = false}) => {
  'id': _postId,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '貼文標題',
  'body': '內文',
  'like_count': 0,
  'comment_count': 0,
  'is_pinned': false,
  'is_liked': false,
  'is_bookmarked': false,
  'is_hidden': false,
  'reported_by_me': reportedByMe,
  'images': <String>[],
  'tags': <Map<String, dynamic>>[],
  'created_at': '2026-08-01T11:00:00.000Z',
  'updated_at': '2026-08-01T11:00:00.000Z',
  'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
};

/// 假後端：貼文、留言列表、檢舉。[reportStatus] 決定檢舉的回應碼，
/// [reports] 記下送出的檢舉內容。
class _FakeApi {
  _FakeApi({this.reportedByMe = false});

  final bool reportedByMe;
  int reportStatus = 201;
  final List<Map<String, dynamic>> reports = [];

  MockClient client() => MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/forum/reports') {
      reports.add(jsonDecode(request.body) as Map<String, dynamic>);
      return reportStatus == 201
          ? jsonResponse({'ok': true}, status: 201)
          : errorResponse('INTERNAL', status: reportStatus, message: 'boom');
    }
    if (path.endsWith('/posts/$_postId/comments')) {
      return jsonResponse({
        'comments': <Map<String, dynamic>>[],
        'replies': <Map<String, dynamic>>[],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    }
    if (path.endsWith('/posts/$_postId')) {
      return jsonResponse({'post': _postJson(reportedByMe: reportedByMe)});
    }
    return http.Response('not found', 404);
  });
}

/// 從一個假列表頁開詳情，記下詳情頁關閉時回報的結果。
Future<void> _openDetail(WidgetTester tester, List<Object?> popped) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped.add(
                await Navigator.of(
                  context,
                ).push(ForumDetailScreen.route(postId: _postId)),
              );
            },
            child: const Text('開貼文'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開貼文'));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, '廣告');
  await tester.pump();
  await tester.tap(find.text('送出檢舉'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

  group('檢舉貼文', () {
    testWidgets('送出成功：提示並回上一頁，結果是「從動態拿掉」', (tester) async {
      final api = _FakeApi();
      ApiClient.httpClient = api.client();
      final popped = <Object?>[];
      await _openDetail(tester, popped);

      await _openMenu(tester);
      await tester.tap(find.text('檢舉'));
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester);

      expect(api.reports, [
        {'target_type': 'post', 'target_id': _postId, 'reason': '廣告'},
      ]);
      expect(find.byType(ForumDetailScreen), findsNothing);
      expect(popped, hasLength(1));
      final result = popped.single as ForumDetailResult;
      expect(result.removedFromFeed, isTrue);
      expect(result.deleted, isFalse);
      expect(find.text(_successText), findsOneWidget);
    });

    testWidgets('沒送出就關掉面板：留在詳情頁', (tester) async {
      final api = _FakeApi();
      ApiClient.httpClient = api.client();
      final popped = <Object?>[];
      await _openDetail(tester, popped);

      await _openMenu(tester);
      await tester.tap(find.text('檢舉'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(api.reports, isEmpty);
      expect(find.byType(ForumDetailScreen), findsOneWidget);
      expect(find.text('貼文標題'), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('送出失敗：留在面板，詳情頁不關', (tester) async {
      final api = _FakeApi()..reportStatus = 500;
      ApiClient.httpClient = api.client();
      final popped = <Object?>[];
      await _openDetail(tester, popped);

      await _openMenu(tester);
      await tester.tap(find.text('檢舉'));
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester);

      expect(api.reports, hasLength(1));
      expect(find.text('送出檢舉'), findsOneWidget);
      expect(find.byType(ForumDetailScreen), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('檢舉過的貼文：內容照常顯示，選單是不可點的「已檢舉」', (tester) async {
      final api = _FakeApi(reportedByMe: true);
      ApiClient.httpClient = api.client();
      final popped = <Object?>[];
      await _openDetail(tester, popped);

      expect(find.text('貼文標題'), findsOneWidget);
      await _openMenu(tester);

      expect(find.text('檢舉'), findsNothing);
      final item = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text('已檢舉'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(item.enabled, isFalse);

      await tester.tap(find.text('已檢舉'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('送出檢舉'), findsNothing);
      expect(api.reports, isEmpty);
      expect(popped, isEmpty);
    });
  });
}
