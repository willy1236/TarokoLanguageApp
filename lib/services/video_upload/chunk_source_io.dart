// 手機的讀檔來源：RandomAccessFile 依位移讀一段。由 chunk_source.dart 條件匯入。

import 'dart:io';
import 'dart:typed_data';

import 'chunk_source.dart';

class IoChunkSource implements ChunkSource {
  @override
  final String path;
  @override
  final bool temporary;

  @override
  final int size;

  RandomAccessFile? _file;

  IoChunkSource(this.path, {this.temporary = false})
    : size = File(path).lengthSync();

  @override
  Future<Uint8List> read(int start, int end) async {
    final file = _file ??= await File(path).open();
    await file.setPosition(start);
    return file.read(end - start);
  }

  @override
  Future<void> close() async {
    final file = _file;
    _file = null;
    await file?.close();
  }

  @override
  Future<void> discard() async {
    // 關檔失敗（例如還有讀取在進行）也要刪暫存複本，不然 2GB 檔案會留在 App 裡。
    try {
      await close();
    } finally {
      if (temporary) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }
}
