// 上傳暫存目錄：選檔的暫存複本搬進來、比對檔案、清孤兒檔。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/video_upload/upload_files_io.dart';

void main() {
  late Directory root;
  late Directory uploadDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('upload_files_test');
    uploadDir = Directory('${root.path}/admin_video_uploads');
    uploadDirOverride = () async => uploadDir;
  });
  tearDown(() async {
    uploadDirOverride = null;
    await root.delete(recursive: true);
  });

  test('暫存複本搬進上傳暫存目錄，原處不留；內容與大小不變', () async {
    final picked = File('${root.path}/IMG_0001.MOV')
      ..writeAsBytesSync([1, 2, 3]);

    final moved = await moveIntoUploadDir(picked.path);

    expect(File(moved).parent.path, uploadDir.path);
    expect(moved, endsWith('_IMG_0001.MOV'));
    expect(picked.existsSync(), isFalse);
    expect(File(moved).readAsBytesSync(), [1, 2, 3]);
    expect(await moveIntoUploadDir(moved), moved, reason: '已在目錄裡就不再搬');
  });

  test('搬不動（檔案不存在）就回原路徑', () async {
    final missing = '${root.path}/gone.mp4';
    expect(await moveIntoUploadDir(missing), missing);
  });

  test('檔案存在且大小一致才算相符', () async {
    final file = File('${root.path}/a.mp4')..writeAsBytesSync([1, 2, 3]);
    expect(await uploadFileMatches(file.path, 3), isTrue);
    expect(await uploadFileMatches(file.path, 4), isFalse);
    expect(await uploadFileMatches('${root.path}/none.mp4', 3), isFalse);
  });

  test('清孤兒檔：只留紀錄裡還用得到的', () async {
    await uploadDir.create(recursive: true);
    final keep = File('${uploadDir.path}/1_a.mp4')..writeAsBytesSync([1]);
    final orphan = File('${uploadDir.path}/2_b.mp4')..writeAsBytesSync([2]);

    await deleteOrphanUploadFiles({keep.path});

    expect(keep.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });
}
