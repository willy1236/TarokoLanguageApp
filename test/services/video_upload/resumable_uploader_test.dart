// 分段上傳器：分段大小、Content-Range、308／200 處理、查進度解析 Range、錯誤分類、讀檔不超過一段。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/services/video_upload/chunk_source.dart';
import 'package:flutter_application_1/services/video_upload/resumable_uploader.dart';

const _multiple = 256 * 1024;
final _url = Uri.parse(
  'https://storage.googleapis.com/upload/storage/v1/b/x/o?upload_id=abc',
);

/// 記憶體裡的檔案，記下每次讀了哪一段。
class _FakeSource implements ChunkSource {
  @override
  String? get path => null;

  @override
  bool get temporary => false;

  @override
  final int size;
  final reads = <(int, int)>[];
  int closed = 0;

  _FakeSource(this.size);

  @override
  Future<Uint8List> read(int start, int end) async {
    reads.add((start, end));
    return Uint8List(end - start);
  }

  @override
  Future<void> close() async => closed++;

  @override
  Future<void> discard() async {}
}

/// 讀檔一定失敗（檔案被刪或搬走）。
class _BrokenSource extends _FakeSource {
  _BrokenSource(super.size);

  @override
  Future<Uint8List> read(int start, int end) async =>
      throw const FileSystemException('檔案不見了');
}

/// 假的雲端：照 GCS 協定收段，[persistLimit] 可讓某次只持久化部分位元組。
class _FakeGcs {
  final int size;
  int received = 0;
  final requests = <http.Request>[];

  /// 第 n 個上傳段（從 0 起）只收下這麼多位元組。
  final Map<int, int> partial;
  int _chunkIndex = 0;

  /// 依請求序號（從 0 起）直接回指定狀態碼。
  final Map<int, int> failAt;

  _FakeGcs(this.size, {this.partial = const {}, this.failAt = const {}});

  MockClient get client => MockClient(handle);

  /// 收一個請求並照 GCS 協定回應（測試可以在前面插入失敗）。
  Future<http.Response> handle(http.Request request) async {
    final index = requests.length;
    requests.add(request);
    final forced = failAt[index];
    if (forced != null) return http.Response('', forced);
    final range = request.headers['Content-Range']!;
    if (range.startsWith('bytes */')) return _status();
    final m = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(range)!;
    final start = int.parse(m.group(1)!);
    final end = int.parse(m.group(2)!) + 1;
    expect(start, received, reason: '每段要從雲端已收到的位置開始');
    expect(request.bodyBytes.length, end - start);
    expect(int.parse(m.group(3)!), size);
    final keep = partial[_chunkIndex++];
    received = keep == null ? end : start + keep;
    return _status();
  }

  http.Response _status() {
    if (received >= size) return http.Response('{}', 200);
    return http.Response(
      '',
      308,
      headers: received == 0 ? {} : {'range': 'bytes=0-${received - 1}'},
    );
  }
}

/// 記下 close 次數的 http.Client。
class _CountingClient extends http.BaseClient {
  final http.Client inner;
  int closed = 0;

  _CountingClient(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      inner.send(request);

  @override
  void close() => closed++;
}

UploadSession _session(int size) =>
    UploadSession(sessionUrl: _url, size: size, chunkMultiple: _multiple);

void main() {
  test('分段上傳：先查進度，每段大小與 Content-Range 正確，完成時關閉', () async {
    final size = _multiple * 5 + 123;
    final gcs = _FakeGcs(size);
    final source = _FakeSource(size);
    final uploader = ResumableUploader(
      _session(size),
      source,
      chunkSize: _multiple * 2,
      client: gcs.client,
    );

    final progress = await uploader.start().toList();

    expect(gcs.requests.map((r) => r.headers['Content-Range']), [
      'bytes */$size',
      'bytes 0-${_multiple * 2 - 1}/$size',
      'bytes ${_multiple * 2}-${_multiple * 4 - 1}/$size',
      'bytes ${_multiple * 4}-${size - 1}/$size',
    ]);
    expect(gcs.requests.every((r) => r.method == 'PUT'), isTrue);
    expect(gcs.requests.first.bodyBytes, isEmpty);
    expect(progress.map((p) => p.sent), [
      0,
      _multiple * 2,
      _multiple * 4,
      size,
    ]);
    expect(progress.last.total, size);
    expect(source.closed, 1);
  });

  test('傳完關掉 http.Client；中斷時不關，之後可以接著傳', () async {
    final size = _multiple * 2;
    final gcs = _FakeGcs(size, failAt: {2: 503});
    final client = _CountingClient(gcs.client);
    final uploader = ResumableUploader(
      _session(size),
      _FakeSource(size),
      chunkSize: _multiple,
      client: client,
      retryDelays: const [],
    );
    await expectLater(uploader.start().drain<void>(), throwsA(anything));
    expect(client.closed, 0);
    await uploader.start().drain<void>();
    expect(client.closed, 1);
  });

  test('一次只讀一段，讀取範圍連續且不超過每段大小（記憶體不隨檔案成長）', () async {
    final size = _multiple * 9;
    final source = _FakeSource(size);
    await ResumableUploader(
      _session(size),
      source,
      chunkSize: _multiple * 4,
      client: _FakeGcs(size).client,
    ).start().drain<void>();

    expect(source.reads, [
      (0, _multiple * 4),
      (_multiple * 4, _multiple * 8),
      (_multiple * 8, _multiple * 9),
    ]);
    for (final (start, end) in source.reads) {
      expect(end - start, lessThanOrEqualTo(_multiple * 4));
    }
  });

  test('308 的 Range 比送出的少：下一段從 Range 上界 + 1 接著傳', () async {
    final size = _multiple * 4;
    final gcs = _FakeGcs(size, partial: {0: _multiple});
    final progress = await ResumableUploader(
      _session(size),
      _FakeSource(size),
      chunkSize: _multiple * 2,
      client: gcs.client,
    ).start().toList();

    expect(gcs.requests.map((r) => r.headers['Content-Range']).skip(1), [
      'bytes 0-${_multiple * 2 - 1}/$size',
      'bytes $_multiple-${_multiple * 3 - 1}/$size',
      'bytes ${_multiple * 3}-${size - 1}/$size',
    ]);
    expect(progress.last.sent, size);
  });

  test('每段大小向下取到 chunk_size_multiple 的倍數', () {
    final uploader = ResumableUploader(
      _session(100),
      _FakeSource(100),
      chunkSize: _multiple * 3 + 5,
    );
    expect(uploader.chunkSize, _multiple * 3);
    expect(
      ResumableUploader(
        _session(100),
        _FakeSource(100),
        chunkSize: 10,
      ).chunkSize,
      _multiple,
    );
    expect(
      ResumableUploader(_session(100), _FakeSource(100)).chunkSize,
      8 * 1024 * 1024,
    );
  });

  group('queryOffset', () {
    Future<int> query(http.Response response) => ResumableUploader(
      _session(1000),
      _FakeSource(1000),
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.headers['Content-Range'], 'bytes */1000');
        expect(request.bodyBytes, isEmpty);
        return response;
      }),
    ).queryOffset();

    test('308 帶 Range → 上界 + 1', () async {
      expect(
        await query(
          http.Response('', 308, headers: {'range': 'bytes=0-524287'}),
        ),
        524288,
      );
    });

    test('308 沒有 Range → 0', () async {
      expect(await query(http.Response('', 308)), 0);
    });

    test('200／201 → 總大小（已傳完）', () async {
      expect(await query(http.Response('{}', 200)), 1000);
      expect(await query(http.Response('{}', 201)), 1000);
    });

    test('404／410 → UploadSessionExpired', () async {
      await expectLater(
        query(http.Response('', 404)),
        throwsA(isA<UploadSessionExpired>()),
      );
      await expectLater(
        query(http.Response('', 410)),
        throwsA(isA<UploadSessionExpired>()),
      );
    });

    test('5xx → UploadInterrupted 帶狀態碼', () async {
      await expectLater(
        query(http.Response('', 503)),
        throwsA(
          isA<UploadInterrupted>().having((e) => e.statusCode, 'status', 503),
        ),
      );
    });
  });

  test('不自動重試時，上傳中雲端回 503 → 串流丟 UploadInterrupted，重新 start 從已收到處接著傳', () async {
    final size = _multiple * 4;
    // 請求序號：0 查進度、1 第一段、2 第二段（失敗）
    final gcs = _FakeGcs(size, failAt: {2: 503});
    final source = _FakeSource(size);
    final uploader = ResumableUploader(
      _session(size),
      source,
      chunkSize: _multiple * 2,
      client: gcs.client,
      retryDelays: const [],
    );

    await expectLater(
      uploader.start(),
      emitsInOrder([
        const UploadProgress(sent: 0, total: _multiple * 4),
        const UploadProgress(sent: _multiple * 2, total: _multiple * 4),
        emitsError(isA<UploadInterrupted>()),
      ]),
    );

    final progress = await uploader.start().toList();
    expect(progress.first.sent, _multiple * 2);
    expect(progress.last.sent, size);
    expect(
      gcs.requests.skip(3).first.headers['Content-Range'],
      'bytes */$size',
    );
  });

  test('網路錯誤 → UploadInterrupted 帶原因', () async {
    final uploader = ResumableUploader(
      _session(100),
      _FakeSource(100),
      client: MockClient((_) async => throw http.ClientException('offline')),
      retryDelays: const [],
    );
    await expectLater(
      uploader.start(),
      emitsError(
        isA<UploadInterrupted>().having(
          (e) => e.cause,
          'cause',
          isA<http.ClientException>(),
        ),
      ),
    );
  });

  test('雲端一直沒回應 → 逾時丟 UploadInterrupted（原因是 TimeoutException）', () async {
    final uploader = ResumableUploader(
      _session(100),
      _FakeSource(100),
      requestTimeout: const Duration(milliseconds: 20),
      retryDelays: const [],
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      uploader.queryOffset(),
      throwsA(
        isA<UploadInterrupted>().having(
          (e) => e.cause,
          'cause',
          isA<TimeoutException>(),
        ),
      ),
    );
  });

  test('請求卡住時 cancel → 串流安靜結束，讀檔來源已關閉', () async {
    final source = _FakeSource(100);
    final uploader = ResumableUploader(
      _session(100),
      source,
      client: MockClient((_) => Completer<http.Response>().future),
    );
    final done = uploader.start().toList();
    await Future<void>.delayed(Duration.zero);
    uploader.cancel();
    expect(await done, isEmpty);
    expect(source.closed, 1);
  });

  group('自動重試', () {
    const fast = [Duration.zero, Duration.zero, Duration.zero];

    test('網路錯誤、5xx 時送 retrying 進度，查進度後從雲端已收到處接著傳完', () async {
      final size = _multiple * 4;
      // 請求序號：0 查進度、1 第一段、2 第二段（網路錯誤）、3 查進度（503）、4 查進度、5 第二段
      var index = 0;
      final gcs = _FakeGcs(size);
      final client = MockClient((request) async {
        final n = index++;
        if (n == 2) throw http.ClientException('offline');
        if (n == 3) return http.Response('', 503);
        return gcs.handle(request);
      });
      final progress = await ResumableUploader(
        _session(size),
        _FakeSource(size),
        chunkSize: _multiple * 2,
        client: client,
        retryDelays: fast,
      ).start().toList();

      expect(progress, [
        UploadProgress(sent: 0, total: size),
        UploadProgress(sent: _multiple * 2, total: size),
        UploadProgress(sent: _multiple * 2, total: size, retrying: true),
        UploadProgress(sent: _multiple * 2, total: size, retrying: true),
        UploadProgress(sent: _multiple * 2, total: size),
        UploadProgress(sent: size, total: size),
      ]);
      expect(gcs.received, size);
    });

    test('傳成功一段就重新計算重試次數；連續失敗用完才丟 UploadInterrupted', () async {
      final size = _multiple * 3;
      var index = 0;
      final gcs = _FakeGcs(size);
      // 每段之間都連續失敗兩次（上限 3 次），累計 6 次仍傳得完。
      final client = MockClient((request) async {
        final n = index++;
        if (n % 4 == 1 || n % 4 == 2) return http.Response('', 503);
        return gcs.handle(request);
      });
      final progress = await ResumableUploader(
        _session(size),
        _FakeSource(size),
        chunkSize: _multiple,
        client: client,
        retryDelays: fast,
      ).start().toList();
      expect(progress.last.sent, size);
      expect(progress.where((p) => p.retrying), hasLength(6));

      var requests = 0;
      await expectLater(
        ResumableUploader(
          _session(size),
          _FakeSource(size),
          client: MockClient((_) async {
            requests++;
            return http.Response('', 503);
          }),
          retryDelays: fast,
        ).start().where((p) => !p.retrying),
        emitsError(isA<UploadInterrupted>()),
      );
      expect(requests, 4, reason: '第一次＋重試 3 次');
    });

    test('404／410、其他 4xx、讀檔失敗不重試', () async {
      for (final (status, matcher) in [
        (404, isA<UploadSessionExpired>()),
        (400, isA<UploadInterrupted>()),
      ]) {
        var requests = 0;
        await expectLater(
          ResumableUploader(
            _session(100),
            _FakeSource(100),
            client: MockClient((_) async {
              requests++;
              return http.Response('', status);
            }),
            retryDelays: fast,
          ).start(),
          emitsError(matcher),
        );
        expect(requests, 1, reason: '$status 不重試');
      }

      var requests = 0;
      await expectLater(
        ResumableUploader(
          _session(_multiple),
          _BrokenSource(_multiple),
          client: MockClient((_) async {
            requests++;
            return http.Response('', 308);
          }),
          retryDelays: fast,
        ).start(),
        emitsInOrder([
          isA<UploadProgress>(),
          emitsError(isA<UploadInterrupted>()),
        ]),
      );
      expect(requests, 1, reason: '只查了一次進度');
    });

    test('等待重試時 cancel → 立刻安靜結束', () async {
      final uploader = ResumableUploader(
        _session(100),
        _FakeSource(100),
        client: MockClient((_) async => http.Response('', 503)),
        retryDelays: const [Duration(hours: 1)],
      );
      final events = <UploadProgress>[];
      final done = uploader.start().forEach(events.add);
      await pumpEventQueue();
      expect(events.single.retrying, isTrue);
      uploader.cancel();
      await done;
    });

    test('預設重試間隔：1、2、4、8、16 秒後每 30 秒，合計約 10 分鐘', () {
      final delays = ResumableUploader.defaultRetryDelays;
      expect(delays.take(6), const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
        Duration(seconds: 16),
        Duration(seconds: 30),
      ]);
      final total = delays.fold(Duration.zero, (a, b) => a + b);
      expect(total.inMinutes, 10);
    });
  });

  test('ChunkSource.io 依位移讀檔案的一段', () async {
    final dir = await Directory.systemTemp.createTemp('chunk_source_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/a.mp4')
      ..writeAsBytesSync(List.generate(1000, (i) => i % 256));
    final source = ChunkSource.io(file.path);

    expect(source.size, 1000);
    expect(await source.read(300, 305), [44, 45, 46, 47, 48]);
    expect(await source.read(0, 2), [0, 1]);
    await source.close();
    expect(await source.read(998, 1000), [230, 231]);
    await source.close();
  });
}
