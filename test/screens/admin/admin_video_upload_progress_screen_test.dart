// 影片上傳進度頁（後台影片 T-04）：進度條與大小、中斷時重試／放棄、工作階段失效只能放棄、
// 完成提示、離開後從列表上方移除。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_video_upload_progress_screen.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

import '../../helpers/widget_test_helpers.dart';

const _mb = 1024 * 1024;

class _FakeSource implements ChunkSource {
  @override
  String? get path => null;

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

const _video = AdminVideo(
  id: 107,
  title: '部落祭典紀錄',
  category: 'cultural',
  source: 'hls',
  status: 'processing',
);

/// 假雲端：收段照實回 308／200；[respond] 可攔截第 n 個上傳段（從 1 起）改回別的狀態碼，
/// 第 [holdFrom] 段起卡在 [gate]，用來觀察傳送中的畫面。
class _Gcs {
  final int size;
  int received = 0;
  int chunks = 0;
  int? Function(int chunk)? respond;
  int holdFrom = 0;
  final gate = Completer<void>();

  _Gcs(this.size);

  http.Response _status() => received >= size
      ? http.Response('{}', 200)
      : http.Response(
          '',
          308,
          headers: received == 0 ? {} : {'range': 'bytes=0-${received - 1}'},
        );

  MockClient get client => MockClient((request) async {
    final range = request.headers['Content-Range']!;
    if (range.startsWith('bytes */')) return _status();
    chunks++;
    final forced = respond?.call(chunks);
    if (forced != null) return http.Response('', forced);
    if (holdFrom > 0 && chunks >= holdFrom) await gate.future;
    received = int.parse(RegExp(r'-(\d+)/').firstMatch(range)!.group(1)!) + 1;
    return _status();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = VideoUploadManager.instance;
  late _Gcs gcs;
  late _FakeSource source;

  void startUpload(int size) {
    gcs = _Gcs(size);
    source = _FakeSource(size);
    VideoUploadManager.uploaderFactory = (session, src) =>
        ResumableUploader(session, src, chunkSize: 4 * _mb, client: gcs.client);
    manager.start(
      _video,
      UploadSession(
        sessionUrl: Uri.parse('https://storage.googleapis.com/u?upload_id=x'),
        size: size,
        chunkMultiple: 256 * 1024,
      ),
      source,
    );
  }

  setUp(stubCommonChannels);
  tearDown(() => manager.resetForTest());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  pushAdmin(context, const AdminVideoUploadProgressScreen()),
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  testWidgets('傳送中：標題、進度、已傳／總大小、剩餘；沒有取消鍵', (tester) async {
    startUpload(8 * _mb);
    gcs.holdFrom = 2;
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('部落祭典紀錄'), findsOneWidget);
    expect(find.text('上傳中'), findsOneWidget);
    expect(find.textContaining('／8.0 MB'), findsOneWidget);
    expect(find.textContaining('剩餘'), findsOneWidget);
    expect(find.text('重試'), findsNothing);
    expect(find.text('放棄'), findsNothing);
    expect(find.textContaining('可以離開這頁'), findsOneWidget);
  });

  testWidgets('中斷：顯示重試與放棄，重試後接著傳完並顯示完成提示', (tester) async {
    startUpload(8 * _mb);
    gcs.respond = (n) => n == 2 ? 503 : null;
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('上傳中斷'), findsOneWidget);
    expect(find.text('已傳 4.0 MB／8.0 MB（50%）'), findsOneWidget);
    expect(find.textContaining('按「重試」'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('上傳完成'), findsOneWidget);
    expect(find.text('上傳完成，轉檔需要幾分鐘，完成後會自動上架。'), findsOneWidget);
    expect(find.text('已傳 8.0 MB／8.0 MB（100%）'), findsOneWidget);
    expect(manager.active.value!.state, UploadState.done);

    await tester.tap(find.text('回影片管理'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminVideoUploadProgressScreen), findsNothing);
    expect(manager.active.value, isNull, reason: '看過完成畫面就從列表上方移除');
  });

  testWidgets('放棄：確認後停止上傳、刪暫存檔並離開；取消確認不動', (tester) async {
    startUpload(4 * _mb);
    gcs.respond = (_) => 503;
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('放棄'));
    await tester.pumpAndSettle();
    expect(find.text('放棄這次上傳？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(manager.active.value!.state, UploadState.interrupted);

    await tester.tap(find.text('放棄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄').last);
    await tester.pumpAndSettle();

    expect(manager.active.value, isNull);
    expect(source.discarded, 1);
    expect(find.byType(AdminVideoUploadProgressScreen), findsNothing);
  });

  testWidgets('工作階段失效：重試停用，提示放棄後重新上傳', (tester) async {
    startUpload(4 * _mb);
    gcs.respond = (_) => 410;
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('上傳連結已失效'), findsOneWidget);
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '重試'),
    );
    expect(retry.onPressed, isNull);
    expect(find.text('放棄'), findsOneWidget);
  });

  testWidgets('沒有上傳時顯示空狀態', (tester) async {
    await open(tester);
    expect(find.text('目前沒有上傳中的影片'), findsOneWidget);
  });
}
