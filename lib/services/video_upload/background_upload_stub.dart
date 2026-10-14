// 網頁版：沒有背景送法。由 background_upload.dart 條件匯入。

import '../../models/video_upload.dart';
import 'chunk_source.dart';
import 'upload_transport.dart';

UploadTransport? backgroundTransportFor({
  required UploadSession session,
  required ChunkSource source,
  required String filePath,
  required String taskPrefix,
  required String title,
}) => null;

Future<bool> backgroundUploadSupported() async => false;

Future<void> cancelBackgroundUploads(String taskPrefix) async {}
