// App 層級上傳服務：一次一支（UploadBusy）、進度與狀態、中斷後重試、放棄刪暫存、完成後移除。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

const _multiple = 256 * 1024;

class _FakeSource implements ChunkSource {
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

UploadSession _session(int size) => UploadSession(
  sessionUrl: Uri.parse('https://storage.googleapis.com/upload?upload_id=x'),
  size: size,
  chunkMultiple: _multiple,
);

/// 假雲端：照實收段；[failOnChunk] 指定第幾個上傳段（從 1 起）回 503。
class _Gcs {
  final int size;
  int received = 0;
  int? failOnChunk;
  int _chunks = 0;

  /// 設了就卡住每個請求直到 complete，用來觀察「傳送中」。
  Completer<void>? gate;

  _Gcs(this.size);

  http.Response _status() => received >= size
      ? http.Response('{}', 200)
      : http.Response(
          '',
          308,
          headers: received == 0 ? {} : {'range': 'bytes=0-${received - 1}'},
        );

  MockClient get client => MockClient((request) async {
    await gate?.future;
    final range = request.headers['Content-Range']!;
    if (range.startsWith('bytes */')) return _status();
    if (++_chunks == failOnChunk) return http.Response('', 503);
    final end = int.parse(RegExp(r'-(\d+)/').firstMatch(range)!.group(1)!) + 1;
    received = end;
    return _status();
  });
}

void main() {
  final manager = VideoUploadManager.instance;
  late _Gcs gcs;

  void useGcs(int size) {
    gcs = _Gcs(size);
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      chunkSize: _multiple,
      client: gcs.client,
    );
  }

  Future<void> settle() => pumpEventQueue(times: 50);

  tearDown(() => manager.resetForTest());

  test('傳完變 done、進度到總大小，暫存檔刪掉；dismiss 後清空', () async {
    useGcs(_multiple * 3);
    final source = _FakeSource(_multiple * 3);
    final states = <UploadState?>[];
    void listener() => states.add(manager.active.value?.state);
    manager.active.addListener(listener);
    addTearDown(() => manager.active.removeListener(listener));

    manager.start(_video, _session(_multiple * 3), source);
    expect(manager.active.value!.state, UploadState.uploading);
    expect(manager.isBusy, isTrue);
    await settle();

    final active = manager.active.value!;
    expect(active.state, UploadState.done);
    expect(active.video.id, 107);
    expect(active.progress.sent, _multiple * 3);
    expect(states, contains(UploadState.uploading));
    expect(manager.isBusy, isFalse);
    expect(source.discarded, 1);

    manager.dismiss();
    expect(manager.active.value, isNull);
  });

  test('傳送中或中斷時再 start 丟 UploadBusy；完成後可以開始下一支', () async {
    useGcs(_multiple * 2);
    gcs.gate = Completer<void>();
    manager.start(_video, _session(_multiple * 2), _FakeSource(_multiple * 2));
    expect(
      () => manager.start(
        _video,
        _session(_multiple * 2),
        _FakeSource(_multiple * 2),
      ),
      throwsA(isA<UploadBusy>()),
    );
    gcs.gate!.complete();
    await settle();
    expect(manager.active.value!.state, UploadState.done);

    useGcs(_multiple);
    manager.start(_video, _session(_multiple), _FakeSource(_multiple));
    await settle();
    expect(manager.active.value!.state, UploadState.done);
  });

  test('中途 503 → interrupted（仍算佔用），retry 從雲端已收到處接著傳完', () async {
    useGcs(_multiple * 3);
    gcs.failOnChunk = 2;
    final source = _FakeSource(_multiple * 3);

    manager.start(_video, _session(_multiple * 3), source);
    await settle();
    final interrupted = manager.active.value!;
    expect(interrupted.state, UploadState.interrupted);
    expect(interrupted.sessionExpired, isFalse);
    expect(interrupted.progress.sent, _multiple);
    expect(manager.isBusy, isTrue);
    expect(
      () => manager.start(_video, _session(1), _FakeSource(1)),
      throwsA(isA<UploadBusy>()),
    );
    expect(source.discarded, 0, reason: '中斷時保留暫存檔供重試');

    manager.retry();
    expect(manager.active.value!.state, UploadState.uploading);
    await settle();
    expect(manager.active.value!.state, UploadState.done);
    expect(gcs.received, _multiple * 3);
  });

  test('工作階段失效（404）→ interrupted 且 sessionExpired', () async {
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      client: MockClient((_) async => http.Response('', 404)),
    );
    manager.start(_video, _session(_multiple), _FakeSource(_multiple));
    await settle();
    expect(manager.active.value!.state, UploadState.interrupted);
    expect(manager.active.value!.sessionExpired, isTrue);
  });

  test('放棄：清空狀態、刪暫存檔，之後可以開始新的', () async {
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      client: MockClient((_) async => http.Response('', 503)),
    );
    final source = _FakeSource(_multiple);
    manager.start(_video, _session(_multiple), source);
    await settle();
    expect(manager.active.value!.state, UploadState.interrupted);

    await manager.cancel();
    expect(manager.active.value, isNull);
    expect(manager.isBusy, isFalse);
    expect(source.discarded, 1);
  });

  test('retry、dismiss 在不對的狀態下不做事', () async {
    manager.retry();
    manager.dismiss();
    expect(manager.active.value, isNull);

    useGcs(_multiple);
    gcs.gate = Completer<void>();
    manager.start(_video, _session(_multiple), _FakeSource(_multiple));
    manager.dismiss();
    manager.retry();
    expect(manager.active.value!.state, UploadState.uploading);
    gcs.gate!.complete();
    await settle();
  });
}
