// Web 沒有 dart:io：ChunkSource.io 不可用。網頁版改用 chunk_source_web.dart。

import 'dart:typed_data';

import 'chunk_source.dart';

class IoChunkSource implements ChunkSource {
  IoChunkSource(String path, {bool temporary = false}) {
    throw UnsupportedError('ChunkSource.io 只能在手機使用，網頁版請用 pickAdminVideoFile()');
  }

  @override
  String? get path => throw UnsupportedError('ChunkSource.io');

  @override
  int get size => throw UnsupportedError('ChunkSource.io');

  @override
  Future<Uint8List> read(int start, int end) =>
      throw UnsupportedError('ChunkSource.io');

  @override
  Future<void> close() async {}

  @override
  Future<void> discard() async {}
}
