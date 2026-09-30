// 上傳前的附圖壓縮，論壇發文與後台發公告共用。
//
// 後端不做伺服器端壓縮，且限制單張 5 MB，所以壓縮必須在 App 端完成。

import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/platform/platform_features.dart';

/// 把 [file] 縮到長邊 1920、轉成 JPEG（上傳時 Content-Type 一律用 image/jpeg）。
/// 無法處理時回 null。壓完仍可能超過後端的大小上限，由呼叫端檢查。
Future<Uint8List?> compressImageForUpload(XFile file) async {
  // Web 沒有檔案路徑，compressWithFile 不可用，改走 bytes 版本。
  return PlatformFeatures.hasFileSystem
      ? FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
          format: CompressFormat.jpeg,
        )
      : FlutterImageCompress.compressWithList(
          await file.readAsBytes(),
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
          format: CompressFormat.jpeg,
        );
}
