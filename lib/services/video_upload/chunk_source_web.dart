// 網頁版的讀檔來源：File.slice(start, end) 再讀成位元組，一次只有一段在記憶體。
// 只在 Web 編譯（package:web 依賴 dart:js_interop），由網頁版選檔函式建立。

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'chunk_source.dart';

class WebChunkSource implements ChunkSource {
  final web.File file;

  WebChunkSource(this.file);

  @override
  int get size => file.size;

  @override
  Future<Uint8List> read(int start, int end) async {
    final buffer = await file.slice(start, end).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> discard() async {}
}
