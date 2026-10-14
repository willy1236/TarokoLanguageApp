// 雲端可續傳上傳（GCS resumable）的分段上傳器：查進度 → 從斷點一段一段送 → 失敗退避重試。
// 實際怎麼送交給 [UploadTransport]（前景 http.Client 分段，或手機背景一次送完剩下全部），
// 協定細節見 upload_transport.dart。
//
// - 每段（最後一段除外）須為 `chunk_size_multiple`（256KiB）的倍數。
// - 一次只讀一段、傳一段，記憶體不隨檔案大小成長。
//
// 網路錯誤、逾時、雲端 5xx／408／429 時自動退避重試（[ResumableUploader.retryDelays]，
// 預設 1、2、4、8、16 秒後每 30 秒一次），每次重試都先查進度再接著傳；有一段傳成功、
// 或查進度發現雲端收到的比上次多（慢網路逾時前已傳一部分），就重新計算。
// 從第一次失敗起超過 [ResumableUploader.retryWindow]（預設 10 分鐘）就不再等下一次，
// 丟 [UploadInterrupted]（等待期間加上最後一次嘗試的逾時，最久約 12 分鐘）。
// 預設的前景送法每個請求有逾時：送一段 [ResumableUploader.requestTimeout]、查進度 [ResumableUploader.queryTimeout]。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/video_upload.dart';
import 'chunk_source.dart';
import 'upload_transport.dart';

export 'upload_transport.dart'
    show UploadInterrupted, UploadSessionExpired, UploadStorageInsufficient;

/// 已傳／總大小（bytes）。
class UploadProgress {
  final int sent;
  final int total;

  /// 網路中斷，正在等待自動重試（[sent] 是中斷前雲端確認收到的位置）。
  final bool retrying;

  /// 開始送之前正在準備（iOS 背景從斷點續傳時複製剩下的部分）。
  final bool preparing;

  const UploadProgress({
    required this.sent,
    required this.total,
    this.retrying = false,
    this.preparing = false,
  });

  int get remaining => total - sent;

  /// 0～1。
  double get fraction => total <= 0 ? 0 : sent / total;

  @override
  bool operator ==(Object other) =>
      other is UploadProgress &&
      other.sent == sent &&
      other.total == total &&
      other.retrying == retrying &&
      other.preparing == preparing;

  @override
  int get hashCode => Object.hash(sent, total, retrying, preparing);

  @override
  String toString() =>
      'UploadProgress($sent/$total${retrying ? ', retrying' : ''}'
      '${preparing ? ', preparing' : ''})';
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

  /// 預設送法（[HttpUploadTransport]）一個請求（送出一段到收到回應）最多等多久，超過就中止、丟 [UploadInterrupted]。
  /// 指定 `transport` 時不使用。
  final Duration requestTimeout;

  /// 預設送法查進度（空內容）最多等多久。指定 `transport` 時不使用。
  final Duration queryTimeout;

  /// 連續失敗時第 n 次重試前等多久；用完就丟 [UploadInterrupted]。空清單＝不自動重試。
  final List<Duration> retryDelays;

  /// 從這一輪第一次失敗起算，超過多久就不再自動重試。
  final Duration retryWindow;

  final DateTime Function() _now;

  final UploadTransport _transport;
  bool _cancelled = false;

  /// 雲端最近一次確認收到的位置。
  int _confirmed = 0;

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
    UploadTransport? transport,
    @visibleForTesting DateTime Function()? clock,
  }) : chunkSize = alignChunk(chunkSize, session.chunkMultiple),
       retryDelays = retryDelays ?? defaultRetryDelays,
       _transport =
           transport ??
           HttpUploadTransport(
             session,
             source,
             requestTimeout: requestTimeout,
             queryTimeout: queryTimeout,
             client: client,
           ),
       _now = clock ?? DateTime.now;

  /// [size] 向下取到 [multiple] 的倍數（至少一倍）。
  static int alignChunk(int size, int multiple) {
    if (multiple <= 0) return size;
    final aligned = size - size % multiple;
    return aligned < multiple ? multiple : aligned;
  }

  int get _total => session.size;

  /// 從雲端已收到的位置接著傳到完成。先查進度再傳，所以中斷後重新呼叫即是續傳。
  /// 每傳完一段送一次進度；網路中斷時送 `retrying: true` 的進度並自動重試。
  /// 完成時關閉串流並釋放送法的資源（之後不能再用）。重試用完丟 [UploadInterrupted]，
  /// 工作階段失效丟 [UploadSessionExpired]，手機空間不足丟 [UploadStorageInsufficient]；[cancel] 後安靜關閉。
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
            final from = offset;
            final end =
                _transport.sendsWholeRemainder || from + chunkSize >= _total
                ? _total
                : from + chunkSize;
            // 送的同時轉發段內進度（背景送法一次送完剩下全部，要靠它更新進度條）；null 代表準備中。
            final inRequest = StreamController<int?>();
            final sending = _transport
                .send(
                  from,
                  end,
                  onProgress: (sent) {
                    if (!inRequest.isClosed) inRequest.add(sent);
                  },
                  onPreparing: () {
                    if (!inRequest.isClosed) inRequest.add(null);
                  },
                )
                .then<_SendResult>(
                  _SendResult.new,
                  onError: (Object e, StackTrace st) =>
                      _SendResult.failed(e, st),
                )
                .whenComplete(inRequest.close);
            // 段內進度只用來顯示；[offset] 仍是雲端確認過的位置（重試、查進度都以它為準）。
            var shown = from;
            var preparing = false;
            await for (final sent in inRequest.stream) {
              if (_cancelled) return;
              if (sent == null) {
                preparing = true;
                yield UploadProgress(
                  sent: from,
                  total: _total,
                  preparing: true,
                );
                continue;
              }
              final at = from + sent.clamp(0, end - from);
              // 準備完的第一次進度即使還是 0 也送出，畫面才離開「準備中」。
              if (at > shown || preparing) {
                preparing = false;
                shown = at;
                yield UploadProgress(sent: at, total: _total);
              }
            }
            final result = await sending;
            if (_cancelled) return;
            result.rethrowIfFailed();
            var next = result.next;
            if (next == null) {
              // 雲端沒說收到多少：查進度。沒有前進就當作中斷，退避後重試。
              next = await queryOffset();
              if (_cancelled) return;
              if (next <= from) {
                throw UploadInterrupted(
                  cause: http.ClientException('送出後雲端沒有收到新的資料'),
                );
              }
            }
            offset = _confirmed = next;
            failures = 0;
            failingSince = null;
            yield UploadProgress(sent: offset, total: _total);
          }
          // 傳完了，這個上傳器不會再送請求，釋放連線。
          _transport.close();
          return;
        } catch (e) {
          if (_cancelled) return;
          if (e is UploadSessionExpired || e is UploadStorageInsufficient) {
            rethrow;
          }
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
  Future<int> queryOffset() => _transport.query();

  /// 停止上傳並中止進行中的請求。工作階段本身不動（一週後自然失效）。
  void cancel() {
    _cancelled = true;
    _transport.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }
}

/// 一次 [UploadTransport.send] 的結果（成功或錯誤），等段內進度轉發完再處理。
class _SendResult {
  final int? next;
  final Object? error;
  final StackTrace? stackTrace;

  _SendResult(this.next) : error = null, stackTrace = null;

  _SendResult.failed(Object this.error, StackTrace this.stackTrace)
    : next = null;

  void rethrowIfFailed() {
    final e = error;
    if (e != null) Error.throwWithStackTrace(e, stackTrace!);
  }
}
