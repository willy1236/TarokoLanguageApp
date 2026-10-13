// 文化頁影音、文章的分類篩選列跟著後端分類清單走（T-23）。
// 取代的人工重測：「後台新增或改名一個文章／影音分類，App 文化頁的篩選列出現新分類、
//   點下去只列該分類；沒有內容的分類不出現；分類 API 掛掉時篩選列只剩『全部』、
//   卡片名稱照舊；再點一次底部分頁會重抓分類」。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';

import 'package:flutter_application_1/screens/culture/culture_screen.dart';
import 'package:flutter_application_1/screens/culture/widgets/culture_cards.dart';
import 'package:flutter_application_1/services/category_service.dart';

import '../../helpers/flow_test_helpers.dart';
import '../../helpers/widget_test_helpers.dart';

Map<String, dynamic> _cat(String value, String label, int sort, int count) => {
  'value': value,
  'label': label,
  'sort_order': sort,
  'count': count,
};

/// 後端新增的「族語」（value 本身是中文）排在最前面，「舊分類」已經沒有內容。
List<Map<String, dynamic>> _categories() => [
  _cat('族語', '族語教學', 5, 2),
  _cat('cultural', '文化紀錄', 20, 5),
  _cat('old', '舊分類', 30, 0),
  _cat('other', '其他', 1000, 1),
];

// 只回一則，精選輪播不會自動翻頁、留下 Timer。
Map<String, dynamic> _videos(String category) => {
  'videos': [
    {'id': 1, 'title': '影片一', 'category': category},
  ],
};

Map<String, dynamic> _articles(String category) => {
  'articles': [
    {'id': 1, 'title': '文章一', 'category': category},
  ],
};

class _Host extends StatefulWidget {
  final int tabIndex;
  final ChangeNotifier reselect;

  const _Host({required this.tabIndex, required this.reselect});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool active = true;

  void setActive(bool value) => setState(() => active = value);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: CultureScreen(
        cultureTabIndex: widget.tabIndex,
        reselectSignal: widget.reselect,
        active: active,
      ),
    ),
  );
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late _Signal reselect;

  setUp(() {
    stubCommonChannels();
    resetGlobals();
    CategoryService.reset();
    requests = [];
    reselect = _Signal();
  });

  tearDown(() {
    restoreHttp();
    resetGlobals();
    CategoryService.reset();
  });

  /// [categories] 每次請求時才呼叫，測試途中可以換掉分類清單；回 null 表示分類 API 失敗。
  /// 文章與影音的分類 API 回同一份。
  void install({
    List<Map<String, dynamic>>? Function()? categories,
    String itemCategory = 'education',
  }) {
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/api/videos':
          return jsonResponse(_videos(itemCategory));
        case '/api/articles':
          return jsonResponse(_articles(itemCategory));
        case '/api/videos/categories':
        case '/api/articles/categories':
          final list = (categories ?? _categories)();
          return list == null
              ? errorResponse('INTERNAL', status: 500)
              : jsonResponse({'categories': list});
      }
      fail('測試沒有為 ${r.url.path} 準備假回應');
    });
  }

  Future<void> pumpScreen(WidgetTester tester, {int tabIndex = 0}) async {
    usePhoneSurface(tester, size: const Size(414, 2000));
    await tester.pumpWidget(_Host(tabIndex: tabIndex, reselect: reselect));
    await pumpFrames(tester, times: 10);
  }

  /// 目前畫面上（可見那一頁）篩選列的文字。chip 在同一個 Row 裡，樹的順序就是左到右。
  List<String> chipLabels(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(CultureChipsRow).hitTestable(),
        matching: find.byType(Text),
      ),
    ))
      t.data!,
  ];

  Finder chip(String label) => find.descendant(
    of: find.byType(CultureChipsRow).hitTestable(),
    matching: find.text(label),
  );

  List<String?> listCategories(String path) => [
    for (final r in requests)
      if (r.url.path == path) r.url.queryParameters['category'],
  ];

  int categoryCalls(String path) =>
      requests.where((r) => r.url.path == path).length;

  Future<void> teardownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  for (final (tabIndex, name, listPath, catPath) in [
    (0, '影音', '/api/videos', '/api/videos/categories'),
    (1, '文章', '/api/articles', '/api/articles/categories'),
  ]) {
    group(name, () {
      testWidgets('第一顆是「全部」，其後照後端順序，沒有內容的分類不顯示', (tester) async {
        install();
        await pumpScreen(tester, tabIndex: tabIndex);

        expect(chipLabels(tester), ['全部', '族語教學', '文化紀錄', '其他']);
        await teardownScreen(tester);
      });

      testWidgets('點分類帶 category=<value>，value 是中文也照送', (tester) async {
        install();
        await pumpScreen(tester, tabIndex: tabIndex);
        expect(listCategories(listPath).last, isNull);

        await tester.tap(chip('族語教學'));
        await pumpFrames(tester, times: 10);
        expect(listCategories(listPath).last, '族語');

        await tester.tap(chip('全部'));
        await pumpFrames(tester, times: 10);
        expect(listCategories(listPath).last, isNull);
        await teardownScreen(tester);
      });

      testWidgets('分類 API 失敗時只有「全部」，卡片名稱照內建對照', (tester) async {
        install(categories: () => null);
        await pumpScreen(tester, tabIndex: tabIndex);

        expect(chipLabels(tester), ['全部']);
        expect(find.text('教學延伸'), findsWidgets);
        await teardownScreen(tester);
      });

      testWidgets('後端新增的分類，卡片顯示後端的名稱', (tester) async {
        install(itemCategory: '族語');
        await pumpScreen(tester, tabIndex: tabIndex);

        // 篩選列一顆、清單卡片一個（精選輪播的 subtitle 是另一段文字）。
        expect(find.text('族語教學').hitTestable(), findsAtLeastNWidgets(2));
        expect(find.textContaining('族語教學　|'), findsOneWidget);
        await teardownScreen(tester);
      });

      testWidgets('再次點擊底部分頁時重抓分類；切進分頁只讀快取', (tester) async {
        install();
        await pumpScreen(tester, tabIndex: tabIndex);
        expect(categoryCalls(catPath), 1);

        final host = tester.state<_HostState>(find.byType(_Host));
        host.setActive(false);
        await pumpFrames(tester);
        host.setActive(true);
        await pumpFrames(tester, times: 5);
        expect(categoryCalls(catPath), 1, reason: '切進分頁應該讀快取，不重打');

        reselect.fire();
        await pumpFrames(tester, times: 10);
        expect(categoryCalls(catPath), 2);
        await teardownScreen(tester);
      });

      testWidgets('重整後選中的分類不在篩選列了，自動切回「全部」並重查', (tester) async {
        var categories = _categories();
        install(categories: () => categories);
        await pumpScreen(tester, tabIndex: tabIndex);

        await tester.tap(chip('族語教學'));
        await pumpFrames(tester, times: 10);
        expect(listCategories(listPath).last, '族語');

        categories = [_cat('cultural', '文化紀錄', 20, 5)];
        reselect.fire();
        await pumpFrames(tester, times: 10);

        expect(chipLabels(tester), ['全部', '文化紀錄']);
        expect(listCategories(listPath).last, isNull);
        await teardownScreen(tester);
      });

      testWidgets('重抓失敗時保留上次的篩選列與選擇', (tester) async {
        var fail = false;
        install(categories: () => fail ? null : _categories());
        await pumpScreen(tester, tabIndex: tabIndex);

        await tester.tap(chip('文化紀錄'));
        await pumpFrames(tester, times: 10);

        fail = true;
        reselect.fire();
        await pumpFrames(tester, times: 10);

        expect(chipLabels(tester), ['全部', '族語教學', '文化紀錄', '其他']);
        expect(listCategories(listPath).last, 'cultural');
        await teardownScreen(tester);
      });
    });
  }
}
