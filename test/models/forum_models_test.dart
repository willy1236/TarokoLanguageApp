import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';

Map<String, dynamic> _postJson() => {
      // pg driver 會把 BIGINT 以字串回傳，這裡刻意用字串。
      'id': '1024',
      'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
      'title': '關於 mhuway',
      'body': '內文',
      'like_count': 3,
      'comment_count': 5,
      'is_pinned': false,
      'is_liked': true,
      'images': ['https://storage.googleapis.com/truku-media/forum/a.jpg'],
      'tags': [
        {'name': '族語', 'slug': 'yuyan'},
      ],
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
      'author': {'uid': 7, 'display_name': 'Sayun', 'avatar_url': null},
    };

void main() {
  group('ForumPost.fromJson', () {
    test('解析完整欄位，id 為字串也能解析', () {
      final post = ForumPost.fromJson(_postJson());

      expect(post.id, 1024);
      expect(post.board.slug, 'culture');
      expect(post.board.name, '文化傳承');
      expect(post.title, '關於 mhuway');
      expect(post.likeCount, 3);
      expect(post.commentCount, 5);
      expect(post.isLiked, isTrue);
      expect(post.isPinned, isFalse);
      expect(post.images, hasLength(1));
      expect(post.tags.single.name, '族語');
      expect(post.author.displayName, 'Sayun');
    });

    test('images / tags 缺失視為空陣列，is_bookmarked 缺失視為 false', () {
      final json = _postJson()
        ..remove('images')
        ..remove('tags');

      final post = ForumPost.fromJson(json);

      expect(post.images, isEmpty);
      expect(post.tags, isEmpty);
      // 後端補上書籤端點前不會有這個欄位（規格 §9）。
      expect(post.isBookmarked, isFalse);
    });

    test('作者顯示名為 null 時退回匿名使用者', () {
      final json = _postJson()
        ..['author'] = {'uid': 9, 'display_name': null, 'avatar_url': null};

      expect(ForumPost.fromJson(json).author.displayName, '匿名使用者');
    });
  });

  group('ForumPost 樂觀更新', () {
    test('toggledLike 由未按讚變成已按讚並 +1', () {
      final post = ForumPost.fromJson(_postJson()..['is_liked'] = false);

      final toggled = post.toggledLike();

      expect(toggled.isLiked, isTrue);
      expect(toggled.likeCount, 4);
    });

    test('toggledLike 由已按讚變回未按讚並 -1，不會低於 0', () {
      final post = ForumPost.fromJson(
        _postJson()
          ..['is_liked'] = true
          ..['like_count'] = 0,
      );

      final toggled = post.toggledLike();

      expect(toggled.isLiked, isFalse);
      expect(toggled.likeCount, 0);
    });

    test('toggledBookmark 只改書籤狀態', () {
      final post = ForumPost.fromJson(_postJson());

      final toggled = post.toggledBookmark();

      expect(toggled.isBookmarked, isTrue);
      expect(toggled.likeCount, post.likeCount);
    });
  });

  group('ForumComment.fromJson', () {
    test('第一層留言的 parentCommentId 為 null', () {
      final comment = ForumComment.fromJson({
        'id': '5',
        'post_id': '1024',
        'parent_comment_id': null,
        'body': '推',
        'like_count': 0,
        'is_liked': false,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
      });

      expect(comment.id, 5);
      expect(comment.postId, 1024);
      expect(comment.parentCommentId, isNull);
      expect(comment.body, '推');
    });
  });

  group('ForumPostPage.fromJson', () {
    test('置頂與一般貼文分開，next_cursor 為 null 時代表沒有下一頁', () {
      final page = ForumPostPage.fromJson({
        'pinned': [_postJson()..['is_pinned'] = true],
        'posts': [_postJson()],
        'next_cursor': null,
      });

      expect(page.pinned.single.isPinned, isTrue);
      expect(page.posts, hasLength(1));
      expect(page.nextCursor, isNull);
    });
  });

  group('ForumNotificationPage.fromJson', () {
    test('解析通知與未讀數', () {
      final page = ForumNotificationPage.fromJson({
        'notifications': [
          {
            'id': 3,
            'type': 'reply_post',
            'post_id': '1024',
            'comment_id': '5',
            'post_title': '關於 mhuway',
            'is_read': false,
            'created_at': '2026-08-01T11:00:00.000Z',
            'actor': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
          },
        ],
        'unread_count': 1,
        'next_cursor': 3,
      });

      expect(page.items.single.type, 'reply_post');
      expect(page.items.single.postId, 1024);
      expect(page.items.single.isRead, isFalse);
      expect(page.unreadCount, 1);
      expect(page.nextCursor, 3);
    });
  });
}
