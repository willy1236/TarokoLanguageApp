// 網頁版選影片檔：<input type=file> 拿 web.File，不讀內容，上傳時才用 File.slice 分段讀。
// 由 video_file_picker.dart 條件匯入。

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'chunk_source_web.dart';
import 'video_file_picker.dart';

Future<RawPickedVideo?> pickRawVideo(
  VideoPickSource from, {
  VoidCallback? onPreparing,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'video/mp4,video/quicktime,.mp4,.mov';
  final completer = Completer<web.File?>();
  void finish(web.File? file) {
    if (!completer.isCompleted) completer.complete(file);
  }

  input.addEventListener(
    'change',
    ((web.Event _) => finish(input.files?.item(0))).toJS,
  );
  // Chrome 113 起取消選檔會送 cancel 事件；沒送的瀏覽器就一直等到下次選檔，不影響。
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();

  final file = await completer.future;
  if (file == null) return null;
  return (name: file.name, size: file.size, source: WebChunkSource(file));
}
