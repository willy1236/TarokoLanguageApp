// App 層級上傳服務：一次一支（UploadBusy）、進度與狀態、中斷後重試、放棄刪暫存、完成後移除、
// 未完成清單的寫入與刪除、App 重開後續傳。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/pending_uploads.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';
import 'package:flutter_application_1/services/video_upload/upload_files_io.dart';
import 'package:flutter_application_1/services/video_upload/video_file_picker.dart';
import 'package:flutter_application_1/services/video_upload/video_upload_manager.dart';

const _multiple = 256 * 1024;

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

/// 讀檔卡在 [gate]，記下刪檔時是否還在讀。
class _GatedSource extends _FakeSource {
  final gate = Completer<void>();
  bool reading = false;
  bool discardedWhileReading = false;

  _GatedSource(super.size);

  @override
  Future<Uint8List> read(int start, int end) async {
    reading = true;
    await gate.future;
    reading = false;
    return Uint8List(end - start);
  }

  @override
  Future<void> discard() async {
    if (reading) discardedWhileReading = true;
    await super.discard();
  }
}

const _fileName = 'IMG_0001.MOV';

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

  MockClient get client => MockClient(handle);

  Future<http.Response> handle(http.Request request) async {
    await gate?.future;
    final range = request.headers['Content-Range']!;
    if (range.startsWith('bytes */')) return _status();
    if (++_chunks == failOnChunk) return http.Response('', 503);
    final end = int.parse(RegExp(r'-(\d+)/').firstMatch(range)!.group(1)!) + 1;
    received = end;
    return _status();
  }
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
      retryDelays: const [], // 中斷就停，測試 interrupted
    );
  }

  Future<void> settle() => pumpEventQueue(times: 50);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PendingUploads.instance.resetForTest();
  });
  tearDown(() => manager.resetForTest());

  test('傳完變 done、進度到總大小，暫存檔刪掉；dismiss 後清空', () async {
    useGcs(_multiple * 3);
    final source = _FakeSource(_multiple * 3);
    final states = <UploadState?>[];
    void listener() => states.add(manager.active.value?.state);
    manager.active.addListener(listener);
    addTearDown(() => manager.active.removeListener(listener));

    manager.start(_video, _session(_multiple * 3), source, fileName: _fileName);
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
    manager.start(
      _video,
      _session(_multiple * 2),
      _FakeSource(_multiple * 2),
      fileName: _fileName,
    );
    expect(
      () => manager.start(
        _video,
        _session(_multiple * 2),
        _FakeSource(_multiple * 2),
        fileName: _fileName,
      ),
      throwsA(isA<UploadBusy>()),
    );
    gcs.gate!.complete();
    await settle();
    expect(manager.active.value!.state, UploadState.done);

    useGcs(_multiple);
    manager.start(
      _video,
      _session(_multiple),
      _FakeSource(_multiple),
      fileName: _fileName,
    );
    await settle();
    expect(manager.active.value!.state, UploadState.done);
  });

  test('中途 503 → interrupted（仍算佔用），retry 從雲端已收到處接著傳完', () async {
    useGcs(_multiple * 3);
    gcs.failOnChunk = 2;
    final source = _FakeSource(_multiple * 3);

    manager.start(_video, _session(_multiple * 3), source, fileName: _fileName);
    await settle();
    final interrupted = manager.active.value!;
    expect(interrupted.state, UploadState.interrupted);
    expect(interrupted.sessionExpired, isFalse);
    expect(interrupted.progress.sent, _multiple);
    expect(manager.isBusy, isTrue);
    expect(
      () => manager.start(
        _video,
        _session(1),
        _FakeSource(1),
        fileName: _fileName,
      ),
      throwsA(isA<UploadBusy>()),
    );
    expect(source.discarded, 0, reason: '中斷時保留暫存檔供重試');

    manager.retry();
    expect(manager.active.value!.state, UploadState.uploading);
    await settle();
    expect(manager.active.value!.state, UploadState.done);
    expect(gcs.received, _multiple * 3);
  });

  test('自動重試用完而中斷後手動重試：不沿用「自動重試中」的狀態', () async {
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      client: MockClient((_) async => http.Response('', 503)),
      retryDelays: const [Duration.zero],
    );
    manager.start(
      _video,
      _session(_multiple),
      _FakeSource(_multiple),
      fileName: _fileName,
    );
    await settle();
    expect(manager.active.value!.state, UploadState.interrupted);
    expect(manager.active.value!.progress.retrying, isTrue);

    manager.retry();
    expect(manager.active.value!.state, UploadState.uploading);
    expect(manager.active.value!.progress.retrying, isFalse);
  });

  test('工作階段失效（404）→ interrupted 且 sessionExpired', () async {
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      client: MockClient((_) async => http.Response('', 404)),
    );
    manager.start(
      _video,
      _session(_multiple),
      _FakeSource(_multiple),
      fileName: _fileName,
    );
    await settle();
    expect(manager.active.value!.state, UploadState.interrupted);
    expect(manager.active.value!.sessionExpired, isTrue);
  });

  test('放棄：清空狀態、刪暫存檔，之後可以開始新的', () async {
    VideoUploadManager.uploaderFactory = (session, source) => ResumableUploader(
      session,
      source,
      client: MockClient((_) async => http.Response('', 503)),
      retryDelays: const [],
    );
    final source = _FakeSource(_multiple);
    manager.start(_video, _session(_multiple), source, fileName: _fileName);
    await settle();
    expect(manager.active.value!.state, UploadState.interrupted);

    await manager.cancel();
    expect(manager.active.value, isNull);
    expect(manager.isBusy, isFalse);
    expect(source.discarded, 1);
  });

  test('讀檔進行中放棄：等讀完、關檔後才刪暫存檔', () async {
    useGcs(_multiple * 2);
    final source = _GatedSource(_multiple * 2);
    manager.start(_video, _session(_multiple * 2), source, fileName: _fileName);
    await settle();
    expect(source.reading, isTrue, reason: '卡在讀第一段');

    final cancelling = manager.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(source.discarded, 0, reason: '讀取還沒結束，不能刪');

    source.gate.complete();
    await cancelling;
    expect(source.discardedWhileReading, isFalse);
    expect(source.discarded, 1);
  });

  test('retry、dismiss 在不對的狀態下不做事', () async {
    manager.retry();
    manager.dismiss();
    expect(manager.active.value, isNull);

    useGcs(_multiple);
    gcs.gate = Completer<void>();
    manager.start(
      _video,
      _session(_multiple),
      _FakeSource(_multiple),
      fileName: _fileName,
    );
    manager.dismiss();
    manager.retry();
    expect(manager.active.value!.state, UploadState.uploading);
    gcs.gate!.complete();
    await settle();
  });

  group('未完成清單', () {
    final pending = PendingUploads.instance;
    late Directory dir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      pending.resetForTest();
      dir = await Directory.systemTemp.createTemp('manager_pending_test');
      uploadDirOverride = () async => dir;
      VideoUploadManager.currentUserId = () => 20;
    });
    tearDown(() async {
      await manager.resetForTest();
      uploadDirOverride = null;
      await dir.delete(recursive: true);
    });

    /// 讀真檔案要等實際 I/O，事件佇列跑完不代表傳完。
    Future<void> waitDone() async {
      for (var i = 0; i < 200; i++) {
        if (manager.active.value?.state == UploadState.done) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await manager.pendingWrites;
    }

    /// 上傳暫存目錄裡的一個真檔案（續傳時檢查存在與大小）。
    File tempFile(String name, int size) =>
        File('${dir.path}/$name')..writeAsBytesSync(Uint8List(size));

    PendingUpload record({
      String? filePath,
      int size = _multiple * 2,
      DateTime? createdAt,
    }) => PendingUpload(
      userId: 20,
      videoId: 107,
      title: '部落祭典紀錄',
      category: 'cultural',
      session: _session(size),
      fileName: _fileName,
      filePath: filePath,
      temporaryFile: true,
      createdAt: createdAt ?? DateTime(2026, 10, 14, 9),
    );

    test('start 寫入紀錄（帳號、工作階段、檔名、路徑）；傳完刪掉', () async {
      useGcs(_multiple * 2);
      gcs.gate = Completer<void>();
      final file = tempFile('1_IMG_0001.MOV', _multiple * 2);
      manager.start(
        _video,
        _session(_multiple * 2),
        ChunkSource.io(file.path, temporary: true),
        fileName: _fileName,
      );
      await manager.pendingWrites;

      final p = pending.items.value.single;
      expect(p.userId, 20);
      expect(p.videoId, 107);
      expect(p.title, '部落祭典紀錄');
      expect(p.session.sessionUrl, _session(1).sessionUrl);
      expect(p.size, _multiple * 2);
      expect(p.fileName, _fileName);
      expect(p.filePath, file.path);
      expect(p.temporaryFile, isTrue);

      gcs.gate!.complete();
      await waitDone();
      expect(manager.active.value!.state, UploadState.done);
      expect(pending.items.value, isEmpty);
      expect(file.existsSync(), isFalse, reason: '傳完刪暫存複本');
    });

    test('網頁版（沒有路徑）也寫紀錄，路徑是 null', () async {
      useGcs(_multiple);
      gcs.gate = Completer<void>();
      manager.start(
        _video,
        _session(_multiple),
        _FakeSource(_multiple),
        fileName: _fileName,
      );
      await manager.pendingWrites;
      expect(pending.items.value.single.filePath, isNull);
      expect(pending.items.value.single.temporaryFile, isFalse);
      gcs.gate!.complete();
    });

    test('中斷時保留紀錄；放棄時刪掉', () async {
      useGcs(_multiple * 2);
      gcs.failOnChunk = 1;
      manager.start(
        _video,
        _session(_multiple * 2),
        _FakeSource(_multiple * 2),
        fileName: _fileName,
      );
      await settle();
      await manager.pendingWrites;
      expect(manager.active.value!.state, UploadState.interrupted);
      expect(pending.items.value, hasLength(1));

      await manager.cancel();
      await manager.pendingWrites;
      expect(pending.items.value, isEmpty);
    });

    test('工作階段失效：清掉紀錄', () async {
      VideoUploadManager.uploaderFactory = (session, source) =>
          ResumableUploader(
            session,
            source,
            client: MockClient((_) async => http.Response('', 410)),
          );
      manager.start(
        _video,
        _session(_multiple),
        _FakeSource(_multiple),
        fileName: _fileName,
      );
      await settle();
      await manager.pendingWrites;
      expect(manager.active.value!.sessionExpired, isTrue);
      expect(pending.items.value, isEmpty);
    });

    test('手機續傳：檔案還在且大小一致就從斷點接著傳，保留原本的建立時間', () async {
      final file = tempFile('1_IMG_0001.MOV', _multiple * 2);
      final old = record(filePath: file.path);
      await pending.save(old);
      useGcs(_multiple * 2);
      gcs.received = _multiple; // 雲端已收到一半
      final queried = <String>[];
      VideoUploadManager.uploaderFactory = (session, source) =>
          ResumableUploader(
            session,
            source,
            chunkSize: _multiple,
            retryDelays: const [],
            client: MockClient((request) {
              queried.add(request.headers['Content-Range']!);
              return gcs.handle(request);
            }),
          );

      await manager.resume(old);
      await waitDone();

      expect(queried.first, 'bytes */${_multiple * 2}');
      expect(queried[1], startsWith('bytes $_multiple-'), reason: '從斷點接著傳');
      expect(manager.active.value!.state, UploadState.done);
      expect(pending.items.value, isEmpty);
    });

    test('續傳時雲端回報早已收齊（查進度回 200）→ 直接顯示上傳完成，不再送任何段', () async {
      final requests = <String>[];
      VideoUploadManager.uploaderFactory = (session, source) =>
          ResumableUploader(
            session,
            source,
            client: MockClient((request) async {
              requests.add(request.headers['Content-Range']!);
              return http.Response('{}', 200);
            }),
          );
      final file = tempFile('1_IMG_0001.MOV', _multiple * 2);
      await pending.save(record(filePath: file.path));

      await manager.resume(record(filePath: file.path));
      await waitDone();

      expect(manager.active.value!.state, UploadState.done);
      expect(manager.active.value!.progress.fraction, 1);
      expect(requests, ['bytes */${_multiple * 2}']);
      expect(pending.items.value, isEmpty);
    });

    test('手機續傳：檔案不見或大小不符 → PendingFileMissing，不開始上傳', () async {
      await expectLater(
        manager.resume(record(filePath: '${dir.path}/gone.mov')),
        throwsA(isA<PendingFileMissing>()),
      );
      final wrongSize = tempFile('1_a.mov', 10);
      await expectLater(
        manager.resume(record(filePath: wrongSize.path)),
        throwsA(isA<PendingFileMissing>()),
      );
      await expectLater(
        manager.resume(record()),
        throwsA(isA<PendingFileMissing>()),
        reason: '沒有路徑（網頁版紀錄）要重選檔案',
      );
      expect(manager.active.value, isNull);
    });

    test('重選檔案續傳：檔名與大小相符就用新檔接著傳，舊暫存複本刪掉', () async {
      final oldFile = tempFile('1_old.mov', 1);
      final p = record(filePath: oldFile.path, size: _multiple);
      await pending.save(p);
      useGcs(_multiple);
      gcs.gate = Completer<void>();
      final newFile = tempFile('2_IMG_0001.MOV', _multiple);
      final repicked = PickedVideoFile(
        info: const UploadFileInfo(
          name: _fileName,
          size: _multiple,
          contentType: 'video/quicktime',
        ),
        source: ChunkSource.io(newFile.path, temporary: true),
      );

      await manager.resume(p, repicked: repicked);
      await manager.pendingWrites;

      expect(manager.active.value!.state, UploadState.uploading);
      expect(pending.items.value.single.filePath, newFile.path);
      expect(
        pending.items.value.single.createdAt,
        DateTime(2026, 10, 14, 9),
        reason: '同一個工作階段，建立時間不變',
      );
      expect(oldFile.existsSync(), isFalse);
      gcs.gate!.complete();
    });

    test('重選的檔案檔名或大小不符 → PendingFileMismatch，重選的暫存複本刪掉', () async {
      final p = record(size: _multiple);
      for (final (name, size) in [('other.mov', _multiple), (_fileName, 99)]) {
        final source = _FakeSource(size);
        await expectLater(
          manager.resume(
            p,
            repicked: PickedVideoFile(
              info: UploadFileInfo(
                name: name,
                size: size,
                contentType: 'video/quicktime',
              ),
              source: source,
            ),
          ),
          throwsA(isA<PendingFileMismatch>()),
        );
        expect(source.discarded, 1);
      }
      expect(manager.active.value, isNull);
    });

    test('已有一支在傳時續傳 → UploadBusy', () async {
      useGcs(_multiple);
      gcs.gate = Completer<void>();
      manager.start(
        _video,
        _session(_multiple),
        _FakeSource(_multiple),
        fileName: _fileName,
      );
      final file = tempFile('1_a.mov', _multiple);
      await expectLater(
        manager.resume(record(filePath: file.path, size: _multiple)),
        throwsA(isA<UploadBusy>()),
      );
      gcs.gate!.complete();
    });
  });
}
