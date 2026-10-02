// 活動照片欄位的排序：發起活動時拖曳換順序，上傳順序跟著變，第一張是封面。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_images_field.dart';
import 'package:flutter_application_1/shared/utils/pick_images.dart';

final _originalPicker = pickImagesForUpload;

/// 每張照片用第一個 byte 標號，方便比對順序。
List<Uint8List> _photos(int count) => [
  for (var i = 0; i < count; i++) Uint8List.fromList([i]),
];

/// 挑圖回傳 [photos]，回傳加好照片的 controller。
Future<EventImagesController> _withPending(
  List<Uint8List> photos, {
  List<EventImage> existing = const [],
}) async {
  pickImagesForUpload = ({required int limit, required int maxBytes}) async =>
      (images: photos, skippedNotice: null);
  final c = EventImagesController(existing);
  await c.pickMore();
  return c;
}

List<int> _order(EventImagesController c) => [
  for (final bytes in c.toUpload) bytes.first,
];

void main() {
  tearDown(() => pickImagesForUpload = _originalPicker);

  group('move', () {
    test('往前拖：拖到第一位的那張變成第一張上傳', () async {
      final c = await _withPending(_photos(4));
      var notified = 0;
      c.addListener(() => notified++);

      c.move(2, 0);

      expect(_order(c), [2, 0, 1, 3]);
      expect(notified, 1);
    });

    test('往後拖：to 是移完之後的位置', () async {
      final c = await _withPending(_photos(4));

      c.move(0, 3);
      expect(_order(c), [1, 2, 3, 0]);

      c.move(1, 2);
      expect(_order(c), [1, 3, 2, 0]);
    });

    test('原地放下不通知', () async {
      final c = await _withPending(_photos(3));
      var notified = 0;
      c.addListener(() => notified++);

      c.move(1, 1);

      expect(_order(c), [0, 1, 2]);
      expect(notified, 0);
    });

    test('超出範圍丟 RangeError，順序不變', () async {
      final c = await _withPending(_photos(2));

      expect(() => c.move(0, 2), throwsRangeError);
      expect(() => c.move(-1, 0), throwsRangeError);
      expect(_order(c), [0, 1]);
    });
  });

  group('canReorder', () {
    test('只有一張不能排序', () async {
      final c = await _withPending(_photos(1));
      expect(c.canReorder, isFalse);
    });

    test('兩張以上可以排序', () async {
      final c = await _withPending(_photos(2));
      expect(c.canReorder, isTrue);
    });

    test('有既有照片（編輯活動）時不能排序，move 不動', () async {
      final c = await _withPending(
        _photos(3),
        existing: const [EventImage(id: 1, url: 'https://a/1.jpg')],
      );

      expect(c.canReorder, isFalse);
      c.move(2, 0);
      expect(_order(c), [0, 1, 2]);
    });

    test('挑圖中不能排序，挑完恢復', () async {
      final c = await _withPending(_photos(2));
      final picking = Completer<PickedImages>();
      pickImagesForUpload = ({required int limit, required int maxBytes}) =>
          picking.future;

      final pick = c.pickMore();
      expect(c.canReorder, isFalse);
      c.move(1, 0);
      expect(_order(c), [0, 1]);

      picking.complete((images: <Uint8List>[], skippedNotice: null));
      await pick;
      expect(c.canReorder, isTrue);
    });

    test('刪到剩一張就不能排序', () async {
      final c = await _withPending(_photos(2));
      c.removePending(0);
      expect(c.canReorder, isFalse);
    });
  });
}
