// 分段上傳器：分段大小、Content-Range、308／200 處理、查進度解析 Range、錯誤分類、讀檔不超過一段。

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

  MockClient get client => MockClient((request) async {
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
  });

  http.Response _status() {
    if (received >= size) return http.Response('{}', 200);
    return http.Response(
      '',
      308,
      headers: received == 0 ? {} : {'range': 'bytes=0-${received - 1}'},
    );
  }
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

  test('上傳中雲端回 503 → 串流丟 UploadInterrupted，重新 start 從已收到處接著傳', () async {
    final size = _multiple * 4;
    // 請求序號：0 查進度、1 第一段、2 第二段（失敗）
    final gcs = _FakeGcs(size, failAt: {2: 503});
    final source = _FakeSource(size);
    final uploader = ResumableUploader(
      _session(size),
      source,
      chunkSize: _multiple * 2,
      client: gcs.client,
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
