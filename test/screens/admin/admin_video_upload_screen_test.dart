// 上傳影片頁（後台影片 T-03）：貼 YouTube 網址預覽後上架。
// 預覽帶入標題、已上架與不允許嵌入的提示、各種錯誤提示、舊預覽丟棄、上架送出與錯誤、
// 新分類刷新。
// 選擇影片檔（後台影片 T-04）：手機兩種來源、準備中、格式大小擋下、Wi-Fi 提醒（只有手機）、
// 標題必填、送出後換成進度頁、一次一支、建立錯誤提示、沒送出就刪暫存複本。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_progress_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_screen.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_widgets.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/video_file_picker.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _previewPath = '/api/admin/videos/youtube/preview';
const _createPath = '/api/admin/videos';
const _adminCategoriesPath = '/api/admin/categories/videos';
const _appCategoriesPath = '/api/videos/categories';

const _zooUrl = 'https://youtu.be/jNQXAC9IVRw';
const _otherUrl = 'https://www.youtube.com/watch?v=abcdefghijk';

const _movInfo = UploadFileInfo(
  name: 'IMG_0001.MOV',
  size: 431864320,
  contentType: 'video/quicktime',
);

/// 選檔回傳的讀檔來源；只記有沒有被刪暫存。
class _FakeSource implements ChunkSource {
  @override
  String? get path => null;

  @override
  bool get temporary => false;

  @override
  final int size;
  int discarded = 0;

  _FakeSource(this.size);

  @override
  Future<Uint8List> read(int start, int end) async => Uint8List(end - start);

  @override
  Future<void> close() async {}

  @override
  Future<void> discard() async => discarded++;
}

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

  group('選擇影片檔', () {
    late List<VideoPickSource> pickedFrom;
    late _FakeSource source;

    /// 選檔回 [info]（null＝取消）；[onPick] 可在回傳前做事（例如觸發準備中）。
    void fakePicker({
      UploadFileInfo? info = _movInfo,
      Object? error,
      Future<void> Function(VoidCallback? onPreparing)? onPick,
    }) {
      pickedFrom = [];
      source = _FakeSource(info?.size ?? 0);
      adminVideoPickerOverride = (from, {onPreparing}) async {
        pickedFrom.add(from);
        await onPick?.call(onPreparing);
        if (error != null) throw error;
        return info == null
            ? null
            : PickedVideoFile(info: info, source: source);
      };
    }

    setUp(() {
      // 上傳器卡住不連網路；進度頁只看狀態。
      VideoUploadManager.uploaderFactory = (session, src) => ResumableUploader(
        session,
        src,
        client: MockClient((_) => Completer<http.Response>().future),
      );
    });
    tearDown(() async {
      adminVideoPickerOverride = null;
      debugDefaultTargetPlatformOverride = null;
      await VideoUploadManager.instance.resetForTest();
    });

    Future<void> openFileTab(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('選擇影片檔'));
      await tester.pumpAndSettle();
    }

    Finder uploadButton() => find.widgetWithText(FilledButton, '上傳');

    bool uploadEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(uploadButton()).onPressed != null;

    testWidgets('手機：從相簿、從檔案；選好顯示檔名大小與 Wi-Fi 提醒，標題必填，送出後換成進度頁', (tester) async {
      mock(create: loadSpecFixtureMap('post_api_admin_videos_upload.json'));
      fakePicker();
      await openFileTab(tester);

      expect(find.text('從相簿'), findsOneWidget);
      expect(find.text('從檔案'), findsOneWidget);
      expect(urlField(), findsNothing);
      expect(uploadEnabled(tester), isFalse, reason: '還沒選檔不能上傳');
      expect(find.text('影片較大，建議使用 Wi-Fi'), findsNothing);

      await tester.tap(find.text('從相簿'));
      await tester.pumpAndSettle();
      expect(pickedFrom, [VideoPickSource.gallery]);
      expect(find.text('IMG_0001.MOV'), findsOneWidget);
      expect(find.text('411.9 MB'), findsOneWidget);
      expect(find.text('影片較大，建議使用 Wi-Fi'), findsOneWidget);
      expect(uploadEnabled(tester), isTrue);

      await chooseCategory(tester, '文化紀錄');
      await tester.tap(uploadButton());
      await tester.pumpAndSettle();
      expect(find.text('標題必填'), findsOneWidget);
      expect(calls(_createPath), isEmpty);

      await tester.enterText(find.byType(TextField).first, '部落祭典紀錄');
      await tester.tap(uploadButton());
      await tester.pumpAndSettle();

      expect(jsonDecode(calls(_createPath).single.body), {
        'source': 'upload',
        'file_name': 'IMG_0001.MOV',
        'file_size': _movInfo.size,
        'content_type': 'video/quicktime',
        'title': '部落祭典紀錄',
        'category': 'cultural',
      });
      expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
      expect(find.byType(AdminVideoUploadScreen), findsNothing);
      expect(popped, isTrue, reason: '列表重抓，看得到這支處理中');
      final active = VideoUploadManager.instance.active.value!;
      expect(active.video.id, 107);
      expect(active.state, UploadState.uploading);
      expect(source.discarded, 0, reason: '交給上傳服務了，不能刪');
      // 雲端卡住不回：停掉上傳，請求逾時的計時器才不會留到測試結束。
      await VideoUploadManager.instance.cancel();
    });

    testWidgets('從檔案：選檔中顯示「準備檔案中」，複製完才顯示檔案', (tester) async {
      mock();
      final copying = Completer<void>();
      fakePicker(
        onPick: (onPreparing) async {
          onPreparing?.call();
          await copying.future;
        },
      );
      await openFileTab(tester);

      await tester.tap(find.text('從檔案'));
      await tester.pump();
      expect(pickedFrom, [VideoPickSource.files]);
      expect(find.text('準備檔案中…大檔案需要一點時間'), findsOneWidget);
      expect(uploadEnabled(tester), isFalse);

      copying.complete();
      await tester.pumpAndSettle();
      expect(find.text('準備檔案中…大檔案需要一點時間'), findsNothing);
      expect(find.text('IMG_0001.MOV'), findsOneWidget);
    });

    testWidgets('格式或大小不符：顯示原因，不能上傳', (tester) async {
      mock();
      fakePicker(error: const VideoFileRejected('影片檔最大 2GB，請壓縮或剪短後再上傳'));
      await openFileTab(tester);
      await tester.tap(find.text('從檔案'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-video-file-error')),
        findsOneWidget,
      );
      expect(find.text('影片檔最大 2GB，請壓縮或剪短後再上傳'), findsOneWidget);
      expect(uploadEnabled(tester), isFalse);
    });

    testWidgets('取消選檔：維持原樣', (tester) async {
      mock();
      fakePicker(info: null);
      await openFileTab(tester);
      await tester.tap(find.text('從相簿'));
      await tester.pumpAndSettle();
      expect(uploadEnabled(tester), isFalse);
      expect(
        find.byKey(const ValueKey('admin-video-file-error')),
        findsNothing,
      );
    });

    testWidgets('已有一支在上傳：選檔時提示等它傳完，不開挑選器', (tester) async {
      mock();
      fakePicker();
      VideoUploadManager.instance.start(
        const AdminVideo(
          id: 99,
          title: '上一支',
          category: 'cultural',
          source: 'hls',
          status: 'processing',
        ),
        UploadSession(
          sessionUrl: Uri.parse('https://storage.googleapis.com/u'),
          size: 1024,
          chunkMultiple: 262144,
        ),
        _FakeSource(1024),
      );
      await openFileTab(tester);
      await tester.tap(find.text('從檔案'));
      await tester.pumpAndSettle();

      expect(pickedFrom, isEmpty);
      expect(find.text('已有一支影片正在上傳，請等它傳完再上傳下一支'), findsOneWidget);
      // 雲端卡住不回：停掉上傳，請求逾時的計時器才不會留到測試結束。
      await VideoUploadManager.instance.cancel();
    });

    for (final (code, status, message) in [
      ('UPLOAD_SESSION_FAILED', 502, '暫時無法建立上傳，請稍後再試'),
      ('UNSUPPORTED_VIDEO_TYPE', 400, '只能上傳 mp4、mov 影片檔'),
      ('VIDEO_TOO_LARGE', 413, '影片檔最大 2GB，請壓縮或剪短後再上傳'),
    ]) {
      testWidgets('建立回 $status $code：提示並停在上傳頁', (tester) async {
        mock(create: errorResponse(code, status: status));
        fakePicker();
        await openFileTab(tester);
        await tester.tap(find.text('從相簿'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '部落祭典紀錄');
        await chooseCategory(tester, '文化紀錄');
        await tester.tap(uploadButton());
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.byType(AdminVideoUploadScreen), findsOneWidget);
        expect(uploadEnabled(tester), isTrue, reason: '可以再試一次');
        expect(VideoUploadManager.instance.active.value, isNull);
        expect(popped, isNull);
      });
    }

    testWidgets('選了沒送出就離開：刪掉暫存複本', (tester) async {
      mock();
      fakePicker();
      await openFileTab(tester);
      await tester.tap(find.text('從相簿'));
      await tester.pumpAndSettle();
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(source.discarded, 1);
    });

    testWidgets('網頁與桌面：只有一個選檔按鈕，不顯示 Wi-Fi 提醒', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      mock();
      fakePicker();
      await openFileTab(tester);

      expect(find.text('從相簿'), findsNothing);
      expect(find.text('從檔案'), findsNothing);
      final pickButton = find.widgetWithText(OutlinedButton, '選擇影片檔');
      expect(pickButton, findsOneWidget);
      await tester.tap(pickButton);
      await tester.pumpAndSettle();
      expect(pickedFrom, [VideoPickSource.files]);
      expect(find.text('IMG_0001.MOV'), findsOneWidget);
      expect(find.text('影片較大，建議使用 Wi-Fi'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
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
