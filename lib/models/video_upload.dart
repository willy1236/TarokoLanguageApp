// 後台上傳影片檔（source: upload）的檔案資訊與雲端上傳工作階段。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2「影片檔」。

/// 影片檔大小上限（bytes），同後端 2GB。
const int adminVideoMaxBytes = 2147483648;

/// 送給後端建立影片（或重傳）用的檔案資訊。
class UploadFileInfo {
  final String name;

  /// bytes。
  final int size;

  /// `video/mp4` 或 `video/quicktime`，由副檔名決定。
  final String contentType;

  const UploadFileInfo({
    required this.name,
    required this.size,
    required this.contentType,
  });

  /// 副檔名對應的 Content-Type；不是 mp4／mov 回 null（後端只收這兩種）。
  static String? contentTypeOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return switch (fileName.substring(dot + 1).toLowerCase()) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => null,
    };
  }

  Map<String, Object?> toJson() => {
    'file_name': name,
    'file_size': size,
    'content_type': contentType,
  };
}

/// 雲端可續傳上傳的工作階段（GCS resumable）。對 [sessionUrl] 分段 `PUT`，
/// 每段（最後一段除外）是 [chunkMultiple] 的倍數；一週內有效。
class UploadSession {
  final Uri sessionUrl;

  /// 檔案總大小（bytes），必須和實際送出的一樣，否則雲端拒收。
  final int size;
  final int chunkMultiple;

  const UploadSession({
    required this.sessionUrl,
    required this.size,
    required this.chunkMultiple,
  });

  factory UploadSession.fromJson(Map<String, dynamic> j) => UploadSession(
    sessionUrl: Uri.parse(j['session_url'] as String),
    size: (j['size'] as num).toInt(),
    chunkMultiple: (j['chunk_size_multiple'] as num?)?.toInt() ?? 262144,
  );
}
