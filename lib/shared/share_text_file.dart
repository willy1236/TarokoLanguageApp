// 把後端回傳的文字內容（CSV、JSON）交給系統分享選單，讓使用者自行存檔/寄信/傳送。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/platform/platform_features.dart';

/// 手機寫成暫存檔再分享，分享完即刪除（內容多含個資，不留在暫存目錄等 OS 回收）；
/// Web 沒有暫存目錄，直接用記憶體內容分享（瀏覽器不支援 Web Share 時會下載）。
Future<void> shareTextFile({
  required String content,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  if (!PlatformFeatures.hasFileSystem) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(utf8.encode(content), name: filename, mimeType: mimeType),
        ],
        subject: subject,
      ),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  try {
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
      ),
    );
  } finally {
    // share 已回傳代表系統分享流程結束（接收端已取走內容）。
    try {
      await file.delete();
    } catch (e) {
      debugPrint('shareTextFile: 刪除暫存檔失敗（忽略）：$e');
    }
  }
}
