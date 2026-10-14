// 後台影片資訊欄位組（後台影片 T-01）：標題、說明、分類（影音）、相關部落。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/admin_video_meta.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_video_meta_fields.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _tribes = {
  'tribes': [
    {
      'id': 3,
      'ethnic_group': '太魯閣族',
      'name': '富世',
      'name_truku': 'Bsngan',
      'county': '花蓮縣',
      'township': '秀林鄉',
    },
    {
      'id': 5,
      'ethnic_group': '太魯閣族',
      'name': '崇德',
      'name_truku': 'Tkijig',
      'county': '花蓮縣',
      'township': '秀林鄉',
    },
  ],
};

/// 欄位組＋一顆「送出」：按下去呼叫 validate()，結果寫進 [results]。
class _Host extends StatefulWidget {
  final AdminVideoMeta? initial;
  final bool titleRequired;
  final List<bool> results;
  final void Function(AdminVideoMetaController) onController;

  const _Host({
    this.initial,
    this.titleRequired = true,
    required this.results,
    required this.onController,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final _controller = AdminVideoMetaController();

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AdminVideoMetaFields(
              initial: widget.initial,
              controller: _controller,
              titleRequired: widget.titleRequired,
            ),
            TextButton(
              onPressed: () => widget.results.add(_controller.validate()),
              child: const Text('送出'),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late List<bool> results;
  late AdminVideoMetaController controller;

  setUp(() {
    stubCommonChannels();
    calls = [];
    results = [];
    installMockClient({
      '/api/admin/categories/videos': loadFixtureMap(
        'get_api_admin_categories_videos.json',
      ),
      '/api/tribes': _tribes,
    }, onRequest: (r) => calls.add('${r.method} ${r.url.path}'));
  });
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
    CategoryService.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    AdminVideoMeta? initial,
    bool titleRequired = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _Host(
        initial: initial,
        titleRequired: titleRequired,
        results: results,
        onController: (c) => controller = c,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('送出'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCategory(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('讀影音分類清單；不預設選分類，列出「＋新增分類」', (tester) async {
    await pump(tester);
    expect(calls, contains('GET /api/admin/categories/videos'));
    expect(find.text('文化紀錄'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('文化紀錄'), findsWidgets);
    expect(find.text('＋新增分類'), findsWidgets);
  });

  testWidgets('一進來不顯示錯誤；送出時標題空白、分類未選各自顯示錯誤', (tester) async {
    await pump(tester);
    expect(find.text('標題必填'), findsNothing);
    expect(find.text('分類必填'), findsNothing);
    await submit(tester);
    expect(results, [false]);
    expect(find.text('標題必填'), findsOneWidget);
    expect(find.text('分類必填'), findsOneWidget);
  });

  testWidgets('填好標題、選分類即通過；value 去掉前後空白、沒填的說明為 null', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), ' 織布 ');
    await chooseCategory(tester, '文化紀錄');
    await submit(tester);
    expect(results, [true]);
    final v = controller.value;
    expect(v.title, '織布');
    expect(v.description, isNull);
    expect(v.category, 'cultural');
    expect(v.tribeId, isNull);
    expect(controller.isNewCategory, isFalse);
  });

  testWidgets('titleRequired: false 時標題可留空', (tester) async {
    await pump(tester, titleRequired: false);
    expect(find.widgetWithText(TextField, '標題'), findsOneWidget);
    await chooseCategory(tester, '其他');
    await submit(tester);
    expect(results, [true]);
    expect(find.text('標題必填'), findsNothing);
    expect(controller.value.title, isNull);
  });

  testWidgets('說明超過 2000 字顯示錯誤、不能通過', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), 't');
    await chooseCategory(tester, '其他');
    await tester.enterText(
      find.widgetWithText(TextField, '說明'),
      'a' * (adminVideoDescriptionMax + 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('說明最多 2000 字'), findsOneWidget);
    await submit(tester);
    expect(results, [false]);

    await tester.enterText(
      find.widgetWithText(TextField, '說明'),
      'a' * adminVideoDescriptionMax,
    );
    await tester.pumpAndSettle();
    expect(find.text('說明最多 2000 字'), findsNothing);
    await submit(tester);
    expect(results, [false, true]);
  });

  testWidgets('輸入新分類：value 是新名稱、isNewCategory 為 true', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), 't');
    await chooseCategory(tester, '＋新增分類');
    await submit(tester);
    expect(results, [false]);
    expect(find.text('分類名稱必填'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '新分類名稱'), '祭儀');
    await submit(tester);
    expect(results, [false, true]);
    expect(controller.value.category, '祭儀');
    expect(controller.isNewCategory, isTrue);
  });

  testWidgets('部落可不選、可選、可清除', (tester) async {
    await pump(tester);
    expect(find.text('選填，不標註'), findsOneWidget);
    await tester.tap(find.text('相關部落'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('崇德'));
    await tester.pumpAndSettle();
    expect(find.text('崇德'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '標題（必填）'), 't');
    await chooseCategory(tester, '其他');
    await submit(tester);
    expect(controller.value.tribeId, 5);

    await tester.tap(find.byTooltip('不標註部落'));
    await tester.pumpAndSettle();
    expect(find.text('選填，不標註'), findsOneWidget);
    expect(controller.value.tribeId, isNull);
  });

  testWidgets('帶入既有值：各欄位顯示原值，部落補上名稱', (tester) async {
    await pump(
      tester,
      initial: const AdminVideoMeta(
        title: '織布',
        description: '關於織布',
        category: 'cultural',
        tribeId: 3,
      ),
    );
    expect(find.text('織布'), findsOneWidget);
    expect(find.text('關於織布'), findsOneWidget);
    expect(find.text('文化紀錄'), findsOneWidget);
    expect(find.text('富世'), findsOneWidget);
    await submit(tester);
    expect(results, [true]);
    expect(
      controller.value.patchFrom(
        const AdminVideoMeta(
          title: '織布',
          description: '關於織布',
          category: 'cultural',
          tribeId: 3,
        ),
      ),
      isEmpty,
    );
  });

  testWidgets('帶入的分類不在清單裡：仍顯示其名稱並保持選中', (tester) async {
    await pump(
      tester,
      initial: const AdminVideoMeta(title: '舊片', category: '已刪除的分類'),
    );
    expect(find.text('已刪除的分類'), findsOneWidget);
    await submit(tester);
    expect(results, [true]);
    expect(controller.value.category, '已刪除的分類');
    expect(controller.isNewCategory, isTrue);
  });
}
