// 手機背景上傳的入口（後台影片 T-06）：iOS、Android 用系統背景傳輸（background_upload_io.dart），
// 網頁版與桌面版沒有背景送法（回 null，上傳器用前景 http 分段送），網頁版也不載入 background_downloader。

import '../../models/admin_models.dart';
import '../../models/video_upload.dart';
import 'background_upload_stub.dart'
    if (dart.library.io) 'background_upload_io.dart'
    as platform;
import 'chunk_source.dart';
import 'upload_transport.dart';

/// 同一支影片的背景 task id 都以這個開頭。
String backgroundTaskPrefix(int videoId) => 'admin-video-$videoId-';

/// 手機且有本機檔案時回背景送法（Android 13 以下由它改用前景分段送）；其他情況回 null。
UploadTransport? backgroundTransportFor({
  required AdminVideo video,
  required UploadSession session,
  required ChunkSource source,
}) {
  final path = source.path;
  if (path == null) return null;
  return platform.backgroundTransportFor(
    session: session,
    source: source,
    filePath: path,
    taskPrefix: backgroundTaskPrefix(video.id),
    title: video.title,
  );
}

/// 這台裝置的上傳能在背景繼續（iOS、Android 14 以上）。畫面提示用。
Future<bool> backgroundUploadSupported() =>
    platform.backgroundUploadSupported();

/// 放棄一支影片時，取消系統裡還在跑的同一支背景上傳（上一次 App 程序留下的也算），並等它們結束。
/// 不然暫存檔刪了，已開啟的檔案仍可能被系統傳完。沒有背景送法的平台不做事。
Future<void> cancelBackgroundUploads(int videoId) =>
    platform.cancelBackgroundUploads(backgroundTaskPrefix(videoId));
