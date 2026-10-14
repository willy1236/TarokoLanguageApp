// 雲端可續傳上傳（GCS resumable）的分段上傳器。
// 協定：https://cloud.google.com/storage/docs/performing-resumable-uploads
//
// - 每段 `PUT session_url`，帶 `Content-Range: bytes {起}-{迄}/{總大小}`；中間段回 308，
//   下一段從 308 的 `Range` 上界 + 1 開始（不能假設這段全收到），沒有 `Range` 代表還沒收到任何位元組。
//   最後一段回 200／201。
// - 每段（最後一段除外）須為 `chunk_size_multiple`（256KiB）的倍數。
// - 查進度：空內容＋`Content-Range: bytes */{總大小}`。
// - 一次只讀一段、傳一段，記憶體不隨檔案大小成長。
//
// 用獨立的 http.Client，不經 ApiClient：目標是雲端網址，不能帶 App 的 token。
// 網路錯誤、逾時、雲端 5xx／408／429 時自動退避重試（[ResumableUploader.retryDelays]，
// 預設 1、2、4、8、16 秒後每 30 秒一次），每次重試都先查進度再接著傳；有一段傳成功、
// 或查進度發現雲端收到的比上次多（慢網路逾時前已傳一部分），就重新計算。
// 從第一次失敗起超過 [ResumableUploader.retryWindow]（預設 10 分鐘）就不再等下一次，
// 丟 [UploadInterrupted]（等待期間加上最後一次嘗試的逾時，最久約 12 分鐘）。
// 每個請求有逾時：送一段 [ResumableUploader.requestTimeout]、查進度 [ResumableUploader.queryTimeout]。
// 手機切網路時連線可能不報錯也不回應，逾時就中止請求、丟 [UploadInterrupted]，不會一直卡在上傳中。
// 不要改 followRedirects：網頁版 fetch 設成 false 會把 308 當網路錯誤；
// 維持預設時 308 沒有 Location 會照原樣回來。dart:io 對 PUT 本來就不跟隨轉址。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/video_upload.dart';
import 'chunk_source.dart';

/// 已傳／總大小（bytes）。
class UploadProgress {
  final int sent;
  final int total;

  /// 網路中斷，正在等待自動重試（[sent] 是中斷前雲端確認收到的位置）。
  final bool retrying;

  const UploadProgress({
    required this.sent,
    required this.total,
    this.retrying = false,
  });

  int get remaining => total - sent;

  /// 0～1。
  double get fraction => total <= 0 ? 0 : sent / total;

  @override
  bool operator ==(Object other) =>
      other is UploadProgress &&
      other.sent == sent &&
      other.total == total &&
      other.retrying == retrying;

  @override
  int get hashCode => Object.hash(sent, total, retrying);

  @override
  String toString() =>
      'UploadProgress($sent/$total${retrying ? ', retrying' : ''})';
}

/// 上傳中斷（網路錯誤、雲端回非預期狀態碼）。同一個工作階段可以 [ResumableUploader.queryOffset] 後接著傳。
class UploadInterrupted implements Exception {
  final Object? cause;
  final int? statusCode;

  const UploadInterrupted({this.cause, this.statusCode});

  @override
  String toString() => 'UploadInterrupted(status: $statusCode, cause: $cause)';
}

/// 工作階段已失效（雲端回 404／410，超過一週或已被取消），只能重新建立。
class UploadSessionExpired implements Exception {
  const UploadSessionExpired();

  @override
  String toString() => 'UploadSessionExpired';
}

class ResumableUploader {
  /// 預設每段 8MiB。
  static const defaultChunkSize = 8 * 1024 * 1024;

  /// 預設每個請求最多等 2 分鐘（8MiB 在約 0.5Mbps 的慢速網路也傳得完）。
  static const defaultRequestTimeout = Duration(minutes: 2);

  /// 預設查進度（空內容）最多等 30 秒。
  static const defaultQueryTimeout = Duration(seconds: 30);

  /// 預設連續失敗多久後放棄自動重試。
  static const defaultRetryWindow = Duration(minutes: 10);

  /// 預設的自動重試間隔：1、2、4、8、16 秒，之後每 30 秒（次數足夠撐滿 [defaultRetryWindow]，
  /// 實際何時放棄由時間決定）。
  static final List<Duration> defaultRetryDelays = List.unmodifiable([
    for (final seconds in [1, 2, 4, 8, 16]) Duration(seconds: seconds),
    for (var i = 0; i < 40; i++) const Duration(seconds: 30),
  ]);

  final UploadSession session;
  final ChunkSource source;

  /// 實際每段大小：[defaultChunkSize] 或指定值，向下取到 chunk_size_multiple 的倍數。
  final int chunkSize;

  /// 一個請求（送出一段到收到回應）最多等多久，超過就中止、丟 [UploadInterrupted]。
  final Duration requestTimeout;

  /// 查進度（空內容）最多等多久。
  final Duration queryTimeout;

  /// 連續失敗時第 n 次重試前等多久；用完就丟 [UploadInterrupted]。空清單＝不自動重試。
  final List<Duration> retryDelays;

  /// 從這一輪第一次失敗起算，超過多久就不再自動重試。
  final Duration retryWindow;

  final DateTime Function() _now;

  final http.Client _client;
  bool _cancelled = false;

  /// 雲端最近一次確認收到的位置。
  int _confirmed = 0;

  /// 進行中的請求：[cancel] 時立刻中止並讓它以錯誤結束。
  void Function()? _stopRequest;

  /// 重試等待中：[cancel] 時提早叫醒。
  Completer<void>? _wake;

  ResumableUploader(
    this.session,
    this.source, {
    int chunkSize = defaultChunkSize,
    this.requestTimeout = defaultRequestTimeout,
    this.queryTimeout = defaultQueryTimeout,
    List<Duration>? retryDelays,
    this.retryWindow = defaultRetryWindow,
    http.Client? client,
    @visibleForTesting DateTime Function()? clock,
  }) : chunkSize = _alignChunk(chunkSize, session.chunkMultiple),
       retryDelays = retryDelays ?? defaultRetryDelays,
       _client = client ?? http.Client(),
       _now = clock ?? DateTime.now;

  static int _alignChunk(int size, int multiple) {
    if (multiple <= 0) return size;
    final aligned = size - size % multiple;
    return aligned < multiple ? multiple : aligned;
  }

  int get _total => session.size;

  /// 從雲端已收到的位置接著傳到完成。先查進度再傳，所以中斷後重新呼叫即是續傳。
  /// 每傳完一段送一次進度；網路中斷時送 `retrying: true` 的進度並自動重試。
  /// 完成時關閉串流並關掉 http.Client（之後不能再用）。重試用完丟 [UploadInterrupted]，
  /// 工作階段失效丟 [UploadSessionExpired]；[cancel] 後安靜關閉。
  Stream<UploadProgress> start() async* {
    // 從上次確認過的位置算起：重新 start 時查進度失敗，進度也不會掉回 0。
    var offset = _confirmed;
    var failures = 0;
    DateTime? failingSince;
    try {
      while (true) {
        try {
          final confirmed = await queryOffset();
          if (_cancelled) return;
          // 慢網路時一段可能傳到一半就逾時，但雲端有收到部分資料：有前進就重新計算重試。
          if (confirmed > offset) {
            failures = 0;
            failingSince = null;
          }
          offset = _confirmed = confirmed;
          yield UploadProgress(sent: offset, total: _total);
          while (offset < _total) {
            final end = offset + chunkSize < _total
                ? offset + chunkSize
                : _total;
            final bytes = await source.read(offset, end);
            if (_cancelled) return;
            final response = await _put(
              'bytes $offset-${end - 1}/$_total',
              bytes,
            );
            if (_cancelled) return;
            offset = _confirmed = _offsetFrom(response);
            failures = 0;
            failingSince = null;
            yield UploadProgress(sent: offset, total: _total);
          }
          // 傳完了，這個上傳器不會再送請求，釋放連線。
          _client.close();
          return;
        } catch (e) {
          if (_cancelled) return;
          if (e is UploadSessionExpired) rethrow;
          final interrupted = e is UploadInterrupted
              ? e
              : UploadInterrupted(cause: e);
          final now = _now();
          final since = failingSince ??= now;
          if (!_retryable(interrupted) ||
              failures >= retryDelays.length ||
              now.difference(since) + retryDelays[failures] > retryWindow) {
            throw interrupted;
          }
          yield UploadProgress(sent: offset, total: _total, retrying: true);
          await _sleep(retryDelays[failures++]);
          if (_cancelled) return;
        }
      }
    } finally {
      await source.close();
    }
  }

  /// 換個時間再試可能會好的錯誤：網路錯誤、逾時、雲端 5xx／408／429。
  /// 讀檔失敗（檔案被刪）、其他 4xx、看不懂的回應不重試。
  static bool _retryable(UploadInterrupted e) {
    final status = e.statusCode;
    if (status != null) return status >= 500 || status == 408 || status == 429;
    final cause = e.cause;
    return cause is http.ClientException || cause is TimeoutException;
  }

  Future<void> _sleep(Duration delay) {
    final wake = _wake = Completer<void>();
    final timer = Timer(delay, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future.whenComplete(() {
      timer.cancel();
      _wake = null;
    });
  }

  /// 問雲端已收到多少：回下一個要傳的位元組位置；已完成回總大小。
  Future<int> queryOffset() async {
    final http.Response response;
    try {
      response = await _put('bytes */$_total', const [], timeout: queryTimeout);
    } on UploadSessionExpired {
      rethrow;
    } on UploadInterrupted {
      rethrow;
    } catch (e) {
      throw UploadInterrupted(cause: e);
    }
    return _offsetFrom(response);
  }

  /// 停止上傳並中止進行中的請求。工作階段本身不動（一週後自然失效）。
  void cancel() {
    _cancelled = true;
    _stopRequest?.call();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    _client.close();
  }

  Future<http.Response> _put(
    String contentRange,
    List<int> body, {
    Duration? timeout,
  }) async {
    final limit = timeout ?? requestTimeout;
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'PUT',
            session.sessionUrl,
            abortTrigger: abort.future,
          )
          ..headers['Content-Range'] = contentRange
          ..bodyBytes = body;
    final result = Completer<http.Response>();
    void stop(Object error) {
      if (!result.isCompleted) result.completeError(error);
      if (!abort.isCompleted) abort.complete();
    }

    final timer = Timer(
      limit,
      () => stop(UploadInterrupted(cause: TimeoutException('雲端沒有回應', limit))),
    );
    _stopRequest = () {
      timer.cancel();
      stop(const UploadInterrupted(cause: 'cancelled'));
    };
    _client
        .send(request)
        .then(http.Response.fromStream)
        .then(
          (response) {
            if (!result.isCompleted) result.complete(response);
          },
          onError: (Object e, StackTrace st) {
            if (!result.isCompleted) result.completeError(e, st);
          },
        );
    final http.Response response;
    try {
      response = await result.future;
    } finally {
      timer.cancel();
      _stopRequest = null;
    }
    final status = response.statusCode;
    if (status == 404 || status == 410) throw const UploadSessionExpired();
    if (status != 308 && status != 200 && status != 201) {
      throw UploadInterrupted(statusCode: status);
    }
    return response;
  }

  /// 308 依 `Range` 回下一個位元組（沒有 `Range` 是 0）；200／201 代表完成。
  int _offsetFrom(http.Response response) {
    if (response.statusCode != 308) return _total;
    final range = response.headers['range'];
    if (range == null) return 0;
    final match = RegExp(r'bytes=\d+-(\d+)').firstMatch(range);
    if (match == null) throw UploadInterrupted(statusCode: 308, cause: range);
    return int.parse(match.group(1)!) + 1;
  }
}
