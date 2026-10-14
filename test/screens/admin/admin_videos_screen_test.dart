// 影片管理列表：各狀態與來源的呈現、篩選與搜尋送出的參數、下一頁、下拉重整、
// 非管理員退出後台、後台首頁入口、上傳影片按鈕、上方的上傳進度與還沒傳完的上傳。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_home_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_progress_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_videos_screen.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:flutter_application_1/shared/widgets/confirm_dialog.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/pending_uploads.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/video_file_picker.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

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

class _FakeSource implements ChunkSource {
  @override
  String? get path => null;

  @override
  bool get temporary => false;

  @override
  final int size;

  _FakeSource(this.size);

  @override
  Future<Uint8List> read(int start, int end) async => Uint8List(end - start);

  @override
  Future<void> close() async {}

  @override
  Future<void> discard() async {}
}

/// 讓 App 層級上傳服務開始傳一支；雲端照 [respond] 回應（預設卡住不回）。
void _startUpload({
  Future<http.Response> Function()? respond,
  List<Duration> retryDelays = const [],
}) {
  VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
    session,
    source,
    client: MockClient(
      (_) => respond?.call() ?? Completer<http.Response>().future,
    ),
    retryDelays: retryDelays,
  );
  VideoUploadManager.instance.start(
    const AdminVideo(
      id: 107,
      title: '部落祭典紀錄',
      category: 'cultural',
      source: 'hls',
      status: 'processing',
    ),
    UploadSession(
      sessionUrl: Uri.parse('https://storage.googleapis.com/u?upload_id=x'),
      size: 8 * 1024 * 1024,
      chunkMultiple: 256 * 1024,
    ),
    _FakeSource(8 * 1024 * 1024),
    fileName: 'IMG_0001.MOV',
  );
}

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

  group('上方的上傳進度', () {
    tearDown(() => VideoUploadManager.instance.resetForTest());

    testWidgets('沒有上傳時不顯示', (tester) async {
      mock((_) => _page([_video(1)], null));
      await _open(tester);
      expect(find.byKey(const ValueKey('admin-active-upload')), findsNothing);
    });

    testWidgets('上傳中：顯示標題與進度，點它回進度頁', (tester) async {
      mock((_) => _page([_video(1)], null));
      _startUpload();
      await _open(tester);

      final banner = find.byKey(const ValueKey('admin-active-upload'));
      expect(banner, findsOneWidget);
      expect(find.text('部落祭典紀錄'), findsOneWidget);
      expect(find.text('上傳中・0.0 MB／8.0 MB'), findsOneWidget);

      await tester.tap(banner);
      await tester.pumpAndSettle();
      expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
      // 雲端卡住不回：停掉上傳，請求逾時的計時器才不會留到測試結束。
      await VideoUploadManager.instance.cancel();
    });

    testWidgets('傳完：顯示完成，看過進度頁回來就移除', (tester) async {
      mock((_) => _page([_video(1)], null));
      _startUpload(respond: () async => http.Response('{}', 200));
      await _open(tester);

      expect(find.text('上傳完成，轉檔後會自動上架・8.0 MB／8.0 MB'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-active-upload')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('回影片管理'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminVideosScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-active-upload')), findsNothing);
    });

    testWidgets('中斷：提示點進去處理', (tester) async {
      mock((_) => _page([_video(1)], null));
      _startUpload(respond: () async => http.Response('', 503));
      await _open(tester);
      expect(find.textContaining('上傳中斷，點這裡重試或放棄'), findsOneWidget);
    });

    testWidgets('網路中斷自動重試中：顯示「網路中斷，自動重試中」', (tester) async {
      mock((_) => _page([_video(1)], null));
      _startUpload(
        respond: () async => http.Response('', 503),
        retryDelays: const [Duration(minutes: 1)],
      );
      await _open(tester);
      expect(find.textContaining('網路中斷，自動重試中'), findsOneWidget);
      await VideoUploadManager.instance.cancel();
    });
  });

  group('還沒傳完的上傳（App 重開後）', () {
    late Directory dir;
    final pending = PendingUploads.instance;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('admin_videos_pending');
      UserService.currentUid = 20;
      VideoUploadManager.uploaderFactory = (session, source) =>
          ResumableUploader(
            session,
            source,
            client: MockClient((_) => Completer<http.Response>().future),
            retryDelays: const [],
          );
    });
    tearDown(() async {
      adminVideoPickerOverride = null;
      await VideoUploadManager.instance.resetForTest();
      pending.resetForTest();
      dir.deleteSync(recursive: true);
    });

    PendingUpload record({
      int videoId = 107,
      int? userId = 20,
      String? filePath,
      int size = 1024,
      DateTime? createdAt,
    }) => PendingUpload(
      userId: userId,
      videoId: videoId,
      title: '部落祭典紀錄$videoId',
      category: 'cultural',
      session: UploadSession(
        sessionUrl: Uri.parse('https://storage.googleapis.com/u?upload_id=x'),
        size: size,
        chunkMultiple: 262144,
      ),
      fileName: 'IMG_0001.MOV',
      filePath: filePath,
      temporaryFile: true,
      createdAt: createdAt ?? DateTime.now(),
    );

    /// 本機已有這些紀錄（App 重開前寫下的）。
    void stored(List<PendingUpload> records) {
      SharedPreferences.setMockInitialValues({
        'admin_video_pending_uploads': jsonEncode([
          for (final r in records) r.toJson(),
        ]),
      });
      pending.resetForTest();
    }

    PickedVideoFile picked(String name, int size, _FakeSource source) =>
        PickedVideoFile(
          info: UploadFileInfo(
            name: name,
            size: size,
            contentType: 'video/quicktime',
          ),
          source: source,
        );

    testWidgets('顯示自己還沒傳完的影片數與標題；別人的、正在傳的不列', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([
        record(videoId: 1),
        record(videoId: 2),
        record(videoId: 3, userId: 21),
        record(videoId: 107),
      ]);
      _startUpload(); // 正在傳 107
      await _open(tester);

      expect(find.text('有 2 支影片還沒傳完'), findsOneWidget);
      expect(find.text('部落祭典紀錄1'), findsOneWidget);
      expect(find.text('部落祭典紀錄2'), findsOneWidget);
      expect(find.text('部落祭典紀錄3'), findsNothing);
      expect(find.text('繼續上傳'), findsNWidgets(2));
      await VideoUploadManager.instance.cancel();
    });

    testWidgets('沒有紀錄時不顯示', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([]);
      await _open(tester);
      expect(find.byKey(const ValueKey('admin-pending-uploads')), findsNothing);
    });

    testWidgets('手機：檔案還在 → 繼續上傳從斷點接著傳，換到進度頁', (tester) async {
      mock((_) => _page([_video(1)], null));
      final file = File('${dir.path}/1_IMG_0001.MOV')
        ..writeAsBytesSync(Uint8List(1024));
      stored([record(filePath: file.path)]);
      await _open(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('繼續上傳'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
      final active = VideoUploadManager.instance.active.value!;
      expect(active.video.id, 107);
      expect(active.state, UploadState.uploading);
      // 上傳是在 runAsync 裡開始的（真的讀檔），停也要在 runAsync 裡停。
      await tester.runAsync(VideoUploadManager.instance.cancel);
    });

    testWidgets('手機：檔案不見 → 提示重選；選同一個檔案就接著傳', (tester) async {
      mock((_) => _page([_video(1)], null));
      // 檔案不見的判斷（真的查檔案）在上傳服務的單元測試；這裡用沒有路徑的紀錄走同一條路。
      stored([record()]);
      final source = _FakeSource(1024);
      adminVideoPickerOverride = (from, {onPreparing}) async =>
          picked('IMG_0001.MOV', 1024, source);
      await _open(tester);

      await tester.tap(find.text('繼續上傳'));
      await tester.pumpAndSettle();
      expect(find.text('找不到原本的影片檔'), findsOneWidget);
      expect(find.textContaining('重新選擇同一個檔案（IMG_0001.MOV，'), findsOneWidget);
      expect(find.textContaining('超過 6 小時後會在每日維護時標成失敗'), findsOneWidget);

      await tester.tap(find.text('重新選擇檔案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('從檔案'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
      expect(VideoUploadManager.instance.active.value!.video.id, 107);
      await VideoUploadManager.instance.cancel();
    });

    testWidgets('手機：檔案不見 → 對話框按「放棄」直接清掉這筆', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([record()]);
      await _open(tester);

      await tester.tap(find.text('繼續上傳'));
      await tester.pumpAndSettle();
      expect(find.text('找不到原本的影片檔'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(AppDialog), matching: find.text('放棄')),
      );
      await tester.pumpAndSettle();

      expect(find.text('找不到原本的影片檔'), findsNothing);
      expect(find.byKey(const ValueKey('admin-pending-uploads')), findsNothing);
      expect(pending.items.value, isEmpty);
      expect(VideoUploadManager.instance.active.value, isNull);
    });

    testWidgets('重選檔案時：準備中顯示「準備檔案中…」，期間其他「繼續上傳」停用', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([record(videoId: 1), record(videoId: 2)]);
      final copying = Completer<void>();
      final source = _FakeSource(1024);
      adminVideoPickerOverride = (from, {onPreparing}) async {
        onPreparing?.call();
        await copying.future;
        return picked('IMG_0001.MOV', 1024, source);
      };
      await _open(tester);

      await tester.tap(find.text('繼續上傳').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新選擇檔案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('從檔案'));
      await tester.pump();

      expect(find.text('準備檔案中…'), findsOneWidget);
      final others = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '繼續上傳'),
      );
      expect(others.onPressed, isNull, reason: '另一支的繼續上傳停用');

      copying.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
      await VideoUploadManager.instance.cancel();
    });

    testWidgets('重選的檔案和原本的不同 → 擋下並提示要選哪個檔案', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([record()]); // 沒有路徑：直接要求重選
      final source = _FakeSource(2048);
      adminVideoPickerOverride = (from, {onPreparing}) async =>
          picked('IMG_0001.MOV', 2048, source);
      await _open(tester);

      await tester.tap(find.text('繼續上傳'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新選擇檔案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('從相簿'));
      await tester.pumpAndSettle();

      expect(find.textContaining('選的檔案和原本的不同，請選 IMG_0001.MOV'), findsOneWidget);
      expect(find.byType(AdminVideoUploadProgressScreen), findsNothing);
      expect(VideoUploadManager.instance.active.value, isNull);
    });

    testWidgets('放棄：確認後清掉這筆，列表上方不再顯示', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([record()]);
      await _open(tester);

      await tester.tap(find.text('放棄'));
      await tester.pumpAndSettle();
      expect(find.text('放棄這次上傳？'), findsOneWidget);
      await tester.tap(find.text('放棄').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('admin-pending-uploads')), findsNothing);
      expect(pending.items.value, isEmpty);
    });

    testWidgets('超過一週：提示連結失效，只能放棄', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([
        record(createdAt: DateTime.now().subtract(const Duration(days: 8))),
      ]);
      await _open(tester);

      expect(find.textContaining('上傳連結已超過一週失效'), findsOneWidget);
      expect(find.text('繼續上傳'), findsNothing);
      expect(find.text('放棄'), findsOneWidget);
    });

    testWidgets('已有一支在傳時按繼續 → 提示等它傳完', (tester) async {
      mock((_) => _page([_video(1)], null));
      stored([record(videoId: 1)]);
      _startUpload();
      await _open(tester);

      await tester.tap(find.text('繼續上傳'));
      await tester.pump();
      expect(find.text('已有一支影片正在上傳，請等它傳完再繼續'), findsOneWidget);
      await VideoUploadManager.instance.cancel();
    });
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
