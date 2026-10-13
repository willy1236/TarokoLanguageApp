// EventService.eventsChanged：活動本身有異動的 API 成功後通知活動分頁與廣場重抓。
// 失敗或沒有真的送出時不通知，免得列表白白重打。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_draft.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var fired = 0;
  void onChanged() => fired++;

  setUp(() {
    stubCommonChannels();
    fired = 0;
    EventService.eventsChanged.addListener(onChanged);
  });

  tearDown(() {
    EventService.eventsChanged.removeListener(onChanged);
    restoreHttp();
  });

  final startsAt = DateTime.now().add(const Duration(days: 7));
  final draft = EventDraft(
    title: '豐年祭',
    description: '一起來',
    address: '花蓮縣秀林鄉部落廣場',
    startsAt: startsAt,
    tribeId: 1,
    category: '族語',
  );
  EventDetail detail({String reminderNote = '帶水'}) => EventDetail(
    id: 1,
    title: '走讀',
    description: '說明',
    startsAt: startsAt,
    location: '部落',
    address: '秀林鄉',
    reminderNote: reminderNote,
    status: 'active',
  );

  group('成功時通知', () {
    test('發起活動', () async {
      installMockClient({
        '/api/events': jsonResponse({'id': 7}, status: 201),
      });
      await EventService.createEvent(draft);
      expect(fired, 1);
    });

    test('編輯活動', () async {
      installMockClient({
        '/api/events/1': {'ok': true},
      });
      await EventService.updateEvent(
        1,
        EventDraft.fromDetail(detail(reminderNote: '帶雨衣')),
        detail(),
      );
      expect(fired, 1);
    });

    test('刪除活動', () async {
      installMockClient({
        '/api/events/1': {'success': true, 'notified': 0},
      });
      await EventService.deleteEvent(1);
      expect(fired, 1);
    });

    test('取消活動', () async {
      installMockClient({
        '/api/events/1/cancel': {'ok': true},
      });
      await EventService.cancelEvent(1, '下雨');
      expect(fired, 1);
    });

    test('上傳照片', () async {
      installMockClient({
        '/api/events/1/images': jsonResponse({
          'images': [
            {'id': 1, 'url': 'https://a/1.jpg'},
          ],
        }, status: 201),
      });
      await EventService.uploadImages(1, [
        Uint8List.fromList([1]),
      ]);
      expect(fired, 1);
    });

    test('刪除照片', () async {
      installMockClient({
        '/api/events/1/images/2': {'images': <dynamic>[]},
      });
      await EventService.deleteImage(1, 2);
      expect(fired, 1);
    });
  });

  group('不通知', () {
    test('發起被後端拒絕', () async {
      installMockClient({
        '/api/events': errorResponse('CATEGORY_REQUIRED'),
      });
      await expectLater(EventService.createEvent(draft), throwsA(anything));
      expect(fired, 0);
    });

    test('刪除失敗', () async {
      installMockClient({
        '/api/events/1': errorResponse('EVENT_STARTED', status: 409),
      });
      await expectLater(EventService.deleteEvent(1), throwsA(anything));
      expect(fired, 0);
    });

    test('取消失敗', () async {
      installMockClient({
        '/api/events/1/cancel': errorResponse('EVENT_CLOSED', status: 409),
      });
      await expectLater(EventService.cancelEvent(1, '下雨'), throwsA(anything));
      expect(fired, 0);
    });

    test('上傳照片失敗', () async {
      installMockClient({
        '/api/events/1/images': errorResponse('TOO_MANY_IMAGES'),
      });
      await expectLater(
        EventService.uploadImages(1, [
          Uint8List.fromList([1]),
        ]),
        throwsA(anything),
      );
      expect(fired, 0);
    });

    test('編輯沒有任何變更（不送 PATCH）', () async {
      installMockClient(const {});
      await EventService.updateEvent(
        1,
        EventDraft.fromDetail(detail()),
        detail(),
      );
      expect(fired, 0);
    });

    test('報名、按讚、收藏不算活動異動', () async {
      installMockClient({
        '/api/events/1/join': <String, dynamic>{},
        '/api/events/1/like': {'liked': true, 'like_count': 1},
        '/api/events/1/bookmark': {'bookmarked': true},
      });
      await EventService.joinEvent(1, contactEmail: 'a@b.c');
      await EventService.likeEvent(1, like: true);
      await EventService.bookmarkEvent(1, add: true);
      expect(fired, 0);
    });
  });
}
