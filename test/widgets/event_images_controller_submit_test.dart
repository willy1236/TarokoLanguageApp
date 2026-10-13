// EventImagesController.submit：活動文字存好後送出照片。先刪後傳；照片失敗不
// 丟例外，回傳給發起人看的說明。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_images_field.dart';
import 'package:flutter_application_1/shared/utils/pick_images.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPicker = pickImagesForUpload;

  /// 依序記下打出去的請求（'METHOD path'）。
  final calls = <String>[];

  /// 要失敗的請求（'METHOD path'），回 500。
  final failing = <String>{};

  setUp(() {
    stubCommonChannels();
    calls.clear();
    failing.clear();
    ApiClient.httpClient = MockClient((request) async {
      final call = '${request.method} ${request.url.path}';
      calls.add(call);
      if (failing.contains(call)) {
        return errorResponse('SERVER_ERROR', message: '伺服器錯誤', status: 500);
      }
      return jsonResponse({'images': <dynamic>[]});
    });
  });

  tearDown(() {
    restoreHttp();
    pickImagesForUpload = originalPicker;
  });

  /// 建一個 controller：既有照片 [existingIds]，標記刪除 [removeIds]，
  /// 再挑 [newCount] 張新照片。
  Future<EventImagesController> controller({
    List<int> existingIds = const [],
    List<int> removeIds = const [],
    int newCount = 0,
  }) async {
    final c = EventImagesController([
      for (final id in existingIds) EventImage(id: id, url: 'https://x/$id'),
    ]);
    for (final image in c.existing) {
      if (removeIds.contains(image.id)) c.toggleRemoved(image);
    }
    if (newCount > 0) {
      pickImagesForUpload =
          ({required int limit, required int maxBytes}) async => (
            images: [
              for (var i = 0; i < newCount; i++) Uint8List.fromList([i]),
            ],
            skippedNotice: null,
          );
      await c.pickMore();
    }
    addTearDown(c.dispose);
    return c;
  }

  group('建立活動', () {
    test('沒選照片：不打 API，回 null', () async {
      final c = await controller();
      expect(await c.submit(5, creating: true), isNull);
      expect(calls, isEmpty);
    });

    test('有選照片：上傳到新活動，成功回 null', () async {
      final c = await controller(newCount: 2);
      expect(await c.submit(5, creating: true), isNull);
      expect(calls, ['POST /api/events/5/images']);
    });

    test('上傳失敗：不丟例外，提示稍後在編輯頁補上', () async {
      failing.add('POST /api/events/5/images');
      final c = await controller(newCount: 1);
      expect(await c.submit(5, creating: true), '圖片可以稍後在編輯頁補上（伺服器錯誤）');
    });
  });

  group('編輯活動', () {
    test('先刪標記的、再傳新的', () async {
      final c = await controller(
        existingIds: [11, 12, 13],
        removeIds: [11, 13],
        newCount: 1,
      );
      expect(await c.submit(1, creating: false), isNull);
      expect(calls, [
        'DELETE /api/events/1/images/11',
        'DELETE /api/events/1/images/13',
        'POST /api/events/1/images',
      ]);
    });

    test('沒有任何變更：不打 API', () async {
      final c = await controller(existingIds: [11]);
      expect(await c.submit(1, creating: false), isNull);
      expect(calls, isEmpty);
    });

    test('刪除失敗且沒有新照片：停在失敗那張，提示到活動頁再刪', () async {
      failing.add('DELETE /api/events/1/images/11');
      final c = await controller(existingIds: [11, 12], removeIds: [11, 12]);
      expect(await c.submit(1, creating: false), '有照片沒有刪除（伺服器錯誤），可到活動頁頂端再刪');
      expect(calls, ['DELETE /api/events/1/images/11']);
    });

    test('刪除失敗且有新照片：新照片也不傳，提示到活動頁調整', () async {
      failing.add('DELETE /api/events/1/images/11');
      final c = await controller(
        existingIds: [11],
        removeIds: [11],
        newCount: 1,
      );
      expect(
        await c.submit(1, creating: false),
        '有照片沒有刪除、新照片也沒有上傳（伺服器錯誤），可到活動頁頂端調整',
      );
      expect(calls, ['DELETE /api/events/1/images/11']);
    });

    test('刪除成功但上傳失敗：提示新照片沒有上傳', () async {
      failing.add('POST /api/events/1/images');
      final c = await controller(
        existingIds: [11],
        removeIds: [11],
        newCount: 1,
      );
      expect(await c.submit(1, creating: false), '新照片沒有上傳（伺服器錯誤），可到活動頁頂端重新新增');
      expect(calls, [
        'DELETE /api/events/1/images/11',
        'POST /api/events/1/images',
      ]);
    });

    test('沒有既有照片時上傳失敗：仍用編輯的提示', () async {
      failing.add('POST /api/events/1/images');
      final c = await controller(newCount: 1);
      expect(await c.submit(1, creating: false), '新照片沒有上傳（伺服器錯誤），可到活動頁頂端重新新增');
    });
  });
}
