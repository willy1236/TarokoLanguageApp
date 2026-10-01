// 挑多張圖並壓縮成可上傳的 JPEG。活動圖片（詳情頁、發起／編輯活動）共用。

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'upload_image.dart';

/// 挑圖結果：可上傳的 JPEG bytes，與略過的圖片說明（全部可用時為 null）。
typedef PickedImages = ({List<Uint8List> images, String? skippedNotice});

/// 開相簿讓使用者最多選 [limit] 張，逐張壓縮（長邊 1920、JPEG）；無法處理或
/// 壓縮後仍超過 [maxBytes] 的略過，檔名放進 [PickedImages.skippedNotice]。
/// 使用者取消時回空清單。
///
/// 是變數而非函式，測試才能換成假的，不必真的開相簿與壓縮。
Future<PickedImages> Function({required int limit, required int maxBytes})
pickImagesForUpload = _pickAndCompress;

Future<PickedImages> _pickAndCompress({
  required int limit,
  required int maxBytes,
}) async {
  final picked = await ImagePicker().pickMultiImage(limit: limit);
  final images = <Uint8List>[];
  final skipped = <String>[];
  // 部分平台不尊重 limit，多選的直接不處理。
  for (final file in picked.take(limit)) {
    final compressed = await compressImageForUpload(file);
    if (compressed == null || compressed.length > maxBytes) {
      skipped.add(file.name);
    } else {
      images.add(compressed);
    }
  }
  final maxMb = maxBytes ~/ (1024 * 1024);
  return (
    images: images,
    skippedNotice: skipped.isEmpty
        ? null
        : '已略過 ${skipped.join('、')}：無法處理或壓縮後仍超過 $maxMb MB',
  );
}
