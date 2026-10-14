// 手機（與桌面）的選影片檔：相簿用 image_picker、檔案用 file_picker，回本機路徑。
// 由 video_file_picker.dart 條件匯入。

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'chunk_source.dart';
import 'upload_files.dart';
import 'video_file_picker.dart';

/// 手機上兩種挑選器都會把檔案複製成 App 自己的暫存複本；桌面版 file_picker 回原檔路徑，不能刪。
bool get _isTemporaryCopy =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

Future<RawPickedVideo?> pickRawVideo(
  VideoPickSource from, {
  VoidCallback? onPreparing,
}) async {
  final String? path;
  final String name;
  switch (from) {
    case VideoPickSource.gallery:
      // image_picker 沒有「選好了、正在複製」的通知，從選好之前就顯示準備中。
      onPreparing?.call();
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return null;
      path = picked.path;
      name = picked.name;
    case VideoPickSource.files:
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov'],
        onFileLoading: (status) {
          if (status == FilePickerStatus.picking) onPreparing?.call();
        },
      );
      if (picked == null) return null;
      path = picked.path;
      name = picked.name;
  }
  if (path == null) return null;
  // 暫存複本搬進上傳暫存目錄，App 重開後還找得到（續傳，後台影片 T-05）。
  final temporary = _isTemporaryCopy;
  final kept = temporary ? await moveIntoUploadDir(path) : path;
  final source = ChunkSource.io(kept, temporary: temporary);
  return (name: name, size: source.size, source: source);
}
