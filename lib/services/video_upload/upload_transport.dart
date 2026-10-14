// 上傳器送資料到雲端工作階段（GCS resumable）的方式。
// 協定：https://cloud.google.com/storage/docs/performing-resumable-uploads
//
// [ResumableUploader] 只管「查進度 → 從斷點送 → 失敗退避重試」，實際怎麼送交給 [UploadTransport]：
// - [HttpUploadTransport]：App 在前景時用 http.Client 一段一段 PUT（網頁版、桌面版都用這個）。
//
// 協定細節（兩種送法共用）：
// - 每次 `PUT session_url`，帶 `Content-Range: bytes {起}-{迄}/{總大小}`；中間段回 308，
//   下一段從 308 的 `Range` 上界 + 1 開始（不能假設這段全收到），沒有 `Range` 代表還沒收到任何位元組。
//   最後一段回 200／201。
// - 查進度：空內容＋`Content-Range: bytes */{總大小}`。
// - 404／410：工作階段失效（超過一週或已被取消）。

import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/video_upload.dart';
import 'chunk_source.dart';

/// 上傳中斷（網路錯誤、雲端回非預期狀態碼）。同一個工作階段可以查進度後接著傳。
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

/// 送資料到雲端工作階段的方式。一個上傳器用一個，同一時間只會有一個 [send] 或 [query] 在進行。
abstract class UploadTransport {
  /// true：一次請求就送完剩下的全部（上傳器不切段，送 `[斷點, 總大小)`）；
  /// false：照上傳器的每段大小一段一段送。
  bool get sendsWholeRemainder;

  /// 送 `[start, end)` 這一段。回雲端確認收到的下一個位元組位置（完成時是總大小）；
  /// 回 null 代表雲端沒說收到多少（例如背景送法讀不到 308 的 `Range`），上傳器會再查進度。
  /// [onProgress]：請求進行中已送出多少位元組（這一段之內，從 0 起），送法提供得到才會呼叫。
  /// 失敗丟 [UploadInterrupted]，工作階段失效丟 [UploadSessionExpired]。
  /// 網路類、換個時間再試可能會好的錯誤，[UploadInterrupted.cause] 是 [http.ClientException]
  /// 或 [TimeoutException]（上傳器據此決定要不要自動重試）。
  Future<int?> send(int start, int end, {void Function(int sent)? onProgress});

  /// 問雲端已收到多少：回下一個要傳的位元組位置；已完成回總大小。錯誤同 [send]。
  Future<int> query();

  /// 停止：中止進行中的請求（讓它以 [UploadInterrupted] 結束）並釋放資源，之後不再使用。
  void cancel();

  /// 傳完了，不會再送請求，釋放資源。
  void close();
}

/// 用 http.Client 一段一段 PUT。用獨立的 http.Client，不經 ApiClient：目標是雲端網址，不能帶 App 的 token。
///
/// 每個請求有逾時：送一段 [requestTimeout]、查進度 [queryTimeout]。手機切網路時連線可能不報錯也不回應，
/// 逾時就中止請求、丟 [UploadInterrupted]（cause 是 [TimeoutException]），不會一直卡住。
/// 不要改 followRedirects：網頁版 fetch 設成 false 會把 308 當網路錯誤；
/// 維持預設時 308 沒有 Location 會照原樣回來。dart:io 對 PUT 本來就不跟隨轉址。
class HttpUploadTransport implements UploadTransport {
  final UploadSession session;
  final ChunkSource source;
  final Duration requestTimeout;
  final Duration queryTimeout;
  final http.Client _client;
  bool _cancelled = false;

  /// 進行中的請求：[cancel] 時立刻中止並讓它以錯誤結束。
  void Function()? _stopRequest;

  HttpUploadTransport(
    this.session,
    this.source, {
    required this.requestTimeout,
    required this.queryTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  int get _total => session.size;

  @override
  bool get sendsWholeRemainder => false;

  /// 一段一段送，段內不回報進度（[onProgress] 不會被呼叫）。
  @override
  Future<int> send(
    int start,
    int end, {
    void Function(int sent)? onProgress,
  }) async {
    final bytes = await source.read(start, end);
    if (_cancelled) throw const UploadInterrupted(cause: 'cancelled');
    final response = await _put('bytes $start-${end - 1}/$_total', bytes);
    return _offsetFrom(response);
  }

  @override
  Future<int> query() async {
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

  @override
  void cancel() {
    _cancelled = true;
    _stopRequest?.call();
    _client.close();
  }

  @override
  void close() => _client.close();

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
