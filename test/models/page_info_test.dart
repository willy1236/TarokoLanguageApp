import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/page_info.dart';

void main() {
  group('PageInfo.fromResponse', () {
    test('讀 page_info 的字串游標與 has_more', () {
      final info = PageInfo.fromResponse({
        'items': [],
        'page_info': {'next_cursor': '53', 'has_more': true},
      });
      expect(info.nextCursor, '53');
      expect(info.hasMore, isTrue);
    });

    test('has_more 為 false 時沒有下一頁', () {
      final info = PageInfo.fromResponse({
        'page_info': {'next_cursor': null, 'has_more': false},
      });
      expect(info.nextCursor, isNull);
      expect(info.hasMore, isFalse);
    });

    test('沒有 page_info 時當作沒有下一頁，不回頭讀頂層的舊 next_cursor', () {
      final info = PageInfo.fromResponse({'next_cursor': 13});
      expect(info.nextCursor, isNull);
      expect(info.hasMore, isFalse);
    });

    test('has_more 為 false 時即使帶了游標也不再往下翻', () {
      final info = PageInfo.fromResponse({
        'page_info': {'next_cursor': '40', 'has_more': false},
      });
      expect(info.nextCursor, isNull);
      expect(info.hasMore, isFalse);
    });

    test('has_more 為 true 但沒有游標時也不算有下一頁，避免重打第一頁', () {
      final info = PageInfo.fromResponse({
        'page_info': {'next_cursor': null, 'has_more': true},
      });
      expect(info.hasMore, isFalse);
    });
  });

  group('PageInfo.query', () {
    test('第一頁不帶 cursor', () {
      expect(PageInfo.query(limit: 20), {'limit': '20'});
    });

    test('之後帶上一頁的游標原字串', () {
      expect(PageInfo.query(cursor: 'abc:12', limit: 20), {
        'cursor': 'abc:12',
        'limit': '20',
      });
    });
  });
}
