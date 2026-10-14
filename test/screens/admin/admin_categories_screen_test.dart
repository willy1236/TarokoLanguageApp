// 分類管理頁：三分頁列出、新增、改名排序、同名與已不存在的處理、送出中不能連點，活動分類選色。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_categories_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_home_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cards.dart';
import 'package:flutter_application_1/services/category_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _articles = '/api/admin/categories/articles';
const _videos = '/api/admin/categories/videos';
const _events = '/api/admin/categories/events';

Widget _host(Widget Function() screen) => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => pushAdmin<void>(context, screen()),
        child: const Text('開啟'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_host(() => const AdminCategoriesScreen()));
  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
  });

  late List<http.Request> requests;

  /// 預設三個模組的清單都用錄製的 fixture；[extra] 覆寫或加上其他路徑。
  void mock(
    Map<String, Object?> extra, {
    Duration Function(http.Request)? delayFor,
  }) {
    requests = [];
    installMockClient(
      {
        _articles: loadFixtureMap('get_api_admin_categories_articles.json'),
        _videos: loadFixtureMap('get_api_admin_categories_videos.json'),
        _events: loadFixtureMap('get_api_admin_categories_events.json'),
        '/api/articles/categories': loadFixtureMap(
          'get_api_articles_categories.json',
        ),
        ...extra,
      },
      onRequest: requests.add,
      delayFor: delayFor,
    );
  }

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path).length;

  testWidgets('後台首頁有分類管理入口', (tester) async {
    // 功能清單較長，拉高視窗才放得下最下方的入口。
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mock({});
    await tester.pumpWidget(_host(() => const AdminHomeScreen()));
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('分類管理'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminCategoriesScreen), findsOneWidget);
  });

  testWidgets('三個分頁各列出全部分類與筆數；第一次切到才載入', (tester) async {
    mock({});
    await _open(tester);

    expect(count('GET', _articles), 1);
    expect(count('GET', _videos), 0, reason: '還沒切到影音分頁');
    expect(find.text('部落宣傳'), findsOneWidget);
    expect(find.text('代碼 tribal_intro'), findsOneWidget);
    expect(find.text('0 筆'), findsOneWidget, reason: 'count 0 也列出');
    expect(find.text('12 筆'), findsOneWidget);

    await tester.tap(find.text('活動'));
    await tester.pumpAndSettle();
    expect(count('GET', _events), 1);
    expect(find.text('族語'), findsOneWidget);
    expect(find.text('代碼 族語'), findsNothing, reason: '代碼與名稱相同不重複顯示');

    await tester.tap(find.text('影音'));
    await tester.pumpAndSettle();
    expect(find.text('23 筆'), findsOneWidget);

    await tester.tap(find.text('文章'));
    await tester.pumpAndSettle();
    expect(count('GET', _articles), 1, reason: '切回已載入的分頁不重抓');
  });

  testWidgets('新增：只送名稱，成功後重抓清單並刷新前台快取', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'GET $_articles': loadFixtureMap(
        'get_api_admin_categories_articles.json',
      ),
      'POST $_articles': jsonResponse({
        'category': {
          'value': '祭儀',
          'label': '祭儀',
          'sort_order': 100,
          'count': 0,
        },
      }, status: 201),
      'GET /api/articles/categories': loadFixtureMap(
        'get_api_articles_categories.json',
      ),
    });

    await tester.tap(find.byTooltip('新增分類'));
    await tester.pumpAndSettle();
    expect(find.text('新增文章分類'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), ' 祭儀 ');
    await tester.pump();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'label': '祭儀'});
    expect(count('GET', _articles), 1, reason: '成功後重抓清單');
    expect(count('GET', '/api/articles/categories'), 1, reason: '刷新前台快取');
    expect(find.text('已新增分類'), findsOneWidget);
    expect(find.text('新增文章分類'), findsNothing, reason: '對話框已關閉');
  });

  testWidgets('改名與排序：只送有改的欄位，路徑帶原 value，成功後重抓', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'GET $_articles': loadFixtureMap(
        'get_api_admin_categories_articles.json',
      ),
      'PATCH $_articles/cultural': {
        'category': {'value': 'cultural', 'label': '文化', 'sort_order': 5},
      },
      'GET /api/articles/categories': loadFixtureMap(
        'get_api_articles_categories.json',
      ),
    });

    await tester.tap(find.text('文化紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('編輯文章分類'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '文化');
    await tester.enterText(find.widgetWithText(TextField, '排序（選填）'), '5');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body), {'label': '文化', 'sort_order': 5});
    expect(count('GET', _articles), 1);
    expect(count('GET', '/api/articles/categories'), 1);
    expect(find.text('已儲存'), findsOneWidget);
  });

  testWidgets('名稱沒改、只改排序：只送 sort_order', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'GET $_articles': loadFixtureMap(
        'get_api_admin_categories_articles.json',
      ),
      'PATCH $_articles/other': {
        'category': {'value': 'other', 'label': '其他', 'sort_order': 999},
      },
      'GET /api/articles/categories': loadFixtureMap(
        'get_api_articles_categories.json',
      ),
    });

    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '排序（選填）'), '999');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(jsonDecode(requests.singleWhere((r) => r.method == 'PATCH').body), {
      'sort_order': 999,
    });
  });

  testWidgets('名稱空白或排序超過 10000 不能送出', (tester) async {
    mock({});
    await _open(tester);
    await tester.tap(find.byTooltip('新增分類'));
    await tester.pumpAndSettle();

    TextButton submit() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, '新增'));
    expect(submit().onPressed, isNull, reason: '名稱還沒填');
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '   ');
    await tester.pump();
    expect(submit().onPressed, isNull, reason: '只有空白');

    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '祭儀');
    await tester.enterText(find.widgetWithText(TextField, '排序（選填）'), '10001');
    await tester.pump();
    expect(find.text('排序須為 0～10000 的整數'), findsOneWidget);
    expect(submit().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, '名稱（必填）'),
      '一二三四五六七八九十一二三四五六七八九十多',
    );
    await tester.pump();
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, '名稱（必填）'),
    );
    expect(field.controller!.text.length, 20, reason: '超過 20 字截掉');
  });

  testWidgets('同名（409 CATEGORY_EXISTS）：對話框不關，顯示分類名稱已存在', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'GET $_articles': loadFixtureMap(
        'get_api_admin_categories_articles.json',
      ),
      'POST $_articles': errorResponse(
        'CATEGORY_EXISTS',
        status: 409,
        message: '已有同名分類',
      ),
    });

    await tester.tap(find.byTooltip('新增分類'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '其他');
    await tester.pump();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.text('新增文章分類'), findsOneWidget, reason: '對話框還在');
    expect(find.text('分類名稱已存在'), findsOneWidget);
    expect(count('GET', _articles), 0, reason: '失敗不重抓');
  });

  testWidgets('分類已不存在（404）：提示、關對話框並重抓該分頁', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'GET $_articles': loadFixtureMap(
        'get_api_admin_categories_articles.json',
      ),
      'PATCH $_articles/event': errorResponse(
        'CATEGORY_NOT_FOUND',
        status: 404,
        message: '分類不存在',
      ),
    });

    await tester.tap(find.text('活動紀錄'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '活動');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(find.text('這個分類已不存在'), findsOneWidget);
    expect(find.text('編輯文章分類'), findsNothing);
    expect(count('GET', _articles), 1);
  });

  testWidgets('其他錯誤：關對話框並顯示後端訊息，不重抓', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(requests, {
      'POST $_articles': errorResponse(
        'INVALID_REQUEST',
        status: 400,
        message: 'label 必填，1～20 字',
      ),
    });

    await tester.tap(find.byTooltip('新增分類'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '祭儀');
    await tester.pump();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.text('label 必填，1～20 字'), findsOneWidget);
    expect(find.text('新增文章分類'), findsNothing);
  });

  testWidgets('送出中按鈕停用，連點只送一次', (tester) async {
    mock({});
    await _open(tester);
    _dispatchByMethod(
      requests,
      {
        'GET $_articles': loadFixtureMap(
          'get_api_admin_categories_articles.json',
        ),
        'POST $_articles': jsonResponse({
          'category': {
            'value': '祭儀',
            'label': '祭儀',
            'sort_order': 100,
            'count': 0,
          },
        }, status: 201),
        'GET /api/articles/categories': loadFixtureMap(
          'get_api_articles_categories.json',
        ),
      },
      delayFor: (r) =>
          r.method == 'POST' ? const Duration(seconds: 1) : Duration.zero,
    );

    await tester.tap(find.byTooltip('新增分類'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '祭儀');
    await tester.pump();
    await tester.tap(find.text('新增'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '新增'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('新增'), warnIfMissed: false);
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(count('POST', _articles), 1);
  });

  group('活動分類選色', () {
    /// 活動分類清單：預設色、不在色票裡的色、沒設。
    final eventList = {
      'categories': [
        _eventCat('族語', '#7A1F1A'),
        _eventCat('打獵', '#123456'),
        _eventCat('祭儀', null),
      ],
    };

    /// 對話框加上選色會變高，拉高視窗讓整個對話框都在畫面內。
    Future<void> openEvents(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      mock({_events: eventList});
      await _open(tester);
      await tester.tap(find.text('活動'));
      await tester.pumpAndSettle();
    }

    /// 送出後成功的路由：活動清單、POST／PATCH、前台快取。
    void respondOk(String method, String path) => _dispatchByMethod(requests, {
      'GET $_events': eventList,
      '$method $path': jsonResponse({
        'category': _eventCat('x', null),
      }, status: method == 'POST' ? 201 : 200),
      'GET /api/events/categories': eventList,
    });

    Finder colorField() => find.widgetWithText(TextField, '色碼（選填）');
    String colorText(WidgetTester tester) =>
        tester.widget<TextField>(colorField()).controller!.text;
    bool isSelected(String swatch) => find
        .descendant(
          of: find.byTooltip(swatch),
          matching: find.byIcon(Icons.check),
        )
        .evaluate()
        .isNotEmpty;
    Map<String, dynamic> sentBody(String method) =>
        jsonDecode(requests.singleWhere((r) => r.method == method).body)
            as Map<String, dynamic>;

    testWidgets('文章分頁的對話框沒有選色；活動分頁有六個色票、不指定與色碼欄', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      mock({_events: eventList});
      await _open(tester);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      expect(colorField(), findsNothing);
      expect(find.text('不指定（用預設色）'), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('活動'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      for (final name in ['深紅', '暗紅', '苔綠', '深綠', '暗金', '墨褐']) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }
      expect(find.text('不指定（用預設色）'), findsOneWidget);
      expect(colorField(), findsOneWidget);
      expect(find.byType(EventDateBox), findsOneWidget, reason: '預覽日期方塊');
    });

    testWidgets('列表列顯示目前顏色，沒設的標示預設', (tester) async {
      await openEvents(tester);

      expect(find.text('顏色 #7A1F1A'), findsOneWidget);
      expect(find.text('顏色 #123456'), findsOneWidget);
      expect(find.text('顏色 預設'), findsOneWidget);
    });

    testWidgets('新增：點色票同步色碼欄並送 color，預覽換成該色', (tester) async {
      await openEvents(tester);
      respondOk('POST', _events);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '舞蹈');
      await tester.tap(find.byTooltip('苔綠'));
      await tester.pump();

      expect(colorText(tester), '#3D5A3D');
      expect(isSelected('苔綠'), isTrue);
      expect(
        tester.widget<EventDateBox>(find.byType(EventDateBox)).color,
        AppColors.moss,
      );

      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(sentBody('POST'), {'label': '舞蹈', 'color': '#3D5A3D'});
    });

    testWidgets('新增：選不指定就不帶 color', (tester) async {
      await openEvents(tester);
      respondOk('POST', _events);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '舞蹈');
      await tester.tap(find.byTooltip('暗金'));
      await tester.pump();
      await tester.tap(find.text('不指定（用預設色）'));
      await tester.pump();
      expect(colorText(tester), '');

      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(sentBody('POST'), {'label': '舞蹈'});
    });

    testWidgets('色碼欄輸入小寫的色票色：該色票選中，送出轉大寫', (tester) async {
      await openEvents(tester);
      respondOk('POST', _events);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '舞蹈');
      await tester.enterText(colorField(), '#8e7234');
      await tester.pump();

      expect(isSelected('暗金'), isTrue);
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(sentBody('POST')['color'], '#8E7234');
    });

    testWidgets('色碼格式不對顯示錯誤、不能送出', (tester) async {
      await openEvents(tester);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '舞蹈');
      await tester.enterText(colorField(), '#FFF');
      await tester.pump();

      expect(find.text('須為 #RRGGBB 格式，例如 #7A1F1A'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '新增'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('編輯：改顏色只送 color', (tester) async {
      await openEvents(tester);
      respondOk('PATCH', '$_events/${Uri.encodeComponent('族語')}');
      await tester.tap(find.text('族語'));
      await tester.pumpAndSettle();
      expect(isSelected('深紅'), isTrue, reason: '帶出目前顏色');

      await tester.tap(find.byTooltip('深綠'));
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(sentBody('PATCH'), {'color': '#1F3220'});
    });

    testWidgets('編輯：改成不指定送 color: null', (tester) async {
      await openEvents(tester);
      respondOk('PATCH', '$_events/${Uri.encodeComponent('族語')}');
      await tester.tap(find.text('族語'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不指定（用預設色）'));
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      final body = sentBody('PATCH');
      expect(body, {'color': null});
      expect(body.containsKey('color'), isTrue);
    });

    testWidgets('編輯：現有顏色不在色票裡，帶進色碼欄；只改名不送 color', (tester) async {
      await openEvents(tester);
      respondOk('PATCH', '$_events/${Uri.encodeComponent('打獵')}');
      await tester.tap(find.text('打獵'));
      await tester.pumpAndSettle();

      expect(colorText(tester), '#123456');
      for (final s in ['深紅', '暗紅', '苔綠', '深綠', '暗金', '墨褐']) {
        expect(isSelected(s), isFalse, reason: s);
      }
      await tester.enterText(find.widgetWithText(TextField, '名稱（必填）'), '狩獵');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(sentBody('PATCH'), {'label': '狩獵'});
    });

    testWidgets('編輯：名稱、排序、顏色都沒變直接關閉，不送請求', (tester) async {
      await openEvents(tester);
      _dispatchByMethod(requests, {});
      await tester.tap(find.text('祭儀'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('暗紅'));
      await tester.pump();
      await tester.tap(find.text('不指定（用預設色）'));
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);
      expect(find.text('編輯活動分類'), findsNothing);
    });
  });
}

Map<String, Object?> _eventCat(String value, String? color) => {
  'value': value,
  'label': value,
  'sort_order': 10,
  'count': 1,
  'color': color,
};

/// 同一路徑依 method 回不同內容（GET 清單、POST 新增）。key 為 `METHOD path`。
/// 會清空 [requests] 重新記錄，方便只看這之後送出的請求。
void _dispatchByMethod(
  List<http.Request> requests,
  Map<String, Object?> routes, {
  Duration Function(http.Request)? delayFor,
}) {
  requests.clear();
  ApiClient.httpClient = MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    if (!routes.containsKey(key)) fail('測試沒有為 $key 準備假回應');
    final delay = delayFor?.call(request);
    if (delay != null) await Future<void>.delayed(delay);
    final route = routes[key];
    return route is http.Response ? route : jsonResponse(route);
  });
}
