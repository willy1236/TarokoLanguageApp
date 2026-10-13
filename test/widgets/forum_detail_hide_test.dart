// 在貼文詳情隱藏、取消隱藏貼文（決策紀錄 A47）：隱藏後回上一頁並從動態拿掉；
// 取消隱藏留在本頁並回報列表。隱藏只影響自己，後端不擋唯讀帳號，前端也不擋。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

const _postId = 7;
const _authorCode = 'AUTH2345';
const _hiddenText = '已隱藏，可在個人頁的『已隱藏的貼文』取消';

Map<String, dynamic> _postJson({required bool isHidden}) => {
  'id': _postId,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '貼文標題',
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
    'friend_code': _authorCode,
  },
};

/// 假後端：貼文、留言、隱藏。[hideStatus] 決定 POST /hide 的回應碼，
/// [hideCalls] 記下打過的隱藏請求（method）。
class _FakeApi {
  _FakeApi({this.isHidden = false});

  bool isHidden;
  int hideStatus = 200;

  /// 為 true 時隱藏請求丟 http.ClientException（手機上 ApiClient 會原樣 rethrow）。
  bool hideThrows = false;
  final List<String> hideCalls = [];

  /// 不為 null 時，隱藏請求要等它完成才回應，模擬網路慢。
  Completer<void>? hideGate;

  MockClient client() => MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/forum/posts/$_postId/hide') {
      hideCalls.add(request.method);
      await hideGate?.future;
      if (hideThrows && request.method == 'POST') {
        throw http.ClientException('connection reset');
      }
      if (request.method == 'DELETE') {
        isHidden = false;
        return jsonResponse({'is_hidden': false});
      }
      if (hideStatus == 404) {
        return errorResponse('POST_NOT_FOUND', status: 404, message: '貼文不存在');
      }
      if (hideStatus != 200) {
        return errorResponse('INTERNAL', status: hideStatus, message: 'boom');
      }
      isHidden = true;
      return jsonResponse({'is_hidden': true});
    }
    if (path.endsWith('/posts/$_postId/comments')) {
      return jsonResponse({
        'comments': <Object>[],
        'replies': <Object>[],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    }
    if (path.endsWith('/posts/$_postId')) {
      return jsonResponse({'post': _postJson(isHidden: isHidden)});
    }
    return http.Response('not found', 404);
  });
}

/// 從一個假列表頁開詳情，記下關閉時的結果與 onPostChanged 回報。
Future<void> _openDetail(
  WidgetTester tester,
  List<Object?> popped, {
  List<ForumPost>? changed,
}) async {
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
                await Navigator.of(context).push(
                  ForumDetailScreen.route(
                    postId: _postId,
                    onPostChanged: changed?.add,
                  ),
                ),
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

Future<void> _tapMenuItem(WidgetTester tester, String label) async {
  await _openMenu(tester);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
    UserService.userNotifier.value = null;
  });

  testWidgets('別人的貼文：選單有「隱藏這篇貼文」', (tester) async {
    ApiClient.httpClient = _FakeApi().client();
    await _openDetail(tester, []);

    await _openMenu(tester);

    expect(find.text('隱藏這篇貼文'), findsOneWidget);
    expect(find.text('取消隱藏'), findsNothing);
  });

  testWidgets('自己的貼文：選單沒有隱藏項目', (tester) async {
    UserService.userNotifier.value = UserModel(
      uid: 8,
      friendCode: _authorCode,
      email: 'me@example.com',
      createdAt: DateTime(2026),
    );
    ApiClient.httpClient = _FakeApi().client();
    await _openDetail(tester, []);

    await _openMenu(tester);

    expect(find.text('刪除'), findsOneWidget);
    expect(find.text('隱藏這篇貼文'), findsNothing);
    expect(find.text('取消隱藏'), findsNothing);
  });

  testWidgets('隱藏成功：提示並回上一頁，結果是「從動態拿掉」', (tester) async {
    final api = _FakeApi();
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    await _tapMenuItem(tester, '隱藏這篇貼文');

    expect(api.hideCalls, ['POST']);
    expect(find.byType(ForumDetailScreen), findsNothing);
    final result = popped.single as ForumDetailResult;
    expect(result.removedFromFeed, isTrue);
    expect(result.deleted, isFalse);
    expect(find.text(_hiddenText), findsOneWidget);
  });

  testWidgets('隱藏成功：pop 前回報 isHidden=true，列表才分得出重新隱藏', (tester) async {
    ApiClient.httpClient = _FakeApi().client();
    final changed = <ForumPost>[];
    await _openDetail(tester, [], changed: changed);

    await _tapMenuItem(tester, '隱藏這篇貼文');

    expect(changed.last.isHidden, isTrue);
  });

  testWidgets('非 ApiException 的失敗：例外照常往外丟，選單的隱藏項恢復可點', (tester) async {
    final api = _FakeApi()..hideThrows = true;
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    // 選單在這個 zone 裡開，onSelected 與 _hidePost 也跑在這裡，
    // 逸出的例外才接得到（不接的話測試框架會直接判失敗）。
    final uncaught = <Object>[];
    await runZonedGuarded(
      () => _tapMenuItem(tester, '隱藏這篇貼文'),
      (error, _) => uncaught.add(error),
    );
    await tester.pumpAndSettle();
    expect(uncaught.single, isA<http.ClientException>());
    expect(find.byType(ForumDetailScreen), findsOneWidget);

    api.hideThrows = false;
    await _openMenu(tester);
    final item = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, '隱藏這篇貼文'),
    );
    expect(item.enabled, isTrue);
    await tester.tap(find.text('隱藏這篇貼文'));
    await tester.pumpAndSettle();

    expect(api.hideCalls, ['POST', 'POST']);
    expect(popped, hasLength(1));
  });

  testWidgets('隱藏送出中：選單的隱藏項停用，只送一次、只 pop 一次', (tester) async {
    final api = _FakeApi()..hideGate = Completer<void>();
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    await _tapMenuItem(tester, '隱藏這篇貼文');
    expect(api.hideCalls, ['POST']);

    await _openMenu(tester);
    final item = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, '隱藏這篇貼文'),
    );
    expect(item.enabled, isFalse);
    await tester.tap(find.text('隱藏這篇貼文'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(api.hideCalls, ['POST']);
    // 停用的項目點了不會關選單，手動關掉再放行請求。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    api.hideGate!.complete();
    await tester.pumpAndSettle();

    expect(popped, hasLength(1));
    expect(find.text('開貼文'), findsOneWidget);
    expect(find.text(_hiddenText), findsOneWidget);
  });

  testWidgets('已隱藏的貼文：取消隱藏後留在本頁、回報列表，選單變回「隱藏這篇貼文」', (tester) async {
    final api = _FakeApi(isHidden: true);
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    final changed = <ForumPost>[];
    await _openDetail(tester, popped, changed: changed);

    await _openMenu(tester);
    expect(find.text('隱藏這篇貼文'), findsNothing);
    await tester.tap(find.text('取消隱藏'));
    await tester.pumpAndSettle();

    expect(api.hideCalls, ['DELETE']);
    expect(find.byType(ForumDetailScreen), findsOneWidget);
    expect(popped, isEmpty);
    expect(changed.single.isHidden, isFalse);
    expect(find.text('已取消隱藏'), findsOneWidget);

    await _openMenu(tester);
    expect(find.text('隱藏這篇貼文'), findsOneWidget);
    expect(find.text('取消隱藏'), findsNothing);
  });

  testWidgets('貼文已不存在（404）：提示並回上一頁，結果是「已刪除」', (tester) async {
    final api = _FakeApi()..hideStatus = 404;
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    await _tapMenuItem(tester, '隱藏這篇貼文');

    expect(find.byType(ForumDetailScreen), findsNothing);
    expect((popped.single as ForumDetailResult).deleted, isTrue);
    expect(find.text('這篇貼文已被刪除'), findsOneWidget);
  });

  testWidgets('其他錯誤：留在詳情頁並提示錯誤', (tester) async {
    final api = _FakeApi()..hideStatus = 500;
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    await _tapMenuItem(tester, '隱藏這篇貼文');

    expect(find.byType(ForumDetailScreen), findsOneWidget);
    expect(popped, isEmpty);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('唯讀帳號：選單只有隱藏，不給檢舉，按下照樣隱藏', (tester) async {
    accountLockController.setLocked(true);
    final api = _FakeApi();
    ApiClient.httpClient = api.client();
    final popped = <Object?>[];
    await _openDetail(tester, popped);

    await _openMenu(tester);
    expect(find.text('檢舉'), findsNothing);
    await tester.tap(find.text('隱藏這篇貼文'));
    await tester.pumpAndSettle();

    expect(api.hideCalls, ['POST']);
    expect((popped.single as ForumDetailResult).removedFromFeed, isTrue);
  });
}
