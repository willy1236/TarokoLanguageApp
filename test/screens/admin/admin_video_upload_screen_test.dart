// 上傳影片頁（後台影片 T-03）：貼 YouTube 網址預覽後上架。
// 預覽帶入標題、已上架與不允許嵌入的提示、各種錯誤提示、舊預覽丟棄、上架送出與錯誤、
// 新分類刷新、選擇影片檔尚未開放。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_screen.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_widgets.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _previewPath = '/api/admin/videos/youtube/preview';
const _createPath = '/api/admin/videos';
const _adminCategoriesPath = '/api/admin/categories/videos';
const _appCategoriesPath = '/api/videos/categories';

const _zooUrl = 'https://youtu.be/jNQXAC9IVRw';
const _otherUrl = 'https://www.youtube.com/watch?v=abcdefghijk';

Map<String, dynamic> _preview({
  String id = 'jNQXAC9IVRw',
  String? title = 'Me at the zoo',
  bool embeddable = true,
  int? exists,
}) => {
  'youtube_video_id': id,
  'title': title,
  'thumbnail_url': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  'embeddable': embeddable,
  'exists_video_id': exists,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late bool? popped;

  /// 預覽依網址回 [previews]（Map 為 200，http.Response 原樣），[delays] 讓某個網址晚回；
  /// 上架回 [create]。
  void mock({
    Map<String, Object> previews = const {},
    Map<String, Duration> delays = const {},
    Object? create,
  }) {
    requests = [];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case _adminCategoriesPath:
          return jsonResponse(
            loadFixtureMap('get_api_admin_categories_videos.json'),
          );
        case _appCategoriesPath:
          return jsonResponse({'categories': []});
        case '/api/me':
          return jsonResponse({
            'uid': 1,
            'created_at': '2026-01-01T00:00:00Z',
            'role': 'user',
          });
        case _previewPath:
          final url = (jsonDecode(r.body) as Map)['url'] as String;
          final delay = delays[url];
          if (delay != null) await Future<void>.delayed(delay);
          final res =
              previews[url] ??
              errorResponse('INVALID_YOUTUBE_URL', message: '只接受 YouTube 影片網址');
          return res is http.Response ? res : jsonResponse(res);
        case _createPath:
          final res =
              create ??
              loadSpecFixtureMap('post_api_admin_videos_youtube.json');
          return res is http.Response ? res : jsonResponse(res, status: 201);
      }
      fail('沒有準備 ${r.method} ${r.url}');
    });
  }

  setUp(() {
    stubCommonChannels();
    popped = null;
  });
  tearDown(() {
    restoreHttp();
    CategoryService.reset();
    UserService.clearCache();
  });

  List<http.Request> calls(String path) =>
      requests.where((r) => r.url.path == path).toList();

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => popped = await pushAdmin<bool>(
                context,
                const AdminVideoUploadScreen(),
              ),
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  Finder urlField() => find.widgetWithText(TextField, 'YouTube 網址');

  /// 一次放進整串網址＝貼上，立刻預覽。
  Future<void> paste(WidgetTester tester, String url) async {
    await tester.enterText(urlField(), url);
    await tester.pumpAndSettle();
  }

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text;

  Future<void> chooseCategory(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Finder submitButton() => find.widgetWithText(FilledButton, '上架');

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submitButton()).onPressed != null;

  testWidgets('貼上網址立刻預覽：顯示縮圖、標題帶入可改；上架送出後回列表', (tester) async {
    mock(previews: {_zooUrl: _preview()});
    await open(tester);
    expect(submitEnabled(tester), isFalse, reason: '還沒預覽不能上架');

    await paste(tester, '  $_zooUrl ');
    expect(calls(_previewPath), hasLength(1));
    expect(jsonDecode(calls(_previewPath).single.body), {'url': _zooUrl});
    expect(
      find.byKey(const ValueKey('admin-video-preview-thumbnail')),
      findsOneWidget,
    );
    expect(titleText(tester), 'Me at the zoo');
    expect(find.text('標題'), findsOneWidget, reason: '可嵌入且有標題，標題選填');

    await tester.enterText(find.byType(TextField).at(1), '動物園');
    await chooseCategory(tester, '文化紀錄');
    expect(submitEnabled(tester), isTrue);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    final body = jsonDecode(calls(_createPath).single.body);
    expect(body, {
      'source': 'youtube',
      'url': _zooUrl,
      'title': '動物園',
      'category': 'cultural',
    });
    expect(popped, isTrue);
    expect(find.text('開啟'), findsOneWidget);
    expect(find.text('已上架'), findsOneWidget);
    expect(calls(_appCategoriesPath), isEmpty, reason: '不是新分類不刷新');
  });

  testWidgets('逐字輸入：停止約 500ms 才預覽；不是 YouTube 網址顯示指定提示', (tester) async {
    mock();
    await open(tester);

    await tester.enterText(urlField(), 'h');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(urlField(), 'ht');
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls(_previewPath), isEmpty, reason: '還在輸入');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(calls(_previewPath), hasLength(1));
    expect(jsonDecode(calls(_previewPath).single.body), {'url': 'ht'});
    expect(find.text('只接受 YouTube 網址；影片檔請用「選擇影片檔」上傳'), findsOneWidget);
    expect(find.text('重試'), findsNothing);
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('已經上架過：提示且不能上架', (tester) async {
    mock(previews: {_zooUrl: _preview(exists: 101)});
    await open(tester);
    await paste(tester, _zooUrl);
    expect(find.text('這支影片已經上架過'), findsOneWidget);
    await chooseCategory(tester, '文化紀錄');
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('不允許嵌入：提示會改開 YouTube，標題變必填', (tester) async {
    mock(previews: {_zooUrl: _preview(title: null, embeddable: false)});
    await open(tester);
    await paste(tester, _zooUrl);
    expect(find.text('這支影片不允許在 App 裡播放，會改成開 YouTube'), findsOneWidget);
    expect(find.text('標題（必填）'), findsOneWidget);
    expect(titleText(tester), '');

    await chooseCategory(tester, '文化紀錄');
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(find.text('標題必填'), findsOneWidget);
    expect(calls(_createPath), isEmpty);
  });

  testWidgets('私人、不存在的影片顯示後端提示；YouTube 暫時查不到可重試', (tester) async {
    final previews = <String, Object>{
      _zooUrl: errorResponse(
        'YOUTUBE_UNAVAILABLE',
        status: 422,
        message: '這支影片是私人或受限影片，無法上架',
      ),
      _otherUrl: errorResponse(
        'YOUTUBE_NOT_FOUND',
        status: 422,
        message: '找不到這支 YouTube 影片',
      ),
      'https://youtu.be/retry000000': errorResponse(
        'YOUTUBE_CHECK_FAILED',
        status: 502,
        message: '暫時無法向 YouTube 確認這支影片，請稍後再試',
      ),
    };
    mock(previews: previews);
    await open(tester);

    await paste(tester, _zooUrl);
    expect(find.text('這支影片是私人或受限影片，無法上架'), findsOneWidget);
    expect(find.text('重試'), findsNothing);

    await paste(tester, _otherUrl);
    expect(find.text('找不到這支 YouTube 影片'), findsOneWidget);
    expect(find.text('重試'), findsNothing);

    await paste(tester, 'https://youtu.be/retry000000');
    expect(find.text('暫時無法向 YouTube 確認這支影片，請稍後再試'), findsOneWidget);
    previews['https://youtu.be/retry000000'] = _preview(id: 'retry000000');
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('暫時無法向 YouTube 確認這支影片，請稍後再試'), findsNothing);
    expect(titleText(tester), 'Me at the zoo');
    expect(calls(_previewPath).last.body, contains('retry000000'));
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('換網址時舊的預覽晚回來：丟掉，標題換成新影片的', (tester) async {
    mock(
      previews: {
        _zooUrl: _preview(),
        _otherUrl: _preview(id: 'abcdefghijk', title: '太魯閣族織布'),
      },
      delays: {_zooUrl: const Duration(seconds: 2)},
    );
    await open(tester);
    await tester.enterText(urlField(), _zooUrl);
    await tester.pump();
    await tester.enterText(urlField(), _otherUrl);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(calls(_previewPath), hasLength(2));
    expect(titleText(tester), '太魯閣族織布');
    expect(find.text('Me at the zoo'), findsNothing);
  });

  testWidgets('換網址：沒改過的標題換成新影片的，自己改過的不動', (tester) async {
    mock(
      previews: {
        _zooUrl: _preview(),
        _otherUrl: _preview(id: 'abcdefghijk', title: '太魯閣族織布'),
      },
    );
    await open(tester);
    await paste(tester, _zooUrl);
    expect(titleText(tester), 'Me at the zoo');
    await paste(tester, _otherUrl);
    expect(titleText(tester), '太魯閣族織布');

    await tester.enterText(find.byType(TextField).at(1), '自己的標題');
    await paste(tester, _zooUrl);
    expect(titleText(tester), '自己的標題');
  });

  testWidgets('上架時 409 VIDEO_EXISTS：提示並把預覽標成已上架，上架鍵停用', (tester) async {
    mock(
      previews: {_zooUrl: _preview()},
      create: jsonResponse({
        'error': {
          'code': 'VIDEO_EXISTS',
          'message': '這支影片已經上架過',
          'video_id': 101,
        },
      }, status: 409),
    );
    await open(tester);
    await paste(tester, _zooUrl);
    await chooseCategory(tester, '文化紀錄');
    expect(find.text('這支影片已經上架過'), findsNothing);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AdminCard),
        matching: find.text('這支影片已經上架過'),
      ),
      findsOneWidget,
      reason: '預覽卡顯示已上架',
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(AdminVideoUploadScreen), findsOneWidget);
    expect(popped, isNull);
    expect(submitEnabled(tester), isFalse);
    expect(calls(_createPath), hasLength(1));
  });

  testWidgets('鍵盤整詞輸入不像網址：照樣等停止輸入才預覽', (tester) async {
    mock();
    await open(tester);
    await tester.enterText(urlField(), 'w');
    await tester.enterText(urlField(), 'watch?v=');
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls(_previewPath), isEmpty, reason: '一次多個字但不像網址，不立刻送');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(calls(_previewPath), hasLength(1));
    expect(jsonDecode(calls(_previewPath).single.body), {'url': 'watch?v='});
  });

  testWidgets('打到一半再貼上網址的其餘部分：像網址就立刻預覽', (tester) async {
    mock(previews: {_zooUrl: _preview()});
    await open(tester);
    await tester.enterText(urlField(), 'h');
    await tester.enterText(urlField(), _zooUrl);
    await tester.pump();
    expect(calls(_previewPath), hasLength(1));
    await tester.pumpAndSettle();
    expect(titleText(tester), 'Me at the zoo');
  });

  testWidgets('填新分類：上架後重抓影音分類清單；沒改標題時不送，由後端帶入', (tester) async {
    mock(previews: {_zooUrl: _preview()});
    await open(tester);
    await paste(tester, _zooUrl);
    await tester.enterText(find.byType(TextField).at(1), '');
    await chooseCategory(tester, '＋新增分類');
    await tester.enterText(find.widgetWithText(TextField, '新分類名稱'), '祭儀');
    await tester.pumpAndSettle();
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    final body = jsonDecode(calls(_createPath).single.body) as Map;
    expect(body['category'], '祭儀');
    expect(body.containsKey('title'), isFalse);
    expect(popped, isTrue);
    expect(calls(_appCategoriesPath), isNotEmpty);
  });

  testWidgets('選擇影片檔：顯示即將開放，沒有上架鍵', (tester) async {
    mock();
    await open(tester);
    await tester.tap(find.text('選擇影片檔'));
    await tester.pumpAndSettle();
    expect(find.text('選擇影片檔即將開放，目前請先用 YouTube 網址上架。'), findsOneWidget);
    expect(submitButton(), findsNothing);
    expect(urlField(), findsNothing);
  });

  testWidgets('403 ADMIN_ONLY：退出後台', (tester) async {
    mock(
      previews: {
        _zooUrl: errorResponse('ADMIN_ONLY', status: 403, message: '只有管理員可以使用'),
      },
    );
    UserService.currentUid = 1;
    await open(tester);
    await paste(tester, _zooUrl);
    expect(find.text('開啟'), findsOneWidget);
    expect(find.byType(AdminVideoUploadScreen), findsNothing);
    expect(find.text('只有管理員可以使用'), findsOneWidget);
  });
}
