// 手機的系統背景傳輸：background_downloader 9.5.9（iOS 背景 URLSession、Android 14 以上 UIDT）。
// 由 background_upload.dart 條件匯入；桌面版沒有背景送法（回 null）。
//
// - task 用 PUT、binary、不自動重試（重試由上傳器回前景查進度後重排）。
// - Android 14 以上：priority 0＋進行中通知 → 套件排 UIDT。要設 `Config.runInForeground`：
//   套件每個 task 開始時依它重算 runInForeground，沒設就是 false，priority 0 的 task 2 分鐘就被中止
//   （`TaskRunner.kt` determineRunInForeground、expedited 逾時）。UIDT 下「前景」是
//   `JobService.setNotification`，不是前景服務；UIDT 排程失敗退回 WorkManager 時套件會呼叫
//   setForeground(dataSync)，App 沒宣告前景服務權限會失敗，套件 catch 後退回 2 分鐘限制
//   （`Notifications.kt`），不會真的開前景服務（2026-10-14 決定 A）。
// - Android 13 以下：[BackgroundUploadEngine.available] 為 false，送法改用前景 http 分段（決定 E）。
// - iOS 不設通知（不碰推播用的通知設定）；單一請求最久 24 小時，請求逾時用系統預設。
// - FileDownloader 等到第一次上傳才初始化，App 啟動時不做事。

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../models/video_upload.dart';
import 'background_upload_transport.dart';
import 'chunk_source.dart';
import 'resumable_uploader.dart';
import 'upload_transport.dart';

bool get _mobile => Platform.isAndroid || Platform.isIOS;

UploadTransport? backgroundTransportFor({
  required UploadSession session,
  required ChunkSource source,
  required String filePath,
  required String taskPrefix,
  required String title,
}) {
  if (!_mobile) return null;
  return BackgroundUploadTransport(
    engine: FileDownloaderEngine.instance,
    sessionUrl: session.sessionUrl,
    total: session.size,
    filePath: filePath,
    taskPrefix: taskPrefix,
    displayName: title,
    contentType: UploadFileInfo.contentTypeOf(filePath),
    foreground: AppForeground.instance.value,
    http: HttpUploadTransport(
      session,
      source,
      requestTimeout: ResumableUploader.defaultRequestTimeout,
      queryTimeout: ResumableUploader.defaultQueryTimeout,
    ),
    fallbackChunkSize: ResumableUploader.alignChunk(
      ResumableUploader.defaultChunkSize,
      session.chunkMultiple,
    ),
  );
}

Future<bool> backgroundUploadSupported() async =>
    _mobile && await FileDownloaderEngine.instance.available;

Future<void> cancelBackgroundUploads(String taskPrefix) async {
  if (!_mobile) return;
  final engine = FileDownloaderEngine.instance;
  if (!await engine.available) return;
  await cancelBackgroundTasks(engine, taskPrefix);
}

/// App 是否在前景（resumed）。第一次用到才開始監看；回到前景時順便取回背景期間的 task 狀態。
class AppForeground with WidgetsBindingObserver {
  AppForeground._() {
    final state = WidgetsBinding.instance.lifecycleState;
    _value.value = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  static final instance = AppForeground._();

  final _value = ValueNotifier(true);

  ValueListenable<bool> get value => _value;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _value.value) return;
    _value.value = resumed;
    if (resumed) FileDownloaderEngine.instance.resumeFromBackground();
  }
}

class FileDownloaderEngine implements BackgroundUploadEngine {
  FileDownloaderEngine._();

  static final instance = FileDownloaderEngine._();

  static const group = 'admin_video_upload';

  /// iOS 單一請求最久可以傳多久（2GB 用 1Mbps 約 4.5 小時，套件預設 4 小時不夠）。
  static const _resourceTimeout = Duration(hours: 24);

  static const _storageChannel = MethodChannel('truku/storage');

  final _events = StreamController<BackgroundEvent>.broadcast();

  /// task id → 這個 task 要送的位元組數（把套件的 0～1 進度換成位元組）。
  final _lengths = <String, int>{};
  Future<bool>? _available;
  Future<void>? _ready;

  FileDownloader get _downloader => FileDownloader();

  @override
  Future<bool> get available => _available ??= _checkAvailable();

  Future<bool> _checkAvailable() async {
    if (Platform.isIOS) return true;
    if (!Platform.isAndroid) return false;
    final sdk = int.tryParse(await _downloader.platformVersion()) ?? 0;
    return sdk >= 34;
  }

  @override
  bool get copiesPartialFile => Platform.isIOS;

  @override
  Future<int?> freeBytes() async {
    if (!Platform.isIOS) return null;
    try {
      return await _storageChannel.invokeMethod<int>('freeBytes');
    } catch (e) {
      debugPrint('FileDownloaderEngine: 查剩餘空間失敗（不擋）：$e');
      return null;
    }
  }

  @override
  Stream<BackgroundEvent> get events => _events.stream;

  Future<void> _ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: _onStatus,
      taskProgressCallback: _onProgress,
    );
    if (Platform.isAndroid) {
      await _downloader.configure(
        androidConfig: [(Config.runInForeground, Config.always)],
      );
      _downloader.configureNotificationForGroup(
        group,
        running: const TaskNotification('影片上傳中', '{displayName}'),
        complete: const TaskNotification(
          '影片上傳完成',
          '{displayName}：轉檔需要幾分鐘，完成後會自動上架',
        ),
        progressBar: true,
      );
    } else {
      await _downloader.configure(
        iOSConfig: [(Config.resourceTimeout, _resourceTimeout)],
      );
    }
    // 取回 App 不在時累積的狀態。
    await _downloader.resumeFromBackground();
  }

  /// App 回到前景：取回背景期間的 task 狀態（還沒用過背景上傳時不做事）。
  void resumeFromBackground() {
    final ready = _ready;
    if (ready == null) return;
    unawaited(
      ready
          .then((_) => _downloader.resumeFromBackground())
          .catchError(
            (Object e) => debugPrint('FileDownloaderEngine: 取回背景狀態失敗（忽略）：$e'),
          ),
    );
  }

  @override
  Future<bool> enqueue(BackgroundPut put) async {
    await _ensureReady();
    final (baseDirectory, directory, filename) = await Task.split(
      filePath: put.filePath,
    );
    final headers = Map.of(put.headers);
    // 套件用 mimeType 設 Content-Type（會蓋掉 headers 裡的）。
    final contentType = headers.remove('Content-Type');
    final task = UploadTask(
      taskId: put.taskId,
      url: put.url.toString(),
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      headers: headers,
      httpRequestMethod: 'PUT',
      post: 'binary',
      mimeType: contentType,
      group: group,
      updates: Updates.statusAndProgress,
      retries: 0,
      priority: 0,
      displayName: put.displayName,
    );
    _lengths[put.taskId] = put.end - put.start;
    final queued = await _downloader.enqueue(task);
    if (!queued) _lengths.remove(put.taskId);
    return queued;
  }

  @override
  Future<List<String>> activeTaskIds(String prefix) async {
    await _ensureReady();
    return [
      for (final id in await _downloader.allTaskIds(group: group))
        if (id.startsWith(prefix)) id,
    ];
  }

  @override
  Future<void> cancel(String taskId) async {
    await _ensureReady();
    await _downloader.cancelTaskWithId(taskId);
  }

  void _onProgress(TaskProgressUpdate update) {
    final progress = update.progress;
    // 負值代表狀態（失敗、取消等），由狀態回呼處理。
    if (progress < 0 || progress > 1) return;
    final taskId = update.task.taskId;
    final length = _lengths[taskId] ?? update.expectedFileSize;
    if (length <= 0) return;
    _events.add(BackgroundEvent.progress(taskId, (progress * length).floor()));
  }

  void _onStatus(TaskStatusUpdate update) {
    final taskId = update.task.taskId;
    final status = switch (update.status) {
      TaskStatus.enqueued => BackgroundTaskStatus.enqueued,
      TaskStatus.running => BackgroundTaskStatus.running,
      TaskStatus.complete => BackgroundTaskStatus.complete,
      TaskStatus.failed => BackgroundTaskStatus.failed,
      TaskStatus.notFound => BackgroundTaskStatus.notFound,
      TaskStatus.canceled => BackgroundTaskStatus.canceled,
      _ => null,
    };
    if (status == null) return;
    if (status.finished) _lengths.remove(taskId);
    final exception = update.exception;
    _events.add(
      BackgroundEvent.status(
        taskId,
        status,
        httpStatus: exception is TaskHttpException
            ? exception.httpResponseCode
            : update.responseStatusCode,
        description: exception?.description,
      ),
    );
  }
}
