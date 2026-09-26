// 取代的人工重測：
//   「在文化頁的文章清單挑一篇點進去，按返回，看清單有沒有整個重載、
//     原本選的分類 chip 有沒有被重設回『全部』」
//
// CultureArticleSection 沒有分頁也沒有 ScrollController，它的狀態就是
// 「已經載好的那個 Future」與「選到的分類 / 排序」（culture_article_section.dart:25-27）。
// 所以「返回後狀態還在」的可觀察證據，是它不會再打一次 /api/articles。
// 這條在 didChangeDependencies / key 被動到時最容易壞，人工才看得出來。
//
// 入口刻意直接掛 CultureArticleSection 而不是 CultureScreen：
// 後者 592 行、大量 Image.network，對這條流程沒有額外覆蓋價值。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/culture/article_detail_screen.dart';
import 'package:flutter_application_1/screens/culture/widgets/culture_article_section.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _summary({
  required int id,
  required String title,
  String category = 'education', // 刻意不用 cultural：卡片上的分類徽章也會印同樣的字，
  // 會讓「文化紀錄」這個 chip 的 finder 變得不唯一。
}) => {
  'id': id,
  'title': title,
  'summary': '摘要 $id',
  'cover_image_url': null,
  'category': category,
  'view_count': 10,
  'weekly_view_count': 3,
  'like_count': 1,
  'is_liked': false,
  'is_bookmarked': false,
  'published_at': '2026-09-01T00:00:00Z',
};

Map<String, dynamic> _list() => {
  'total': 2,
  'page': 1,
  'page_size': 20,
  'sort': 'latest',
  'articles': [
    _summary(id: 1, title: '太魯閣族的織布'),
    _summary(id: 2, title: '獵人的山林智慧'),
  ],
};

Map<String, dynamic> _detail() => {
  'id': 1,
  'title': '太魯閣族的織布',
  'category': 'cultural',
  'content_md': '# 織布\n\n這是內文。',
  'summary': '關於織布的故事',
  'like_count': 1,
  'is_liked': false,
  'is_bookmarked': false,
  'view_count': 10,
  'published_at': '2026-09-01T00:00:00Z',
};

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const Scaffold(
    body: SingleChildScrollView(
      child: CultureArticleSection(seniorMode: false),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    resetGlobals();
  });

  tearDown(() {
    restoreHttp();
    resetGlobals();
  });

  testWidgets('清單 → 詳情 → 返回，清單不會重新載入', (tester) async {
    var listCalls = 0;
    installMockClient(
      {'/api/articles': _list(), '/api/articles/1': _detail()},
      onRequest: (r) {
        if (r.url.path == '/api/articles') listCalls++;
      },
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(_app());
    await pumpFrames(tester, times: 10);

    expect(listCalls, 1);
    expect(find.text('太魯閣族的織布'), findsWidgets);

    await tester.tap(find.text('太魯閣族的織布').first);
    await pumpFrames(tester, times: 10);
    expect(find.byType(ArticleDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester, times: 10);

    expect(find.byType(ArticleDetailScreen), findsNothing);
    expect(find.text('太魯閣族的織布'), findsWidgets);
    expect(
      listCalls,
      1,
      reason:
          '返回清單時重打了 /api/articles，代表 section 的 State 沒被保留，'
          '使用者會看到清單重新轉圈圈',
    );
  });

  testWidgets('先切分類再進詳情再返回，選中的分類不會被重設', (tester) async {
    final requestedCategories = <String?>[];
    installMockClient(
      {'/api/articles': _list(), '/api/articles/1': _detail()},
      onRequest: (r) {
        if (r.url.path == '/api/articles') {
          requestedCategories.add(r.url.queryParameters['category']);
        }
      },
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(_app());
    await pumpFrames(tester, times: 10);
    expect(requestedCategories, [null], reason: '初始是「全部」，不帶 category');

    // 切到「文化紀錄」（ArticleCategory.cultural 的標籤）。
    await tester.tap(find.text('文化紀錄'));
    await pumpFrames(tester, times: 10);
    expect(requestedCategories.last, 'cultural');

    await tester.tap(find.text('太魯閣族的織布').first);
    await pumpFrames(tester, times: 10);
    expect(find.byType(ArticleDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester, times: 10);

    expect(requestedCategories, [
      null,
      'cultural',
    ], reason: '返回後不該再打一次 /api/articles，也不該退回「全部」重查');
  });
}
