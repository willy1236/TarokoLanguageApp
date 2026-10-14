// App 層級的影片上傳服務：一次只傳一支，離開進度頁也繼續傳。
// 進度頁與影片管理列表只訂閱 [VideoUploadManager.active]，不持有上傳器。
//
// 狀態：uploading（傳送中）→ done（傳完，後端接著轉檔）；中途失敗變 interrupted，
// 可 [VideoUploadManager.retry]（查雲端已收到多少後接著傳，同一個 session_url）
// 或 [VideoUploadManager.cancel] 放棄。interrupted 仍算佔用，要重試或放棄後才能傳下一支。
// 上傳中不提供取消（後台影片 T-04 決定）。這裡不做持久化，App 被關掉就沒了（續傳見 T-05）。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/admin_models.dart';
import '../../models/video_upload.dart';
import 'chunk_source.dart';
import 'resumable_uploader.dart';

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

  final _active = ValueNotifier<ActiveUpload?>(null);
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

  /// 開始上傳 [video]。已有一支未完成時丟 [UploadBusy]；上一支已完成的會被取代。
  void start(AdminVideo video, UploadSession session, ChunkSource source) {
    final current = _active.value;
    if (current != null && isBusy) throw UploadBusy(current.video);
    _uploader = uploaderFactory(session, source);
    _source = source;
    _active.value = ActiveUpload(
      video: video,
      progress: UploadProgress(sent: 0, total: session.size),
      state: UploadState.uploading,
    );
    _run();
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
    _subscription?.cancel();
    _subscription = null;
    _uploader?.cancel();
    _uploader = null;
    _active.value = null;
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
    _subscription = uploader.start().listen(
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
      },
      onDone: () {
        final current = _active.value;
        if (current == null || current.state != UploadState.uploading) return;
        if (current.progress.sent < current.progress.total) return;
        _active.value = current.copyWith(state: UploadState.done);
        _uploader = null;
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

  /// 測試之間清掉狀態。
  @visibleForTesting
  Future<void> resetForTest() async {
    await cancel();
    uploaderFactory = _defaultFactory;
  }
}
