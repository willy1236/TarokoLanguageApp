// 上傳器的讀檔來源：依位移一段一段讀，從不把整個檔案讀進記憶體（影片檔最大 2GB）。
//
// 手機（dart:io）用 [ChunkSource.io] 以 RandomAccessFile 讀；網頁版的來源由
// 只在 Web 編譯的 `chunk_source_web.dart`（`WebChunkSource`，用 File.slice）建立，
// 通常經 `pickAdminVideoFile()` 取得，呼叫端不必自己建。

import 'dart:typed_data';

import 'chunk_source_io_stub.dart'
    if (dart.library.io) 'chunk_source_io.dart'
    as platform;

abstract class ChunkSource {
  /// 本機檔案路徑（手機）。Web 上沒有 dart:io，呼叫會丟 [UnsupportedError]。
  /// [temporary]：檔案是選檔時複製出來的暫存複本，[discard] 時刪掉。
  factory ChunkSource.io(String path, {bool temporary}) =
      platform.IoChunkSource;

  /// 本機檔案路徑；網頁版沒有路徑，是 null。未完成上傳的紀錄靠它在 App 重開後找回檔案。
  String? get path;

  /// 檔案是選檔時複製出來的 App 暫存複本，[discard] 時會刪掉；網頁版與桌面版原檔是 false。
  bool get temporary;

  /// 檔案總大小（bytes）。
  int get size;

  /// 讀 [start] 到 [end]（不含）這一段。同一時間只會有一個讀取在進行。
  Future<Uint8List> read(int start, int end);

  /// 釋放開著的檔案。之後再 [read] 會重新開檔。
  Future<void> close();

  /// 這支不再上傳（完成或放棄）：關檔，暫存複本一併刪除。
  Future<void> discard();
}
