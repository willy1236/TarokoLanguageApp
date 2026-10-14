// 編輯影片（後台影片 T-07）：從列表選單進入、帶入原值、只送改動的欄位、
// 說明與部落清空送 null、沒有改動不送出、新分類刷新影音分類、404 回列表重抓、非管理員退出後台。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_videos_screen.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _videosPath = '/api/admin/videos';
const _adminCategoriesPath = '/api/admin/categories/videos';
const _appCategoriesPath = '/api/videos/categories';

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
  ],
};

Map<String, dynamic> _video({String status = 'ready'}) => {
  'id': 7,
  'title': '織布',
  'description': '關於織布',
  'category': 'cultural',
  'source': 'hls',
  'status': status,
  'fail_reason': null,
  'duration_sec': 60,
  'thumbnail_url': null,
  'youtube_video_id': null,
  'embeddable': null,
  'tribe_id': 3,
  'created_at': '2026-10-13T00:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  /// 列表回一筆 [video]；PATCH 回 [patch]（null＝把送出的欄位套到原資料上回 200）。
  void mock({Map<String, dynamic>? video, http.Response? patch}) {
    requests = [];
    final row = video ?? _video();
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case _videosPath:
          return jsonResponse({
            'videos': [row],
            'page_info': {'next_cursor': null, 'has_more': false},
          });
        case '$_videosPath/7':
          if (patch != null) return patch;
          final fields = jsonDecode(r.body) as Map<String, dynamic>;
          return jsonResponse({
            'video': {...row, ...fields},
          });
        case _adminCategoriesPath:
          return jsonResponse(
            loadFixtureMap('get_api_admin_categories_videos.json'),
          );
        case _appCategoriesPath:
          return jsonResponse({'categories': []});
        case '/api/tribes':
          return jsonResponse(_tribes);
        case '/api/me':
          return jsonResponse({
            'uid': 1,
            'created_at': '2026-01-01T00:00:00Z',
            'role': 'user',
          });
      }
      fail('沒有準備 ${r.method} ${r.url}');
    });
  }

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
    UserService.clearCache();
  });

  List<http.Request> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path).toList();

  Map<String, dynamic> patchBody() =>
      jsonDecode(calls('PATCH', '$_videosPath/7').single.body)
          as Map<String, dynamic>;

  Future<void> openList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  pushAdmin<void>(context, const AdminVideosScreen()),
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  Future<void> openEdit(WidgetTester tester) async {
    await openList(tester);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
  }

  Finder titleField() => find.widgetWithText(TextField, '標題（必填）');
  Finder descriptionField() => find.widgetWithText(TextField, '說明');

  testWidgets('列選單「編輯」打開編輯頁，各欄位帶入原值', (tester) async {
    mock();
    await openEdit(tester);

    expect(find.text('編輯影片'), findsOneWidget);
    expect(tester.widget<TextField>(titleField()).controller!.text, '織布');
    expect(
      tester.widget<TextField>(descriptionField()).controller!.text,
      '關於織布',
    );
    expect(find.text('文化紀錄'), findsOneWidget);
    expect(find.text('富世'), findsOneWidget);
  });

  testWidgets('只改標題：只送 title，成功後回列表、該列顯示新值', (tester) async {
    mock();
    await openEdit(tester);

    await tester.enterText(titleField(), '  織布教學 ');
    await save(tester);

    expect(patchBody(), {'title': '織布教學'});
    expect(find.text('編輯影片'), findsNothing);
    expect(find.text('影片管理'), findsOneWidget);
    expect(find.text('織布教學'), findsOneWidget);
    expect(find.text('已儲存'), findsOneWidget);
    expect(calls('GET', _videosPath), hasLength(1), reason: '就地換掉，不重抓');
  });

  testWidgets('說明、部落清空送 null', (tester) async {
    mock();
    await openEdit(tester);

    await tester.enterText(descriptionField(), '   ');
    await tester.tap(find.byTooltip('不標註部落'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(patchBody(), {'description': null, 'tribe_id': null});
  });

  testWidgets('沒有改動：不送出，提示「沒有變更」並留在編輯頁', (tester) async {
    mock();
    await openEdit(tester);

    await save(tester);

    expect(calls('PATCH', '$_videosPath/7'), isEmpty);
    expect(find.text('沒有變更'), findsOneWidget);
    expect(find.text('編輯影片'), findsOneWidget);
  });

  testWidgets('換成新分類：送新名稱，成功後重抓影音分類清單、列表顯示新分類', (tester) async {
    mock();
    await openEdit(tester);
    final before = calls('GET', _appCategoriesPath).length;

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('＋新增分類').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '新分類名稱'), '祭儀');
    await save(tester);

    expect(patchBody(), {'category': '祭儀'});
    expect(calls('GET', _appCategoriesPath).length, before + 1);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('祭儀')),
      findsOneWidget,
    );
  });

  testWidgets('換成清單裡既有的分類：不重抓影音分類清單', (tester) async {
    mock();
    await openEdit(tester);
    final before = calls('GET', _appCategoriesPath).length;

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('教學延伸').last);
    await tester.pumpAndSettle();
    await save(tester);

    expect(patchBody(), {'category': 'education'});
    expect(calls('GET', _appCategoriesPath).length, before);
  });

  testWidgets('已下架的影片也能編輯', (tester) async {
    mock(video: _video(status: 'archived'));
    await openEdit(tester);
    expect(find.text('編輯影片'), findsOneWidget);
  });

  testWidgets('404 VIDEO_NOT_FOUND：提示影片不存在，回列表重抓', (tester) async {
    mock(
      patch: errorResponse('VIDEO_NOT_FOUND', status: 404, message: '影片不存在'),
    );
    await openEdit(tester);

    await tester.enterText(titleField(), '新標題');
    await save(tester);

    expect(find.text('這支影片已不存在'), findsOneWidget);
    expect(find.text('編輯影片'), findsNothing);
    expect(find.text('影片管理'), findsOneWidget);
    expect(calls('GET', _videosPath), hasLength(2));
  });

  testWidgets('其他錯誤：顯示後端訊息，留在編輯頁可再送', (tester) async {
    mock(
      patch: errorResponse('INVALID_CATEGORY', message: 'category 必填，1～20 字'),
    );
    await openEdit(tester);

    await tester.enterText(titleField(), '新標題');
    await save(tester);

    expect(find.text('category 必填，1～20 字'), findsOneWidget);
    expect(find.text('編輯影片'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '儲存'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('非管理員：退出整個後台', (tester) async {
    mock(patch: errorResponse('ADMIN_ONLY', status: 403, message: '僅限管理員'));
    await openEdit(tester);

    await tester.enterText(titleField(), '新標題');
    await save(tester);

    expect(find.text('編輯影片'), findsNothing);
    expect(find.text('影片管理'), findsNothing);
    expect(find.text('開啟'), findsOneWidget);
  });
}
