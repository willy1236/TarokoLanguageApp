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

  final UploadSession session;
  final ChunkSource source;

  /// 實際每段大小：[defaultChunkSize] 或指定值，向下取到 chunk_size_multiple 的倍數。
  final int chunkSize;

  final http.Client _client;
  bool _cancelled = false;

  ResumableUploader(
    this.session,
    this.source, {
    int chunkSize = defaultChunkSize,
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
  /// 每傳完一段送一次進度；完成時關閉。失敗丟 [UploadInterrupted]／[UploadSessionExpired]；
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
    _client.close();
  }

  Future<http.Response> _put(String contentRange, List<int> body) async {
    final request = http.Request('PUT', session.sessionUrl)
      ..headers['Content-Range'] = contentRange
      ..bodyBytes = body;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
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
