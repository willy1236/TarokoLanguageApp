// 重新上傳頁（後台影片 T-09）：顯示影片標題與失敗原因、共用選檔區塊、送出呼叫 retry 後交給上傳服務
// 並換成進度頁、409／404 回列表重抓、建立上傳錯誤提示、一次一支（選檔與送出前都擋）、
// 沒送出就刪暫存複本。

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
import 'package:flutter_application_1/screens/admin/admin_video_reupload_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_progress_screen.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/video_file_picker.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _retryPath = '/api/admin/videos/98/retry';

const _failed = AdminVideo(
  id: 98,
  title: '織布教學',
  description: '外婆示範傳統織布',
  category: 'cultural',
  source: 'hls',
  status: 'failed',
  failReason: '轉檔失敗：無法讀取影片',
  tribeId: 3,
);

const _mp4Info = UploadFileInfo(
  name: 'weaving.mp4',
  size: 299892736,
  contentType: 'video/mp4',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late List<VideoPickSource> pickedFrom;
  late _FakeSource source;
  late AdminVideoReuploadResult? result;
  late bool closed;

  /// retry 回 [retry]（Map 為 200，http.Response 原樣，Completer 等它完成）。
  void mock({Object? retry}) {
    requests = [];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      if (r.url.path == _retryPath) {
        final res =
            retry ?? loadSpecFixtureMap('post_api_admin_videos_retry.json');
        if (res is Completer<http.Response>) return res.future;
        return res is http.Response ? res : jsonResponse(res);
      }
      if (r.url.path == '/api/me') {
        return jsonResponse({
          'uid': 1,
          'created_at': '2026-01-01T00:00:00Z',
          'role': 'user',
        });
      }
      fail('沒有準備 ${r.method} ${r.url}');
    });
  }

  /// 選檔回 [info]（null＝取消）。
  void fakePicker({UploadFileInfo? info = _mp4Info, Object? error}) {
    pickedFrom = [];
    source = _FakeSource(info?.size ?? 0);
    adminVideoPickerOverride = (from, {onPreparing}) async {
      pickedFrom.add(from);
      if (error != null) throw error;
      return info == null ? null : PickedVideoFile(info: info, source: source);
    };
  }

  /// 另一支影片佔住上傳服務（上傳器卡住不回）。
  void startOtherUpload() {
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
      fileName: 'other.mp4',
    );
  }

  setUp(() {
    stubCommonChannels();
    result = null;
    closed = false;
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
    restoreHttp();
  });

  List<http.Request> retryCalls() =>
      requests.where((r) => r.url.path == _retryPath).toList();

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
              onPressed: () async {
                result = await pushAdmin<AdminVideoReuploadResult>(
                  context,
                  const AdminVideoReuploadScreen(video: _failed),
                );
                closed = true;
              },
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  Finder submitButton() => find.widgetWithText(FilledButton, '重新上傳');

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submitButton()).onPressed != null;

  Future<void> pickFromGallery(WidgetTester tester) async {
    await tester.tap(find.text('從相簿'));
    await tester.pumpAndSettle();
  }

  testWidgets('顯示標題與失敗原因；選檔後送出 retry，交給上傳服務並換成進度頁，回列表帶回處理中的影片', (tester) async {
    mock();
    fakePicker();
    await open(tester);

    expect(find.text('織布教學'), findsOneWidget);
    expect(find.text('失敗原因：轉檔失敗：無法讀取影片'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: '不能改標題、分類');
    expect(submitEnabled(tester), isFalse, reason: '還沒選檔');

    await pickFromGallery(tester);
    expect(pickedFrom, [VideoPickSource.gallery]);
    expect(find.text('weaving.mp4'), findsOneWidget);
    expect(find.text('影片較大，建議使用 Wi-Fi'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(retryCalls().single.method, 'POST');
    expect(jsonDecode(retryCalls().single.body), {
      'file_name': 'weaving.mp4',
      'file_size': 299892736,
      'content_type': 'video/mp4',
    });
    expect(find.byType(AdminVideoUploadProgressScreen), findsOneWidget);
    expect(find.byType(AdminVideoReuploadScreen), findsNothing);
    expect(closed, isTrue);
    expect(
      result,
      isA<AdminVideoReuploaded>().having(
        (r) => r.video.status,
        'status',
        'processing',
      ),
    );
    final active = VideoUploadManager.instance.active.value!;
    expect(active.video.id, 98);
    expect(active.state, UploadState.uploading);
    expect(active.progress.total, 299892736);
    expect(source.discarded, 0, reason: '交給上傳服務了，不能刪');
    // 雲端卡住不回：停掉上傳，請求逾時的計時器才不會留到測試結束。
    await VideoUploadManager.instance.cancel();
  });

  for (final (code, status, message) in [
    ('VIDEO_NOT_FAILED', 409, '這支影片的狀態已改變，列表已重新整理'),
    ('VIDEO_NOT_FOUND', 404, '這支影片已不存在'),
  ]) {
    testWidgets('retry 回 $status $code：提示並回列表重抓', (tester) async {
      mock(retry: errorResponse(code, status: status));
      fakePicker();
      await open(tester);
      await pickFromGallery(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(AdminVideoReuploadScreen), findsNothing);
      expect(result, isA<AdminVideoReuploadStale>());
      expect(VideoUploadManager.instance.active.value, isNull);
      expect(source.discarded, 1, reason: '沒送出的暫存複本要刪');
    });
  }

  for (final (code, status, message) in [
    ('UPLOAD_SESSION_FAILED', 502, '暫時無法建立上傳，請稍後再試'),
    ('UNSUPPORTED_VIDEO_TYPE', 400, '只能上傳 mp4、mov 影片檔'),
    ('VIDEO_TOO_LARGE', 413, '影片檔最大 2GB，請壓縮或剪短後再上傳'),
  ]) {
    testWidgets('retry 回 $status $code：提示並停在這頁，可再試', (tester) async {
      mock(retry: errorResponse(code, status: status));
      fakePicker();
      await open(tester);
      await pickFromGallery(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(AdminVideoReuploadScreen), findsOneWidget);
      expect(submitEnabled(tester), isTrue);
      expect(VideoUploadManager.instance.active.value, isNull);
      expect(closed, isFalse);
    });
  }

  testWidgets('格式或大小不符：顯示原因，不能送出', (tester) async {
    mock();
    fakePicker(error: const VideoFileRejected('只能上傳 mp4、mov 影片檔'));
    await open(tester);
    await pickFromGallery(tester);

    expect(
      find.byKey(const ValueKey('admin-video-file-error')),
      findsOneWidget,
    );
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('已有一支在上傳：選檔時提示等它傳完，不開挑選器', (tester) async {
    mock();
    fakePicker();
    startOtherUpload();
    await open(tester);
    await tester.tap(find.text('從檔案'));
    await tester.pumpAndSettle();

    expect(pickedFrom, isEmpty);
    expect(find.text('已有一支影片正在上傳，請等它傳完再上傳下一支'), findsOneWidget);
    await VideoUploadManager.instance.cancel();
  });

  testWidgets('選好檔後才有別支開始上傳：送出時擋下，不呼叫 retry（免得影片變處理中卻沒人傳）', (tester) async {
    mock();
    fakePicker();
    await open(tester);
    await pickFromGallery(tester);
    startOtherUpload();
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(retryCalls(), isEmpty);
    expect(find.text('已有一支影片正在上傳，請等它傳完再上傳下一支'), findsOneWidget);
    expect(find.byType(AdminVideoReuploadScreen), findsOneWidget);
    expect(VideoUploadManager.instance.active.value!.video.id, 99);
    await VideoUploadManager.instance.cancel();
  });

  testWidgets('retry 成功後才發現別支已開始上傳：提示並回列表重抓（影片已是處理中）', (tester) async {
    final response = Completer<http.Response>();
    mock(retry: response);
    fakePicker();
    await open(tester);
    await pickFromGallery(tester);
    await tester.tap(submitButton());
    await tester.pump();
    expect(retryCalls(), hasLength(1));

    // 請求期間別支先開始上傳。
    startOtherUpload();
    response.complete(
      jsonResponse(loadSpecFixtureMap('post_api_admin_videos_retry.json')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已有一支影片正在上傳，請等它傳完再上傳下一支'), findsOneWidget);
    expect(find.byType(AdminVideoReuploadScreen), findsNothing);
    expect(find.byType(AdminVideoUploadProgressScreen), findsNothing);
    expect(result, isA<AdminVideoReuploadStale>());
    expect(VideoUploadManager.instance.active.value!.video.id, 99);
    expect(source.discarded, 1, reason: '沒交給上傳服務的暫存複本要刪');
    await VideoUploadManager.instance.cancel();
  });

  testWidgets('選了沒送出就離開：刪掉暫存複本，結果是 null', (tester) async {
    mock();
    fakePicker();
    await open(tester);
    await pickFromGallery(tester);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(source.discarded, 1);
    expect(closed, isTrue);
    expect(result, isNull);
    expect(retryCalls(), isEmpty);
  });

  testWidgets('網頁與桌面：只有一個選檔按鈕，不顯示 Wi-Fi 提醒', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mock();
    fakePicker();
    await open(tester);

    expect(find.text('從相簿'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, '選擇影片檔'));
    await tester.pumpAndSettle();
    expect(pickedFrom, [VideoPickSource.files]);
    expect(find.text('影片較大，建議使用 Wi-Fi'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
