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
// 每個請求有逾時（[ResumableUploader.requestTimeout]）：手機切網路時連線可能不報錯也不回應，
// 逾時就中止請求、丟 [UploadInterrupted]，不會一直卡在上傳中。
// 不要改 followRedirects：網頁版 fetch 設成 false 會把 308 當網路錯誤；
// 維持預設時 308 沒有 Location 會照原樣回來。dart:io 對 PUT 本來就不跟隨轉址。

import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/video_upload.dart';
import 'chunk_source.dart';

/// 已傳／總大小（bytes）。
class UploadProgress {
  final int sent;
  final int total;

  const UploadProgress({required this.sent, required this.total});

  int get remaining => total - sent;

  /// 0～1。
  double get fraction => total <= 0 ? 0 : sent / total;

  @override
  bool operator ==(Object other) =>
      other is UploadProgress && other.sent == sent && other.total == total;

  @override
  int get hashCode => Object.hash(sent, total);

  @override
  String toString() => 'UploadProgress($sent/$total)';
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

  final UploadSession session;
  final ChunkSource source;

  /// 實際每段大小：[defaultChunkSize] 或指定值，向下取到 chunk_size_multiple 的倍數。
  final int chunkSize;

  /// 一個請求（送出一段到收到回應）最多等多久，超過就中止、丟 [UploadInterrupted]。
  final Duration requestTimeout;

  final http.Client _client;
  bool _cancelled = false;

  /// 進行中的請求：[cancel] 時立刻中止並讓它以錯誤結束。
  void Function()? _stopRequest;

  ResumableUploader(
    this.session,
    this.source, {
    int chunkSize = defaultChunkSize,
    this.requestTimeout = defaultRequestTimeout,
    http.Client? client,
  }) : chunkSize = _alignChunk(chunkSize, session.chunkMultiple),
       _client = client ?? http.Client();

  static int _alignChunk(int size, int multiple) {
    if (multiple <= 0) return size;
    final aligned = size - size % multiple;
    return aligned < multiple ? multiple : aligned;
  }

  int get _total => session.size;

  /// 從雲端已收到的位置接著傳到完成。先查進度再傳，所以中斷後重新呼叫即是續傳。
  /// 每傳完一段送一次進度；完成時關閉串流並關掉 http.Client（之後不能再用）。失敗丟 [UploadInterrupted]／[UploadSessionExpired]；
  /// [cancel] 後安靜關閉。
  Stream<UploadProgress> start() async* {
    try {
      var offset = await queryOffset();
      if (_cancelled) return;
      yield UploadProgress(sent: offset, total: _total);
      while (offset < _total) {
        final end = offset + chunkSize < _total ? offset + chunkSize : _total;
        final bytes = await source.read(offset, end);
        if (_cancelled) return;
        final response = await _put('bytes $offset-${end - 1}/$_total', bytes);
        if (_cancelled) return;
        offset = _offsetFrom(response);
        yield UploadProgress(sent: offset, total: _total);
      }
      // 傳完了，這個上傳器不會再送請求，釋放連線。
      _client.close();
    } catch (e) {
      if (_cancelled) return;
      if (e is UploadInterrupted || e is UploadSessionExpired) rethrow;
      throw UploadInterrupted(cause: e);
    } finally {
      await source.close();
    }
  }

  /// 問雲端已收到多少：回下一個要傳的位元組位置；已完成回總大小。
  Future<int> queryOffset() async {
    final http.Response response;
    try {
      response = await _put('bytes */$_total', const []);
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
    _client.close();
  }

  Future<http.Response> _put(String contentRange, List<int> body) async {
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
      requestTimeout,
      () => stop(
        UploadInterrupted(cause: TimeoutException('雲端沒有回應', requestTimeout)),
      ),
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
