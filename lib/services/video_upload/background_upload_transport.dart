// 手機的背景送法：交給系統背景傳輸（iOS 背景 URLSession、Android 14 以上 UIDT），
// App 切到別的 App 或鎖螢幕時繼續傳（後台影片 T-06）。
//
// 每次用一個 PUT 把剩下的部分送到檔尾（[sendsWholeRemainder]），所以成功只會是 200／201；
// 其他結果（含 308、網路錯誤）一律當失敗，由上傳器查進度後重排剩下的部分。
//
// 只在前景排程：查進度與排 task 都等 App 回到前景才做；背景中失敗的 task 也等回到前景才回報，
// 上傳器因此只會在前景重試（背景期間不重送，2026-10-14 決定 D）。請求逾時交給系統。
//
// 一支影片同時只有一個 task：task id 是 `{prefix}{時間}`；查進度、排新 task 前，
// 先取消同一支影片所有殘留的 task（例如 App 被滑掉前排的），等它們真的結束才繼續。
//
// 排程失敗退回 WorkManager（Android UIDT 排不進去）時，套件會在 2 分鐘後把 task 改回 enqueued 重排。
// App 在前景時發現 task 停在 enqueued 且查進度沒有前進（沒超過 task 起點，或和
// [BackgroundUploadTransport.requeueRecheck] 前查的一樣），就取消它，交給上傳器重排。
//
// 系統不支援背景上傳（Android 13 以下、[BackgroundUploadEngine.available] 為 false）時，
// 改用前景 http 一段一段送，與網頁版相同（2026-10-14 決定 E）。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'upload_transport.dart';

/// 交給系統背景傳輸的一個 PUT：上傳檔案 [filePath] 的 `[start, end)`。
class BackgroundPut {
  final String taskId;
  final Uri url;
  final String filePath;
  final int start;
  final int end;
  final Map<String, String> headers;

  /// 通知列上顯示的名稱（影片標題）。
  final String displayName;

  const BackgroundPut({
    required this.taskId,
    required this.url,
    required this.filePath,
    required this.start,
    required this.end,
    required this.headers,
    required this.displayName,
  });
}

enum BackgroundTaskStatus {
  enqueued,
  running,

  /// 雲端回 2xx。
  complete,

  /// 失敗；[BackgroundEvent.httpStatus] 有值代表雲端回了這個狀態碼（包含 308），否則是連線或其他錯誤。
  failed,

  /// 雲端回 404。
  notFound,

  /// 被取消（App 自己或使用者從通知列）。
  canceled;

  bool get finished =>
      this != BackgroundTaskStatus.enqueued &&
      this != BackgroundTaskStatus.running;
}

/// 背景 task 的進度或狀態變化。
class BackgroundEvent {
  final String taskId;

  /// 進度：這個 task 已送出多少位元組（從 [BackgroundPut.start] 起算）。
  final int? sent;

  /// 狀態變化；進度事件是 null。
  final BackgroundTaskStatus? status;
  final int? httpStatus;
  final String? description;

  const BackgroundEvent.progress(this.taskId, int this.sent)
    : status = null,
      httpStatus = null,
      description = null;

  const BackgroundEvent.status(
    this.taskId,
    BackgroundTaskStatus this.status, {
    this.httpStatus,
    this.description,
  }) : sent = null;

  bool get finished => status?.finished ?? false;
}

/// 系統背景傳輸（background_downloader）的薄包裝；測試換成假的。
abstract class BackgroundUploadEngine {
  /// 這台裝置排得進背景上傳（iOS、Android 14 以上）。
  Future<bool> get available;

  /// 從斷點續傳時，系統要先把剩下的部分複製成暫存檔（iOS）。
  bool get copiesPartialFile;

  /// 手機剩餘可用空間（bytes）；查不到回 null（不擋）。
  Future<int?> freeBytes();

  /// 所有背景上傳 task 的進度與狀態。
  Stream<BackgroundEvent> get events;

  /// 排進系統背景傳輸。回 false：排不進去（檔案不見、iOS 建立暫存檔失敗等）。
  Future<bool> enqueue(BackgroundPut put);

  /// 系統裡還沒結束、id 以 [prefix] 開頭的 task。
  Future<List<String>> activeTaskIds(String prefix);

  Future<void> cancel(String taskId);
}

/// 取消 id 以 [prefix] 開頭的所有 task，並等它們真的結束（收到結束事件）；
/// 每個最多等 [timeout]（task 早已結束時收不到事件）。
Future<void> cancelBackgroundTasks(
  BackgroundUploadEngine engine,
  String prefix, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  for (final id in await engine.activeTaskIds(prefix)) {
    debugPrint('BackgroundUploadTransport: 取消殘留的背景上傳 $id');
    await _cancelAndWait(engine, id, timeout);
  }
}

Future<void> _cancelAndWait(
  BackgroundUploadEngine engine,
  String taskId,
  Duration timeout,
) async {
  final finished = engine.events
      .firstWhere((e) => e.taskId == taskId && e.finished)
      .timeout(timeout, onTimeout: () => BackgroundEvent.progress(taskId, 0));
  await engine.cancel(taskId);
  await finished;
}

class BackgroundUploadTransport implements UploadTransport {
  /// iOS 複製剩下的部分時，除了檔案本身再多留的空間。
  static const copyHeadroom = 200 * 1024 * 1024;

  final BackgroundUploadEngine engine;
  final Uri sessionUrl;
  final int total;
  final String filePath;

  /// 這支影片的 task id 前綴（同一支影片的 task 都用它開頭）。
  final String taskPrefix;
  final String displayName;

  /// 送檔時的 Content-Type（與建立影片時的一致）。
  final String? contentType;

  /// App 是否在前景。
  final ValueListenable<bool> foreground;

  /// 不支援背景時每段多大（chunk_size_multiple 的倍數）。
  final int fallbackChunkSize;

  /// 取消 task 後最多等多久它真的結束。
  final Duration cancelWait;

  /// task 停在 enqueued 但查進度有前進時，隔多久再查一次。
  final Duration requeueRecheck;

  /// 前景送法：查進度、不支援背景時一段一段送。
  final UploadTransport _http;
  final DateTime Function() _now;

  bool _cancelled = false;
  _Task? _task;

  /// 等 App 回到前景中：[cancel] 時提早叫醒。
  Completer<void>? _wake;

  BackgroundUploadTransport({
    required this.engine,
    required this.sessionUrl,
    required this.total,
    required this.filePath,
    required this.taskPrefix,
    required this.displayName,
    required this.foreground,
    required UploadTransport http,
    required this.fallbackChunkSize,
    this.contentType,
    this.cancelWait = const Duration(seconds: 10),
    this.requeueRecheck = const Duration(minutes: 1),
    @visibleForTesting DateTime Function()? clock,
  }) : _http = http,
       _now = clock ?? DateTime.now;

  /// 背景時一次送到檔尾；不支援背景時由 [send] 自己切段（回雲端確認的位置，上傳器照樣接著送）。
  @override
  bool get sendsWholeRemainder => true;

  @override
  Future<int> query() async {
    if (await engine.available) await _readyToSchedule();
    return _http.query();
  }

  @override
  Future<int?> send(
    int start,
    int end, {
    void Function(int sent)? onProgress,
    void Function()? onPreparing,
  }) async {
    if (!await engine.available) {
      return _http.send(
        start,
        start + fallbackChunkSize < end ? start + fallbackChunkSize : end,
      );
    }
    await _readyToSchedule();
    if (start > 0 && engine.copiesPartialFile) {
      final needed = end - start + copyHeadroom;
      final free = await engine.freeBytes();
      if (free != null && free < needed) {
        throw UploadStorageInsufficient(needed);
      }
      onPreparing?.call();
    }
    _throwIfCancelled();
    final task = _task = _Task(
      '$taskPrefix${_now().microsecondsSinceEpoch}',
      start,
    );
    final subscription = engine.events
        .where((e) => e.taskId == task.id)
        .listen((event) => _onEvent(task, event, end, onProgress));
    void onForeground() {
      if (foreground.value) _onForeground(task);
    }

    foreground.addListener(onForeground);
    try {
      final queued = await engine.enqueue(
        BackgroundPut(
          taskId: task.id,
          url: sessionUrl,
          filePath: filePath,
          start: start,
          end: end,
          displayName: displayName,
          headers: {
            'Content-Range': 'bytes $start-${end - 1}/$total',
            'Content-Type': ?contentType,
            // 套件不把 Range 送出去，只用來決定上傳檔案的哪一段；從頭送時不帶，直接傳原檔。
            if (start > 0) 'Range': 'bytes=$start-${end - 1}',
            // 套件預設會加 Content-Disposition，雲端用不到，空字串代表不送。
            'Content-Disposition': '',
          },
        ),
      );
      if (!queued) {
        task.fail(const UploadInterrupted(cause: '排不進系統背景上傳'));
      } else if (_cancelled) {
        unawaited(engine.cancel(task.id));
        task.fail(const UploadInterrupted(cause: 'cancelled'));
      }
      return await task.result.future;
    } finally {
      foreground.removeListener(onForeground);
      task.recheck?.cancel();
      // 不等：取消廣播串流的訂閱沒有要收尾的事。
      unawaited(subscription.cancel());
      if (identical(_task, task)) _task = null;
    }
  }

  void _onEvent(
    _Task task,
    BackgroundEvent event,
    int end,
    void Function(int sent)? onProgress,
  ) {
    final sent = event.sent;
    if (sent != null) {
      if (!task.result.isCompleted) onProgress?.call(sent);
      return;
    }
    switch (event.status!) {
      case BackgroundTaskStatus.running:
        task.ran = true;
        task.requeued = false;
        task.requeuedOffset = null;
        task.recheck?.cancel();
      case BackgroundTaskStatus.enqueued:
        // 跑過又回到 enqueued：排程失敗退回 WorkManager 後被套件重排。
        if (task.ran) {
          task.requeued = true;
          if (foreground.value) _checkRequeued(task);
        }
      case BackgroundTaskStatus.complete:
        // 一定送到檔尾，2xx 就是傳完了。
        task.complete(end);
      case BackgroundTaskStatus.notFound:
        _failInForeground(task, const UploadSessionExpired());
      case BackgroundTaskStatus.canceled:
        _failInForeground(
          task,
          task.cancelledToRequeue
              ? UploadInterrupted(
                  cause: http.ClientException('背景上傳被系統退回排程，重新排入'),
                )
              : const UploadInterrupted(cause: 'cancelled'),
        );
      case BackgroundTaskStatus.failed:
        _failInForeground(task, _failure(event));
    }
  }

  /// 失敗的結果：404／410 是工作階段失效；其他 4xx（408、429 除外）照狀態碼回報；
  /// 308（沒送完）、5xx、連線錯誤、系統中止都是換個時間再試可能會好的錯誤。
  static Object _failure(BackgroundEvent event) {
    final status = event.httpStatus;
    if (status == 404 || status == 410) return const UploadSessionExpired();
    if (status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429) {
      return UploadInterrupted(statusCode: status);
    }
    return UploadInterrupted(
      cause: http.ClientException(
        event.description ?? '背景上傳失敗${status != null ? '（$status）' : ''}',
      ),
    );
  }

  /// 背景中結束的失敗等回到前景才回報：上傳器收到後會馬上查進度並重排，那必須在前景做。
  void _failInForeground(_Task task, Object error) {
    if (foreground.value || _cancelled) {
      task.fail(error);
    } else {
      task.heldError = error;
    }
  }

  void _onForeground(_Task task) {
    final held = task.heldError;
    if (held != null) {
      task.fail(held);
      return;
    }
    if (task.requeued) _checkRequeued(task);
  }

  /// task 停在 enqueued：查進度沒有前進就取消，交給上傳器重排；有前進就記下來，
  /// [requeueRecheck] 後（App 仍在前景時）再查一次。
  Future<void> _checkRequeued(_Task task) async {
    if (task.checking || task.result.isCompleted) return;
    task.checking = true;
    task.recheck?.cancel();
    try {
      final offset = await _http.query();
      if (!task.requeued || task.result.isCompleted || _cancelled) return;
      if (offset > (task.requeuedOffset ?? task.start)) {
        task.requeuedOffset = offset;
        task.recheck = Timer(requeueRecheck, () {
          if (foreground.value && task.requeued) _checkRequeued(task);
        });
        return;
      }
      debugPrint('BackgroundUploadTransport: ${task.id} 停在重排沒有前進，取消後重排');
      task.cancelledToRequeue = true;
      await _cancelAndWait(engine, task.id, cancelWait);
      // 等不到結束事件也不能卡住：當作已取消。
      task.fail(
        UploadInterrupted(cause: http.ClientException('背景上傳被系統退回排程，重新排入')),
      );
    } catch (e) {
      // 查不到進度就先不動，下次回到前景或狀態變化時再看。
      debugPrint('BackgroundUploadTransport: 檢查重排的 task 失敗（忽略）：$e');
    } finally {
      task.checking = false;
    }
  }

  /// 排程（或為排程查進度）前：等 App 回到前景，再清掉同一支影片殘留的 task。
  Future<void> _readyToSchedule() async {
    while (!foreground.value) {
      _throwIfCancelled();
      final wake = _wake = Completer<void>();
      void listener() {
        if (foreground.value && !wake.isCompleted) wake.complete();
      }

      foreground.addListener(listener);
      try {
        await wake.future;
      } finally {
        foreground.removeListener(listener);
        _wake = null;
      }
    }
    _throwIfCancelled();
    await cancelBackgroundTasks(engine, taskPrefix, timeout: cancelWait);
    _throwIfCancelled();
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const UploadInterrupted(cause: 'cancelled');
  }

  @override
  void cancel() {
    _cancelled = true;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    final task = _task;
    if (task != null) {
      unawaited(engine.cancel(task.id));
      task.fail(const UploadInterrupted(cause: 'cancelled'));
    }
    _http.cancel();
  }

  @override
  void close() => _http.close();
}

/// 進行中的一個背景 task。
class _Task {
  final String id;
  final int start;
  final result = Completer<int?>();

  /// 跑過（收到過 running）。
  bool ran = false;

  /// 跑過又回到 enqueued，還沒再跑。
  bool requeued = false;

  /// 正在檢查重排的 task 有沒有前進。
  bool checking = false;

  /// 停在 enqueued 後上次查到的雲端進度；還沒查過是 null（以 [start] 比）。
  int? requeuedOffset;

  /// 停在 enqueued 但有前進時，下一次檢查。
  Timer? recheck;

  /// 因為停在重排而由這裡取消（取消事件當作可重試的中斷）。
  bool cancelledToRequeue = false;

  /// 背景中失敗、等回到前景才回報的錯誤。
  Object? heldError;

  _Task(this.id, this.start);

  void complete(int next) {
    if (!result.isCompleted) result.complete(next);
  }

  void fail(Object error) {
    if (!result.isCompleted) result.completeError(error);
  }
}
