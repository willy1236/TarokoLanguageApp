// 影片管理列表：各狀態與來源的呈現、篩選與搜尋送出的參數、下一頁、下拉重整、
// 非管理員退出後台、後台首頁入口、上傳影片按鈕。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_home_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_videos_screen.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _videosPath = '/api/admin/videos';
const _categoriesPath = '/api/videos/categories';

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
  await tester.pumpWidget(_host(() => const AdminVideosScreen()));
  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _video(int id, {String status = 'ready'}) => {
  'id': id,
  'title': '影片$id',
  'description': null,
  'category': 'cultural',
  'source': 'hls',
  'status': status,
  'fail_reason': null,
  'duration_sec': 60,
  'thumbnail_url': null,
  'youtube_video_id': null,
  'embeddable': null,
  'tribe_id': null,
  'created_at': '2026-10-13T00:00:00.000Z',
};

Map<String, dynamic> _page(List<Map<String, dynamic>> videos, String? next) => {
  'videos': videos,
  'page_info': {'next_cursor': next, 'has_more': next != null},
};

final _categories = {
  'categories': [
    {'value': 'cultural', 'label': '文化紀錄', 'sort_order': 20, 'count': 1},
    {'value': 'new_cat', 'label': '新分類', 'sort_order': 100, 'count': 1},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
    UserService.clearCache();
  });

  late List<Uri> listRequests;

  /// 影片列表依 [respond] 回應（拿到這次的 query），分類清單固定回 [_categories]。
  void mock(Object Function(Map<String, String> query) respond) {
    listRequests = [];
    ApiClient.httpClient = MockClient((r) async {
      if (r.url.path == _categoriesPath) return jsonResponse(_categories);
      // 非管理員錯誤時 handleAdminError 會重抓 /api/me。
      if (r.url.path == '/api/me') {
        return jsonResponse({
          'uid': 1,
          'created_at': '2026-01-01T00:00:00Z',
          'role': 'user',
        });
      }
      if (r.url.path == _videosPath) {
        listRequests.add(r.url);
        final res = respond(r.url.queryParameters);
        return res is http.Response ? res : jsonResponse(res);
      }
      fail('沒有準備 ${r.url}');
    });
  }

  testWidgets('每列顯示標題、狀態、來源、分類名稱；失敗顯示原因；沒縮圖顯示圖示', (tester) async {
    mock((_) => loadSpecFixtureMap('get_api_admin_videos.json'));
    await _open(tester);

    expect(find.text('影片管理'), findsOneWidget);
    expect(find.text('上傳中的教學影片'), findsOneWidget);
    expect(find.text('轉檔失敗的部落宣傳'), findsOneWidget);
    expect(find.text('已下架的活動紀錄'), findsOneWidget);

    Finder badge(String text) =>
        find.descendant(of: find.byType(ListView), matching: find.text(text));
    expect(badge('處理中'), findsOneWidget);
    expect(badge('失敗'), findsOneWidget);
    expect(badge('已下架'), findsOneWidget);
    expect(badge('已上架'), findsNWidgets(2));
    expect(badge('自家'), findsNWidgets(3));
    expect(badge('YouTube'), findsNWidgets(2));
    expect(badge('教學延伸'), findsOneWidget, reason: '內建對照');
    expect(badge('新分類'), findsOneWidget, reason: '分類清單抓回來後顯示新分類的名稱');

    expect(
      find.text('失敗原因：ffmpeg exit 1: moov atom not found'),
      findsOneWidget,
    );
    // 處理中、失敗兩筆沒有縮圖；其他筆的網路圖在測試環境載入失敗也會退回圖示。
    expect(
      find.byKey(const ValueKey('admin-video-thumbnail-placeholder')),
      findsAtLeastNWidgets(2),
    );

    expect(listRequests.single.queryParameters, isEmpty, reason: '全部不帶篩選');
  });

  testWidgets('狀態、來源篩選與標題搜尋都會重新查詢', (tester) async {
    mock((_) => _page([_video(1)], null));
    await _open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '失敗'));
    await tester.pumpAndSettle();
    expect(listRequests.last.queryParameters, {'status': 'failed'});

    await tester.tap(find.widgetWithText(ChoiceChip, 'YouTube'));
    await tester.pumpAndSettle();
    expect(listRequests.last.queryParameters, {
      'status': 'failed',
      'source': 'youtube',
    });

    await tester.enterText(find.byType(TextField), '  織布 ');
    await tester.pump(const Duration(milliseconds: 100));
    expect(listRequests, hasLength(3), reason: '還在輸入，不送出');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(listRequests.last.queryParameters, {
      'status': 'failed',
      'source': 'youtube',
      'q': '織布',
    });

    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.tap(find.widgetWithText(ChoiceChip, '全部來源'));
    await tester.pumpAndSettle();
    expect(listRequests.last.queryParameters, {'q': '織布'});
  });

  testWidgets('搜尋上限以 UTF-16 單位計（同後端），emoji 不會被放行成 400', (tester) async {
    mock((_) => _page([_video(1)], null));
    await _open(tester);

    // 79 個中文字＋1 個 emoji：字形叢集是 80，UTF-16 是 81。
    await tester.enterText(find.byType(TextField), '${'織' * 79}😀');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final text = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(text, '織' * 79, reason: '放不下的 emoji 整個不收，不切成半個');
    expect(listRequests.last.queryParameters['q'], '織' * 79);
    expect(
      listRequests.last.queryParameters['q']!.length,
      lessThanOrEqualTo(80),
    );
  });

  testWidgets('捲到底載入下一頁', (tester) async {
    mock(
      (q) => q['cursor'] == null
          ? _page([for (var i = 1; i <= 20; i++) _video(i)], '20')
          : _page([_video(21)], null),
    );
    await _open(tester);

    await tester.dragUntilVisible(
      find.text('影片21'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('影片21'), findsOneWidget);
    expect(listRequests.map((u) => u.queryParameters['cursor']), [null, '20']);
  });

  testWidgets('下拉重新整理更新狀態', (tester) async {
    var status = 'processing';
    mock((_) => _page([_video(1, status: status)], null));
    await _open(tester);
    expect(find.text('處理中'), findsNWidgets(2), reason: '篩選 chip 與列上的狀態');

    status = 'ready';
    await tester.fling(find.text('影片1'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(listRequests, hasLength(2));
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('已上架')),
      findsOneWidget,
    );
  });

  testWidgets('右上角上傳影片：上架成功回來重抓第一頁並保留篩選，取消回來不重抓', (tester) async {
    mock((_) => _page([_video(1)], null));
    await _open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'YouTube'));
    await tester.pumpAndSettle();
    expect(listRequests, hasLength(2));

    await tester.tap(find.byTooltip('上傳影片'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminVideoUploadScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(AdminVideoUploadScreen))).pop();
    await tester.pumpAndSettle();
    expect(listRequests, hasLength(2), reason: '沒上架不重抓');

    await tester.tap(find.byTooltip('上傳影片'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AdminVideoUploadScreen))).pop(true);
    await tester.pumpAndSettle();
    expect(listRequests, hasLength(3));
    expect(listRequests.last.queryParameters, {'source': 'youtube'});
    expect(find.text('影片1'), findsOneWidget);
  });

  testWidgets('403 ADMIN_ONLY：退出後台', (tester) async {
    mock((_) => errorResponse('ADMIN_ONLY', status: 403, message: '只有管理員可以使用'));
    UserService.currentUid = 1;

    await _open(tester);
    expect(find.text('開啟'), findsOneWidget, reason: '已退回進入後台前的畫面');
    expect(find.text('影片管理'), findsNothing);
    expect(find.text('只有管理員可以使用'), findsOneWidget);
  });

  testWidgets('後台首頁有影片管理入口', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mock((_) => _page([], null));
    await tester.pumpWidget(_host(() => const AdminHomeScreen()));
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('影片管理'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminVideosScreen), findsOneWidget);
    expect(find.text('沒有符合條件的影片'), findsOneWidget);
  });
}
