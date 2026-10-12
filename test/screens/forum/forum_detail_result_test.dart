import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';

void main() {
  group('ForumDetailResult', () {
    test('預設什麼都沒發生，動態列表不移除', () {
      const result = ForumDetailResult();

      expect(result.deleted, isFalse);
      expect(result.removedFromFeed, isFalse);
      expect(result.removesFromFeed, isFalse);
    });

    test('刪除時動態列表要移除', () {
      const result = ForumDetailResult(deleted: true);

      expect(result.removedFromFeed, isFalse);
      expect(result.removesFromFeed, isTrue);
    });

    test('從動態拿掉時動態列表要移除，但不算刪除', () {
      const result = ForumDetailResult.removedFromFeed();

      expect(result.deleted, isFalse);
      expect(result.removedFromFeed, isTrue);
      expect(result.removesFromFeed, isTrue);
    });
  });
}
