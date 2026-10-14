// 未完成上傳的影片檔放在 App 快取下的 admin_video_uploads/：App 重開後續傳要找得到檔案。
//
// 手機的挑選器給的是 App 暫存複本（iOS 在 tmp，App 沒在跑時系統可能清掉；Android 在 cacheDir），
// 選好後搬（rename，同一個磁區不會多佔空間）到這裡。用快取目錄而不是 App Support：
// 不會進 iCloud／Android 備份（2GB 檔案會塞爆備份）；儲存空間吃緊時系統仍可能清掉，
// 續傳時檔案不見就請管理員重選同一個檔案（後台影片 T-05）。
// 網頁版沒有檔案系統，這裡的函式都不做事。

import 'upload_files_stub.dart'
    if (dart.library.io) 'upload_files_io.dart'
    as platform;

/// 把選檔時的暫存複本搬進上傳暫存目錄，回新路徑；搬不動就回原路徑（續傳時可能找不到檔案）。
Future<String> moveIntoUploadDir(String path) =>
    platform.moveIntoUploadDir(path);

/// [path] 的檔案還在且大小是 [size]。
Future<bool> uploadFileMatches(String path, int size) =>
    platform.uploadFileMatches(path, size);

/// 刪掉上傳暫存目錄裡不在 [keep] 的檔案（App 被關掉、紀錄已清掉留下的孤兒檔）。
Future<void> deleteOrphanUploadFiles(Set<String> keep) =>
    platform.deleteOrphanUploadFiles(keep);
