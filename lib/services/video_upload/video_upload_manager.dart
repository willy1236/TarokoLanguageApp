// App 層級的影片上傳服務：一次只傳一支，離開進度頁也繼續傳。
// 進度頁與影片管理列表只訂閱 [VideoUploadManager.active]，不持有上傳器。
//
// 狀態：uploading（傳送中）→ done（傳完，後端接著轉檔）；中途失敗變 interrupted，
// 可 [VideoUploadManager.retry]（查雲端已收到多少後接著傳，同一個 session_url）
// 或 [VideoUploadManager.cancel] 放棄。interrupted 仍算佔用，要重試或放棄後才能傳下一支。
// 上傳中不提供取消（後台影片 T-04 決定）。網路中斷時上傳器自己退避重試，用完才變 interrupted。
//
// 未完成清單（pending_uploads.dart）由這裡維護：[VideoUploadManager.start] 寫入（上傳、重新上傳
// 都經過它，同一支影片覆蓋舊的），傳完、放棄、工作階段失效時刪除。App 重開後由影片管理列表
// 呼叫 [VideoUploadManager.resume] 接著傳（後台影片 T-05）。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/admin_models.dart';
import '../../models/video_upload.dart';
import '../user_service.dart';
import 'chunk_source.dart';
import 'pending_uploads.dart';
import 'resumable_uploader.dart';
import 'upload_files.dart';
import 'video_file_picker.dart';

enum UploadState { uploading, interrupted, done }

class ActiveUpload {
  final AdminVideo video;
  final UploadProgress progress;
  final UploadState state;

  /// interrupted 時：雲端工作階段已失效（重試也沒用，只能放棄後重新上傳）。
  final bool sessionExpired;

  const ActiveUpload({
    required this.video,
    required this.progress,
    required this.state,
    this.sessionExpired = false,
  });

  ActiveUpload copyWith({
    UploadProgress? progress,
    UploadState? state,
    bool sessionExpired = false,
  }) => ActiveUpload(
    video: video,
    progress: progress ?? this.progress,
    state: state ?? this.state,
    sessionExpired: sessionExpired,
  );
}

/// 已有一支影片在上傳（或中斷待處理）時再呼叫 [VideoUploadManager.start]。
class UploadBusy implements Exception {
  final AdminVideo current;

  const UploadBusy(this.current);

  @override
  String toString() => 'UploadBusy(video ${current.id})';
}

/// 續傳時手機上的檔案不見了（被刪、被搬走或被系統清掉）或大小不符。
/// 請管理員重新選同一個檔案，或放棄。
class PendingFileMissing implements Exception {
  const PendingFileMissing();

  @override
  String toString() => 'PendingFileMissing';
}

/// 續傳時重選的檔案和原本的不同（檔名或大小不符），已擋下，要重選。
class PendingFileMismatch implements Exception {
  const PendingFileMismatch();

  @override
  String toString() => 'PendingFileMismatch';
}

typedef UploaderFactory =
    ResumableUploader Function(UploadSession session, ChunkSource source);

class VideoUploadManager {
  VideoUploadManager._();

  static final VideoUploadManager instance = VideoUploadManager._();

  /// 測試換成接假 http.Client 的上傳器。
  @visibleForTesting
  static UploaderFactory uploaderFactory = _defaultFactory;

  static ResumableUploader _defaultFactory(
    UploadSession session,
    ChunkSource source,
  ) => ResumableUploader(session, source);

  /// 寫入未完成紀錄時的登入者；測試換掉。
  @visibleForTesting
  static int? Function() currentUserId = () => UserService.currentUid;

  final _active = ValueNotifier<ActiveUpload?>(null);
  final _pending = PendingUploads.instance;

  /// 未完成紀錄的寫入依序進行（寫入、刪除不能顛倒）。
  Future<void> _pendingWrites = Future.value();
  ResumableUploader? _uploader;
  ChunkSource? _source;
  StreamSubscription<UploadProgress>? _subscription;

  /// 目前這一支；沒有時是 null。
  ValueListenable<ActiveUpload?> get active => _active;

  /// 有一支還沒傳完（傳送中或中斷待處理），不能再開始新的。
  bool get isBusy {
    final state = _active.value?.state;
    return state == UploadState.uploading || state == UploadState.interrupted;
  }

  /// 開始上傳 [video]（上傳、重新上傳都用這個）。[fileName] 是選檔時的檔名，記進未完成清單，
  /// App 重開或網頁重新整理後重選檔案時用來比對。已有一支未完成時丟 [UploadBusy]；
  /// 上一支已完成的會被取代。
  void start(
    AdminVideo video,
    UploadSession session,
    ChunkSource source, {
    required String fileName,
  }) {
    final current = _active.value;
    if (current != null && isBusy) throw UploadBusy(current.video);
    _uploader = uploaderFactory(session, source);
    _source = source;
    _active.value = ActiveUpload(
      video: video,
      progress: UploadProgress(sent: 0, total: session.size),
      state: UploadState.uploading,
    );
    final path = source.path;
    _writePending(
      () => _pending.save(
        PendingUpload(
          userId: currentUserId(),
          videoId: video.id,
          title: video.title,
          category: video.category,
          session: session,
          fileName: fileName,
          filePath: path,
          temporaryFile: path != null && source.temporary,
          createdAt: DateTime.now(),
        ),
      ),
    );
    _run();
  }

  /// 接著傳一支未完成的（App 重開、網頁重新整理後）。
  /// 手機不帶 [repicked]：用紀錄的檔案路徑，檔案不見或大小不符丟 [PendingFileMissing]。
  /// 網頁、或手機檔案不見時重選了檔案：帶 [repicked]，檔名與大小要和原本的一樣，
  /// 不一樣丟 [PendingFileMismatch]（重選的暫存複本已刪）。已有一支未完成時丟 [UploadBusy]。
  Future<void> resume(PendingUpload upload, {PickedVideoFile? repicked}) async {
    final current = _active.value;
    if (current != null && isBusy) {
      await repicked?.source.discard();
      throw UploadBusy(current.video);
    }
    final ChunkSource source;
    if (repicked != null) {
      if (repicked.info.name != upload.fileName ||
          repicked.info.size != upload.size) {
        await repicked.source.discard();
        throw const PendingFileMismatch();
      }
      source = repicked.source;
      // 原本的暫存複本（如果還在）用不到了。
      final old = upload.filePath;
      if (upload.temporaryFile && old != null && old != source.path) {
        await deleteUploadFile(old);
      }
    } else {
      final path = upload.filePath;
      if (path == null || !await uploadFileMatches(path, upload.size)) {
        throw const PendingFileMissing();
      }
      source = ChunkSource.io(path, temporary: upload.temporaryFile);
    }
    start(upload.video, upload.session, source, fileName: upload.fileName);
  }

  /// 中斷後重試：先查雲端已收到多少再接著傳。不是中斷狀態時不做事。
  void retry() {
    final current = _active.value;
    if (current == null || current.state != UploadState.interrupted) return;
    _active.value = current.copyWith(state: UploadState.uploading);
    _run();
  }

  /// 放棄目前這一支（只在中斷時由畫面提供）：停止上傳、刪掉 App 暫存的檔案複本。
  /// 後端的影片仍是「處理中」，超過 6 小時由後端標成失敗，可再用重新上傳補救。
  Future<void> cancel() async {
    final uploader = _uploader;
    final subscription = _subscription;
    final videoId = _active.value?.video.id;
    _uploader = null;
    _subscription = null;
    _active.value = null;
    if (videoId != null) _writePending(() => _pending.remove(videoId));
    // 先中止請求，再等上傳器真的停下（讀檔結束、關檔）才刪檔，不和進行中的讀取搶。
    uploader?.cancel();
    await subscription?.cancel();
    await _discardSource();
  }

  /// 完成的上傳看過了，從列表上方移除。不是完成狀態時不做事。
  void dismiss() {
    if (_active.value?.state == UploadState.done) _active.value = null;
  }

  void _run() {
    final uploader = _uploader;
    if (uploader == null) return;
    _subscription?.cancel();
    late final StreamSubscription<UploadProgress> subscription;
    subscription = _subscription = uploader.start().listen(
      (progress) {
        final current = _active.value;
        if (current != null) {
          _active.value = current.copyWith(progress: progress);
        }
      },
      onError: (Object e) {
        final current = _active.value;
        if (current == null) return;
        debugPrint('VideoUploadManager: 上傳中斷（video ${current.video.id}）：$e');
        _active.value = current.copyWith(
          state: UploadState.interrupted,
          sessionExpired: e is UploadSessionExpired,
        );
        // 工作階段失效就再也接不上了，清掉紀錄（暫存檔等放棄時刪，或下次啟動清孤兒檔）。
        if (e is UploadSessionExpired) {
          _writePending(() => _pending.remove(current.video.id));
        }
      },
      onDone: () {
        // 串流結束（傳完或中斷）就沒有東西可取消了，放棄時不必再等它。
        if (identical(_subscription, subscription)) _subscription = null;
        final current = _active.value;
        if (current == null || current.state != UploadState.uploading) return;
        if (current.progress.sent < current.progress.total) return;
        _active.value = current.copyWith(state: UploadState.done);
        _uploader = null;
        _writePending(() => _pending.remove(current.video.id));
        _discardSource();
      },
    );
  }

  Future<void> _discardSource() async {
    final source = _source;
    _source = null;
    try {
      await source?.discard();
    } catch (e) {
      debugPrint('VideoUploadManager: 刪除暫存影片檔失敗（忽略）：$e');
    }
  }

  void _writePending(Future<void> Function() write) {
    _pendingWrites = _pendingWrites.then((_) => write()).catchError((Object e) {
      debugPrint('VideoUploadManager: 更新未完成上傳紀錄失敗（忽略）：$e');
    });
  }

  /// 等未完成紀錄寫完（測試用）。
  @visibleForTesting
  Future<void> get pendingWrites => _pendingWrites;

  /// 測試之間清掉狀態。
  @visibleForTesting
  Future<void> resetForTest() async {
    await cancel();
    // 不等寫入：widget 測試的 fake async 裡排的寫入在 tearDown 不會跑完。
    _pendingWrites = Future.value();
    uploaderFactory = _defaultFactory;
    currentUserId = () => UserService.currentUid;
  }
}
