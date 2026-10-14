// 手機的讀檔來源：RandomAccessFile 依位移讀一段。由 chunk_source.dart 條件匯入。

import 'dart:io';
import 'dart:typed_data';

import 'chunk_source.dart';

class IoChunkSource implements ChunkSource {
  final String path;

  @override
  final int size;

  RandomAccessFile? _file;

  IoChunkSource(this.path) : size = File(path).lengthSync();

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
}
