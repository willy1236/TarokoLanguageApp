// 未完成上傳清單：存讀、同一支只留一筆、續傳保留建立時間、刪除、放棄刪暫存檔、清孤兒檔、依帳號過濾。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/video_upload.dart';
import 'package:flutter_application_1/services/video_upload/pending_uploads.dart';
import 'package:flutter_application_1/services/video_upload/upload_files_io.dart';

PendingUpload _pending({
  int videoId = 107,
  int? userId = 20,
  String session = 'https://storage.googleapis.com/u?upload_id=a',
  String? filePath,
  bool temporaryFile = true,
  DateTime? createdAt,
}) => PendingUpload(
  userId: userId,
  videoId: videoId,
  title: '部落祭典紀錄',
  category: 'cultural',
  session: UploadSession(
    sessionUrl: Uri.parse(session),
    size: 1024,
    chunkMultiple: 262144,
  ),
  fileName: 'IMG_0001.MOV',
  filePath: filePath,
  temporaryFile: temporaryFile,
  createdAt: createdAt ?? DateTime(2026, 10, 14, 9),
);

void main() {
  final store = PendingUploads.instance;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store.resetForTest();
    dir = await Directory.systemTemp.createTemp('pending_uploads_test');
    uploadDirOverride = () async => dir;
  });
  tearDown(() async {
    uploadDirOverride = null;
    await dir.delete(recursive: true);
  });

  test('存進去的紀錄 App 重開後讀得回來（欄位完整）', () async {
    await store.save(_pending(filePath: '/x/1_IMG_0001.MOV'));

    store.resetForTest();
    expect(store.items.value, isEmpty);
    await store.load();

    final p = store.items.value.single;
    expect(p.userId, 20);
    expect(p.videoId, 107);
    expect(p.title, '部落祭典紀錄');
    expect(p.category, 'cultural');
    expect(p.session.sessionUrl.toString(), contains('upload_id=a'));
    expect(p.size, 1024);
    expect(p.session.chunkMultiple, 262144);
    expect(p.fileName, 'IMG_0001.MOV');
    expect(p.filePath, '/x/1_IMG_0001.MOV');
    expect(p.temporaryFile, isTrue);
    expect(p.createdAt, DateTime(2026, 10, 14, 9));
    expect(p.video.id, 107);
    expect(p.video.status, 'processing');
  });

  test('同一支影片只留一筆；同一個工作階段保留建立時間，新的工作階段（重新上傳）換新', () async {
    await store.save(_pending());
    await store.save(_pending(createdAt: DateTime(2026, 10, 15)));
    expect(store.items.value.single.createdAt, DateTime(2026, 10, 14, 9));

    await store.save(
      _pending(
        session: 'https://storage.googleapis.com/u?upload_id=b',
        createdAt: DateTime(2026, 10, 20),
      ),
    );
    expect(store.items.value.single.createdAt, DateTime(2026, 10, 20));

    await store.save(_pending(videoId: 108));
    expect(store.items.value.map((p) => p.videoId), [107, 108]);
  });

  test('remove 刪紀錄不動檔案；discard 連暫存複本一起刪（非暫存的原檔不刪）', () async {
    final temp = File('${dir.path}/1_a.mov')..writeAsBytesSync([1]);
    final original = File('${dir.path}/orig.mov')..writeAsBytesSync([1]);
    await store.save(_pending(videoId: 1, filePath: temp.path));
    await store.save(
      _pending(videoId: 2, filePath: original.path, temporaryFile: false),
    );
    await store.save(_pending(videoId: 3, filePath: temp.path));

    await store.remove(3);
    expect(temp.existsSync(), isTrue);

    await store.discard(store.items.value.firstWhere((p) => p.videoId == 1));
    await store.discard(store.items.value.firstWhere((p) => p.videoId == 2));
    expect(store.items.value, isEmpty);
    expect(temp.existsSync(), isFalse);
    expect(original.existsSync(), isTrue);

    final saved = await SharedPreferences.getInstance();
    expect(jsonDecode(saved.getString('admin_video_pending_uploads')!), []);
  });

  test('App 啟動後第一次 load 清掉沒有紀錄的暫存檔；之後不再清', () async {
    final kept = File('${dir.path}/1_a.mov')..writeAsBytesSync([1]);
    final orphan = File('${dir.path}/2_b.mov')..writeAsBytesSync([1]);
    await store.save(_pending(filePath: kept.path));
    store.resetForTest();

    await store.load();
    expect(kept.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);

    final picked = File('${dir.path}/3_c.mov')..writeAsBytesSync([1]);
    await store.load();
    expect(picked.existsSync(), isTrue, reason: '選好還沒送出的檔案不能清');
  });

  test('只顯示給同一個管理員', () async {
    await store.save(_pending(videoId: 1, userId: 20));
    await store.save(_pending(videoId: 2, userId: 21));
    expect(store.visibleTo(20).map((p) => p.videoId), [1]);
    expect(store.visibleTo(null), isEmpty);
  });

  test('超過一週視為工作階段已過期', () {
    final p = _pending(createdAt: DateTime(2026, 10, 1));
    expect(p.isExpiredAt(DateTime(2026, 10, 7, 23)), isFalse);
    expect(p.isExpiredAt(DateTime(2026, 10, 8)), isTrue);
  });

  test('整份壞掉：當作沒有，也不清暫存檔', () async {
    final file = File('${dir.path}/1_a.mov')..writeAsBytesSync([1]);
    SharedPreferences.setMockInitialValues({
      'admin_video_pending_uploads': '{not json',
    });
    store.resetForTest();
    await store.load();
    expect(store.items.value, isEmpty);
    expect(file.existsSync(), isTrue);
  });

  test('其中一筆壞掉：其他照常讀出，不清暫存檔；之後寫入保留好的那幾筆', () async {
    final file = File('${dir.path}/9_unknown.mov')..writeAsBytesSync([1]);
    SharedPreferences.setMockInitialValues({
      'admin_video_pending_uploads': jsonEncode([
        {'video_id': 'oops'},
        _pending(videoId: 1).toJson(),
      ]),
    });
    store.resetForTest();
    await store.load();
    expect(store.items.value.map((p) => p.videoId), [1]);
    expect(file.existsSync(), isTrue, reason: '壞掉那筆可能用的是這個檔案');

    await store.save(_pending(videoId: 2));
    store.resetForTest();
    await store.load();
    expect(store.items.value.map((p) => p.videoId), [1, 2]);
  });
}
