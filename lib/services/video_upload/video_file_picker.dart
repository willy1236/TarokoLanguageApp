// 後台選影片檔（上傳、重新上傳共用）：手機「從相簿」「從檔案」、網頁 <input type=file>，
// 選完檢查格式（mp4／mov）與大小（≤2GB），回傳送給後端的檔案資訊和上傳器的讀檔來源。
//
// - 從相簿：image_picker.pickVideo。iOS 走 PHPicker 並取原始檔（不轉檔），
//   Android 會先把整個檔案複製到 App 快取，2GB 要等一下。
// - 從檔案：file_picker（FileType.custom）。Android 一樣先複製到快取，iOS 由系統複製到 tmp。
// - 網頁：只有一種來源，用 File.slice 分段讀（見 chunk_source_web.dart）。
// 手機上兩種來源拿到的都是 App 自己的暫存複本，搬進上傳暫存目錄（見 upload_files.dart），
// 完成或放棄時由上傳服務刪掉。

import 'package:flutter/foundation.dart';

import '../../models/video_upload.dart';
import 'chunk_source.dart';
import 'video_file_picker_io.dart'
    if (dart.library.js_interop) 'video_file_picker_web.dart'
    as platform;

/// 選檔來源。網頁只有 [files]。
enum VideoPickSource { gallery, files }

/// 選好的影片檔。
class PickedVideoFile {
  final UploadFileInfo info;
  final ChunkSource source;

  const PickedVideoFile({required this.info, required this.source});
}

/// 選到的檔案不能上傳（格式或大小不符）。[message] 直接顯示給管理員。
class VideoFileRejected implements Exception {
  final String message;

  const VideoFileRejected(this.message);

  @override
  String toString() => 'VideoFileRejected($message)';
}

/// 平台選檔的原始結果（還沒檢查）。
typedef RawPickedVideo = ({String name, int size, ChunkSource source});

typedef AdminVideoPicker =
    Future<PickedVideoFile?> Function(
      VideoPickSource from, {
      VoidCallback? onPreparing,
    });

/// 測試換成假的選檔。
@visibleForTesting
AdminVideoPicker? adminVideoPickerOverride;

/// 選一支影片檔。取消回 null；格式或大小不符丟 [VideoFileRejected]（暫存複本已刪）。
/// [onPreparing]：選好後系統還在複製檔案時呼叫（Android 大檔要等），畫面顯示「準備檔案中」。
Future<PickedVideoFile?> pickAdminVideoFile(
  VideoPickSource from, {
  VoidCallback? onPreparing,
}) async {
  final override = adminVideoPickerOverride;
  if (override != null) return override(from, onPreparing: onPreparing);
  final raw = await platform.pickRawVideo(from, onPreparing: onPreparing);
  if (raw == null) return null;
  final contentType = UploadFileInfo.contentTypeOf(raw.name);
  final error = videoFileError(raw.name, raw.size);
  if (error != null || contentType == null) {
    await raw.source.discard();
    throw VideoFileRejected(error ?? '只能上傳 mp4、mov 影片檔');
  }
  return PickedVideoFile(
    info: UploadFileInfo(
      name: raw.name,
      size: raw.size,
      contentType: contentType,
    ),
    source: raw.source,
  );
}

/// 檔案能不能上傳；可以回 null，否則回給管理員看的原因。
String? videoFileError(String name, int size) {
  if (UploadFileInfo.contentTypeOf(name) == null) {
    return '只能上傳 mp4、mov 影片檔';
  }
  if (size <= 0) return '這個檔案是空的，請重新選擇';
  if (size > adminVideoMaxBytes) return '影片檔最大 2GB，請壓縮或剪短後再上傳';
  return null;
}
