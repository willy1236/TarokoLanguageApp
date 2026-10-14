// 手機的上傳暫存目錄：App 快取下的 admin_video_uploads/。由 upload_files.dart 條件匯入。

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 測試換成暫存資料夾（path_provider 在單元測試沒有實作）。
@visibleForTesting
Future<Directory> Function()? uploadDirOverride;

Future<Directory> _uploadDir() async {
  final override = uploadDirOverride;
  final dir = override != null
      ? await override()
      : Directory(
          '${(await getApplicationCacheDirectory()).path}/admin_video_uploads',
        );
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String> moveIntoUploadDir(String path) async {
  try {
    final dir = await _uploadDir();
    final file = File(path);
    if (_sameDir(file.parent.path, dir.path)) return path;
    final name = _fileName(path);
    final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name';
    return (await file.rename(target)).path;
  } catch (e) {
    debugPrint('upload_files: 搬移影片暫存檔失敗，留在原處：$e');
    return path;
  }
}

Future<bool> uploadFileMatches(String path, int size) async {
  try {
    final file = File(path);
    return await file.exists() && await file.length() == size;
  } catch (_) {
    return false;
  }
}

Future<void> deleteOrphanUploadFiles(Set<String> keep) async {
  try {
    final dir = await _uploadDir();
    // 目錄裡的檔案只比對檔名（路徑分隔符號在各平台寫法不一）。
    final kept = keep.map(_fileName).toSet();
    await for (final entity in dir.list()) {
      if (entity is File && !kept.contains(_fileName(entity.path))) {
        await entity.delete();
      }
    }
  } catch (e) {
    debugPrint('upload_files: 清除孤兒影片暫存檔失敗（忽略）：$e');
  }
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

bool _sameDir(String a, String b) =>
    Directory(a).uri.normalizePath() == Directory(b).uri.normalizePath();
