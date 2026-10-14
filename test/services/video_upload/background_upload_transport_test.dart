import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/services/video_upload/background_upload_transport.dart';
import 'package:flutter_application_1/services/video_upload/upload_transport.dart';

final _url = Uri.parse('https://storage.googleapis.com/upload/session-1');
const _prefix = 'admin-video-7-';

class _FakeEngine implements BackgroundUploadEngine {
  bool supported = true;
  bool copies = false;
  int? free;
  bool accept = true;

  final _events = StreamController<BackgroundEvent>.broadcast(sync: true);
  final puts = <BackgroundPut>[];
  final cancelled = <String>[];

  /// 系統裡還在跑的 task（含上一次 App 程序留下的）。
  final active = <String>{};

  /// 取消時送出 canceled 事件。
  bool reportCancel = true;

  @override
  Future<bool> get available async => supported;

  @override
  bool get copiesPartialFile => copies;

  @override
  Future<int?> freeBytes() async => free;

  @override
  Stream<BackgroundEvent> get events => _events.stream;

  @override
  Future<bool> enqueue(BackgroundPut put) async {
    puts.add(put);
    if (accept) active.add(put.taskId);
    return accept;
  }

  @override
  Future<List<String>> activeTaskIds(String prefix) async => [
    for (final id in active)
      if (id.startsWith(prefix)) id,
  ];

  @override
  Future<void> cancel(String taskId) async {
    cancelled.add(taskId);
    if (active.remove(taskId) && reportCancel) {
      scheduleMicrotask(
        () =>
            emit(BackgroundEvent.status(taskId, BackgroundTaskStatus.canceled)),
      );
    }
  }

  void emit(BackgroundEvent event) {
    if (event.finished) active.remove(event.taskId);
    _events.add(event);
  }

  String get lastId => puts.last.taskId;
}

class _FakeHttp implements UploadTransport {
  int offset = 0;
  int queries = 0;
  final sends = <(int, int)>[];
  bool cancelled = false;

  @override
  bool get sendsWholeRemainder => false;

  @override
  Future<int> query() async {
    queries++;
    return offset;
  }

  @override
  Future<int?> send(
    int start,
    int end, {
    void Function(int sent)? onProgress,
    void Function()? onPreparing,
  }) async {
    sends.add((start, end));
    return offset = end;
  }

  @override
  void cancel() => cancelled = true;

  @override
  void close() {}
}

class _Harness {
  final engine = _FakeEngine();
  final httpTransport = _FakeHttp();
  final foreground = ValueNotifier(true);
  late final transport = BackgroundUploadTransport(
    engine: engine,
    sessionUrl: _url,
    total: 1000,
    filePath: '/cache/admin_video_uploads/a.mp4',
    taskPrefix: _prefix,
    displayName: '族語影片',
    contentType: 'video/mp4',
    foreground: foreground,
    http: httpTransport,
    fallbackChunkSize: 300,
    cancelWait: const Duration(milliseconds: 50),
    requeueRecheck: const Duration(milliseconds: 20),
  );
}

Future<void> _settle() => pumpEventQueue();

void main() {
  test('從頭送：一個 PUT 送到檔尾，不帶 Range、不送 Content-Disposition；2xx 回總大小', () async {
    final h = _Harness();
    final sent = <int>[];
    final result = h.transport.send(0, 1000, onProgress: sent.add);
    await _settle();

    final put = h.engine.puts.single;
    expect(put.taskId, startsWith(_prefix));
    expect(put.url, _url);
    expect(put.start, 0);
    expect(put.end, 1000);
    expect(put.headers, {
      'Content-Range': 'bytes 0-999/1000',
      'Content-Type': 'video/mp4',
      'Content-Disposition': '',
    });

    h.engine.emit(BackgroundEvent.progress(put.taskId, 400));
    h.engine.emit(
      BackgroundEvent.status(put.taskId, BackgroundTaskStatus.complete),
    );
    expect(await result, 1000);
    expect(sent, [400]);
  });

  test('從斷點送：帶 Range 指定檔案範圍', () async {
    final h = _Harness();
    final result = h.transport.send(256, 1000);
    await _settle();

    expect(h.engine.puts.single.headers['Content-Range'], 'bytes 256-999/1000');
    expect(h.engine.puts.single.headers['Range'], 'bytes=256-999');
    h.engine.emit(
      BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
    );
    expect(await result, 1000);
  });

  group('結果', () {
    Future<Object?> failWith(BackgroundEvent Function(String id) event) async {
      final h = _Harness();
      final result = h.transport.send(0, 1000);
      await _settle();
      h.engine.emit(event(h.engine.lastId));
      try {
        await result;
        return null;
      } catch (e) {
        return e;
      }
    }

    bool retryable(Object? e) =>
        e is UploadInterrupted && e.cause is http.ClientException;

    test('308（沒送完）、5xx、連線錯誤 → 可重試的中斷', () async {
      for (final status in [308, 503, null]) {
        final e = await failWith(
          (id) => BackgroundEvent.status(
            id,
            BackgroundTaskStatus.failed,
            httpStatus: status,
          ),
        );
        expect(retryable(e), isTrue, reason: '$status');
      }
    });

    test('404／410 → 工作階段失效；其他 4xx → 帶狀態碼的中斷', () async {
      expect(
        await failWith(
          (id) => BackgroundEvent.status(id, BackgroundTaskStatus.notFound),
        ),
        isA<UploadSessionExpired>(),
      );
      expect(
        await failWith(
          (id) => BackgroundEvent.status(
            id,
            BackgroundTaskStatus.failed,
            httpStatus: 410,
          ),
        ),
        isA<UploadSessionExpired>(),
      );
      final e = await failWith(
        (id) => BackgroundEvent.status(
          id,
          BackgroundTaskStatus.failed,
          httpStatus: 400,
        ),
      );
      expect(e, isA<UploadInterrupted>());
      expect((e as UploadInterrupted).statusCode, 400);
    });

    test('排不進系統 → 不可重試的中斷', () async {
      final h = _Harness()..engine.accept = false;
      final e = await h.transport
          .send(0, 1000)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<UploadInterrupted>());
      expect(
        (e as UploadInterrupted).cause,
        isNot(isA<http.ClientException>()),
      );
    });
  });

  group('只在前景排程', () {
    test('App 在背景時，查進度與排 task 都等回到前景才做', () async {
      final h = _Harness()..foreground.value = false;
      final query = h.transport.query();
      await _settle();
      expect(h.httpTransport.queries, 0);

      h.foreground.value = true;
      expect(await query, 0);
      expect(h.httpTransport.queries, 1);

      h.foreground.value = false;
      final send = h.transport.send(0, 1000);
      await _settle();
      expect(h.engine.puts, isEmpty);

      h.foreground.value = true;
      await _settle();
      expect(h.engine.puts, hasLength(1));
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
      );
      expect(await send, 1000);
    });

    test('背景中失敗：等回到前景才回報', () async {
      final h = _Harness();
      var done = false;
      final result = h.transport.send(0, 1000).whenComplete(() => done = true);
      await _settle();
      h.foreground.value = false;
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.failed),
      );
      await _settle();
      expect(done, isFalse);

      h.foreground.value = true;
      await expectLater(result, throwsA(isA<UploadInterrupted>()));
    });

    test('背景中傳完：直接回報完成', () async {
      final h = _Harness();
      final result = h.transport.send(0, 1000);
      await _settle();
      h.foreground.value = false;
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
      );
      expect(await result, 1000);
    });

    test('等前景時 cancel → 立刻結束，不排 task', () async {
      final h = _Harness()..foreground.value = false;
      final result = h.transport.send(0, 1000);
      await _settle();
      h.transport.cancel();
      await expectLater(result, throwsA(isA<UploadInterrupted>()));
      expect(h.engine.puts, isEmpty);
      expect(h.httpTransport.cancelled, isTrue);
    });
  });

  group('一支影片同時只有一個 task', () {
    test('查進度前先取消殘留的 task 並等它結束', () async {
      final h = _Harness();
      h.engine.active.addAll(['${_prefix}111', 'admin-video-8-222']);
      await h.transport.query();

      expect(h.engine.cancelled, ['${_prefix}111']);
      expect(h.engine.active, {'admin-video-8-222'});
    });

    test('收不到取消事件也只等 cancelWait', () async {
      final h = _Harness()..engine.reportCancel = false;
      h.engine.active.add('${_prefix}111');
      await h.transport.query();
      expect(h.engine.cancelled, ['${_prefix}111']);
    });

    test('cancel：取消進行中的 task', () async {
      final h = _Harness();
      final result = h.transport.send(0, 1000);
      await _settle();
      h.transport.cancel();
      await expectLater(result, throwsA(isA<UploadInterrupted>()));
      expect(h.engine.cancelled, [h.engine.puts.single.taskId]);
    });
  });

  group('iOS 從斷點續傳要複製剩下的部分', () {
    test('空間不夠（剩下的大小加 200MB）→ 丟 UploadStorageInsufficient，不排 task', () async {
      final h = _Harness()
        ..engine.copies = true
        ..engine.free = 744 + BackgroundUploadTransport.copyHeadroom - 1;
      await expectLater(
        h.transport.send(256, 1000),
        throwsA(
          isA<UploadStorageInsufficient>().having(
            (e) => e.requiredBytes,
            'requiredBytes',
            744 + BackgroundUploadTransport.copyHeadroom,
          ),
        ),
      );
      expect(h.engine.puts, isEmpty);
    });

    test('空間夠 → 先回報準備中再排 task；從頭送不必準備', () async {
      final h = _Harness()
        ..engine.copies = true
        ..engine.free = 1 << 40;
      var preparing = 0;
      final resumed = h.transport.send(
        256,
        1000,
        onPreparing: () => preparing++,
      );
      await _settle();
      expect(preparing, 1);
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
      );
      await resumed;

      final fresh = h.transport.send(0, 1000, onPreparing: () => preparing++);
      await _settle();
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
      );
      await fresh;
      expect(preparing, 1);
    });
  });

  group('排程失敗退回 WorkManager 後被重排', () {
    /// 回 send 的結果（錯誤也當值回，免得在前景時錯誤比測試先到、變成沒人接的錯誤）。
    Future<(_Harness, Future<Object?>)> requeued({
      required bool inForeground,
    }) async {
      final h = _Harness();
      final result = h.transport
          .send(0, 1000)
          .then<Object?>((v) => v, onError: (Object e) => e);
      await _settle();
      final id = h.engine.lastId;
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.enqueued));
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.running));
      h.foreground.value = inForeground;
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.enqueued));
      await _settle();
      return (h, result);
    }

    final retryableInterruption = isA<UploadInterrupted>().having(
      (e) => e.cause,
      'cause',
      isA<http.ClientException>(),
    );

    test('回到前景時停在 enqueued 且查進度沒有前進 → 取消，回報可重試的中斷', () async {
      final (h, result) = await requeued(inForeground: false);
      expect(h.engine.cancelled, isEmpty);

      h.foreground.value = true;
      expect(await result, retryableInterruption);
      expect(h.engine.cancelled, [h.engine.puts.single.taskId]);
    });

    test('在前景時被重排也一樣處理', () async {
      final (h, result) = await requeued(inForeground: true);
      expect(await result, retryableInterruption);
      expect(h.engine.cancelled, hasLength(1));
    });

    test('查進度有前進 → 先不取消；隔一段時間再查沒有再前進 → 取消', () async {
      final h = _Harness();
      h.httpTransport.offset = 500;
      final result = h.transport
          .send(0, 1000)
          .then<Object?>((v) => v, onError: (Object e) => e);
      await _settle();
      final id = h.engine.lastId;
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.running));
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.enqueued));
      await _settle();
      expect(h.engine.cancelled, isEmpty);

      expect(await result, retryableInterruption);
      expect(h.engine.cancelled, [id]);
      expect(h.httpTransport.queries, 2);
    });

    test('兩次檢查之間又前進 → 記下新進度繼續等；計時到時在背景就等回前景再查', () async {
      final h = _Harness();
      h.httpTransport.offset = 500;
      final result = h.transport
          .send(0, 1000)
          .then<Object?>((v) => v, onError: (Object e) => e);
      await _settle();
      final id = h.engine.lastId;
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.running));
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.enqueued));
      await _settle();
      expect(h.httpTransport.queries, 1);

      h.httpTransport.offset = 700;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(h.httpTransport.queries, 2);
      expect(h.engine.cancelled, isEmpty, reason: '500 → 700 有前進');

      h.foreground.value = false;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(h.httpTransport.queries, 2, reason: '在背景不查');

      h.foreground.value = true;
      expect(await result, retryableInterruption);
      expect(h.httpTransport.queries, 3);
      expect(h.engine.cancelled, [id]);
    });

    test('查進度有前進後又開始跑 → 不再檢查', () async {
      final h = _Harness();
      h.httpTransport.offset = 500;
      final result = h.transport.send(0, 1000);
      await _settle();
      final id = h.engine.lastId;
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.running));
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.enqueued));
      await _settle();
      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.running));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(h.engine.cancelled, isEmpty);
      expect(h.httpTransport.queries, 1);

      h.engine.emit(BackgroundEvent.status(id, BackgroundTaskStatus.complete));
      expect(await result, 1000);
    });

    test('第一次 enqueued（還沒跑過）不算重排', () async {
      final h = _Harness();
      final result = h.transport.send(0, 1000);
      await _settle();
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.enqueued),
      );
      await _settle();
      expect(h.httpTransport.queries, 0);
      expect(h.engine.cancelled, isEmpty);
      h.engine.emit(
        BackgroundEvent.status(h.engine.lastId, BackgroundTaskStatus.complete),
      );
      await result;
    });
  });

  test('不支援背景（Android 13 以下）→ 前景 http 一段一段送，不等前景、不排 task', () async {
    final h = _Harness()
      ..engine.supported = false
      ..foreground.value = false;
    expect(await h.transport.query(), 0);
    expect(await h.transport.send(0, 1000), 300);
    expect(await h.transport.send(900, 1000), 1000);
    expect(h.httpTransport.sends, [(0, 300), (900, 1000)]);
    expect(h.engine.puts, isEmpty);
  });
}
