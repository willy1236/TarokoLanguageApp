// POST /api/events/:id/images、DELETE /api/events/:id/images/:imageId。
// 回應格式依後端 活動提醒.md §1.3e 手寫：錄製帳號目前沒有自己發起的活動，
// inspector 的上傳刪除測試會跳過（見 api_inspector_test.dart 的 _inspectEventImages）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('uploadImages', () {
    test('每張都放在 images 欄位、以 JPEG 送出，回傳後端給的完整清單', () async {
      late http.Request sent;
      installMockClient({
        '/api/events/9/images': jsonResponse({
          'images': [
            {'id': 1, 'url': 'https://a/1.jpg'},
            {'id': 2, 'url': 'https://a/2.jpg'},
            {'id': 3, 'url': 'https://a/3.jpg'},
          ],
        }, status: 201),
      }, onRequest: (r) => sent = r);

      final images = await EventService.uploadImages(9, [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3]),
      ]);

      expect(images.map((i) => i.id), [1, 2, 3]);
      expect(sent.method, 'POST');
      final body = latin1.decode(sent.bodyBytes);
      expect('name="images"'.allMatches(body).length, 2);
      expect('content-type: image/jpeg'.allMatches(body).length, 2);
    });

    test('失敗時丟出後端的錯誤', () async {
      installMockClient({
        '/api/events/9/images': errorResponse(
          'TOO_MANY_FILES',
          message: '每個活動最多 6 張圖片，目前已有 6 張',
        ),
      });

      await expectLater(
        EventService.uploadImages(9, [Uint8List(1)]),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'TOO_MANY_FILES')
              .having((e) => e.message, 'message', contains('6 張')),
        ),
      );
    });
  });

  group('deleteImage', () {
    test('回傳刪除後剩下的圖片', () async {
      installMockClient({
        '/api/events/9/images/2': {
          'ok': true,
          'images': [
            {'id': 1, 'url': 'https://a/1.jpg'},
          ],
        },
      });

      final images = await EventService.deleteImage(9, 2);
      expect(images.map((i) => i.id), [1]);
    });

    test('那張已經不在（IMAGE_NOT_FOUND）算成功，改用詳情目前的圖片', () async {
      installMockClient({
        '/api/events/9/images/2': errorResponse('IMAGE_NOT_FOUND', status: 404),
        '/api/events/9': {
          'id': 9,
          'title': 't',
          'starts_at': '2026-11-20T02:30:00Z',
          'images': [
            {'id': 1, 'url': 'https://a/1.jpg'},
          ],
        },
      });

      final images = await EventService.deleteImage(9, 2);
      expect(images.map((i) => i.id), [1]);
    });

    test('其他錯誤照常丟出', () async {
      installMockClient({
        '/api/events/9/images/2': errorResponse('FORBIDDEN', status: 403),
      });

      await expectLater(
        EventService.deleteImage(9, 2),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });
}
