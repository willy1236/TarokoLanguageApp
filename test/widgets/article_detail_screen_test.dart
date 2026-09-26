// ArticleDetailScreen（文章詳情）的畫面層測試。
//
// 這支取代的人工測試：開一篇文章、按讚／收藏、把網路關掉看會不會還原、
// 用被鎖的帳號按讚看有沒有被擋，以及下架／不存在的文章要顯示看得懂的話。
// 後面那幾種狀態人工得請後端把文章下架才測得到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/culture/article_detail_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _article({
  bool isLiked = false,
  bool isBookmarked = false,
  int likeCount = 5,
}) => {
  'id': 1,
  'title': '太魯閣族的織布',
  'category': 'culture',
  'content_md': '# 織布\n\n這是內文。',
  'summary': '關於織布的故事',
  'like_count': likeCount,
  'is_liked': isLiked,
  'is_bookmarked': isBookmarked,
  'view_count': 100,
  'published_at': '2026-09-01T00:00:00Z',
};

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const ArticleDetailScreen(articleId: 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
  });

  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
  });

  testWidgets('載入成功後顯示標題與內文', (tester) async {
    installMockClient({'/api/articles/1': _article()});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('太魯閣族的織布'), findsWidgets);
    expect(find.textContaining('這是內文'), findsWidgets);
  });

  testWidgets('文章不存在時顯示看得懂的話，而不是錯誤碼', (tester) async {
    installMockClient({
      '/api/articles/1': errorResponse(
        'ARTICLE_NOT_FOUND',
        status: 404,
        message: 'not found',
      ),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('找不到這篇文章'), findsOneWidget);
    expect(find.text('返回清單'), findsOneWidget);
  });

  testWidgets('文章已下架時顯示下架說明', (tester) async {
    installMockClient({
      '/api/articles/1': errorResponse(
        'ARTICLE_ARCHIVED',
        status: 410,
        message: 'archived',
      ),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('這篇文章已下架'), findsOneWidget);
  });

  testWidgets('按讚會樂觀更新計數，並以後端回傳的真實計數校正', (tester) async {
    installMockClient({
      '/api/articles/1': _article(isLiked: false, likeCount: 5),
      '/api/articles/1/like': {'liked': true, 'like_count': 42},
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // 後端說 42 就是 42，不是前端自己 +1 的 6。
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('按讚失敗時還原成原本的狀態', (tester) async {
    installMockClient({
      '/api/articles/1': _article(isLiked: false, likeCount: 5),
      '/api/articles/1/like': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('唯讀帳號按讚被擋，但取消讚放行', (tester) async {
    var likeCalls = 0;
    installMockClient(
      {
        '/api/articles/1': _article(isLiked: false),
        '/api/articles/1/like': {'liked': false, 'like_count': 4},
      },
      onRequest: (req) {
        if (req.url.path == '/api/articles/1/like') likeCalls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    accountLockController.setLocked(true);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.text(readOnlyMessage), findsOneWidget);
    expect(likeCalls, 0);
  });

  testWidgets('唯讀帳號仍可取消已按的讚（後端放行）', (tester) async {
    var likeCalls = 0;
    installMockClient(
      {
        '/api/articles/1': _article(isLiked: true, likeCount: 5),
        '/api/articles/1/like': {'liked': false, 'like_count': 4},
      },
      onRequest: (req) {
        if (req.url.path == '/api/articles/1/like') likeCalls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    accountLockController.setLocked(true);
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(likeCalls, 1);
    expect(find.text(readOnlyMessage), findsNothing);
  });

  testWidgets('收藏失敗時還原圖示', (tester) async {
    installMockClient({
      '/api/articles/1': _article(isBookmarked: false),
      '/api/articles/1/bookmark': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
}
