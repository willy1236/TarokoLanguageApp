import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/event_model.dart';

Map<String, dynamic> _detail(Object? images) => {
  'id': 7,
  'title': '豐年祭',
  'starts_at': '2026-11-20T02:30:00Z',
  'images': ?images,
};

void main() {
  group('EventImage.listFromJson', () {
    test('依後端順序解析，字串型 id 也接受', () {
      final images = EventImage.listFromJson([
        {'id': 12, 'url': 'https://a/1.jpg'},
        {'id': '13', 'url': 'https://a/2.jpg'},
      ]);
      expect(images.map((i) => i.id), [12, 13]);
      expect(images.map((i) => i.url), ['https://a/1.jpg', 'https://a/2.jpg']);
    });

    test('缺 id 或 url、型別不對的項目略過，不是陣列時為空清單', () {
      expect(EventImage.listFromJson(null), isEmpty);
      expect(EventImage.listFromJson({'id': 1}), isEmpty);
      final images = EventImage.listFromJson([
        {'id': 1},
        {'url': 'https://a/x.jpg'},
        {'id': 2, 'url': null},
        'oops',
        {'id': 3, 'url': 'https://a/3.jpg'},
      ]);
      expect(images.map((i) => i.id), [3]);
    });
  });

  group('EventDetail 圖片', () {
    test('沒有 images 欄位時為空清單、沒有封面', () {
      final e = EventDetail.fromJson(_detail(null));
      expect(e.images, isEmpty);
      expect(e.coverImageUrl, isNull);
    });

    test('封面是第一張', () {
      final e = EventDetail.fromJson(
        _detail([
          {'id': 1, 'url': 'https://a/1.jpg'},
          {'id': 2, 'url': 'https://a/2.jpg'},
        ]),
      );
      expect(e.coverImageUrl, 'https://a/1.jpg');
    });

    test('withImages 換掉圖片，其他欄位不變', () {
      final e = EventDetail.fromJson({
        ..._detail(const []),
        'is_liked': true,
        'like_count': 3,
      });
      final updated = e.withImages(const [EventImage(id: 9, url: 'u')]);
      expect(updated.images.single.id, 9);
      expect(updated.title, '豐年祭');
      expect(updated.isLiked, isTrue);
      expect(updated.likeCount, 3);
    });
  });

  test('EventSummary 解析 cover_image_url，沒有時為 null', () {
    final base = {
      'id': '44',
      'title': 't',
      'starts_at': '2026-11-20T02:30:00Z',
    };
    expect(EventSummary.fromJson(base).coverImageUrl, isNull);
    expect(
      EventSummary.fromJson({
        ...base,
        'cover_image_url': 'https://a/c.jpg',
      }).coverImageUrl,
      'https://a/c.jpg',
    );
  });
}
