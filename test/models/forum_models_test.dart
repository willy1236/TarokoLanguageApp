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
  });

  group('ForumComment 已刪除佔位', () {
    test('is_deleted 為 true 時 body 與 author 皆為 null，仍能解析', () {
      final comment = ForumComment.fromJson({
        'id': 108,
        'post_id': 42,
        'parent_comment_id': null,
        'body': null,
        'is_deleted': true,
        'like_count': 0,
        'is_liked': false,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': null,
      });

      expect(comment.id, 108);
      expect(comment.isDeleted, isTrue);
      expect(comment.body, '');
      expect(comment.author, isNull);
    });

    test('asDeletedPlaceholder 清掉內容與作者但保留 id 與層級', () {
      final comment = ForumComment.fromJson({
        'id': 5,
        'post_id': 42,
        'parent_comment_id': null,
        'body': '推',
        'like_count': 9,
        'is_liked': true,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
      });

      final placeholder = comment.asDeletedPlaceholder();

      expect(placeholder.id, 5);
      expect(placeholder.parentCommentId, isNull);
      expect(placeholder.isDeleted, isTrue);
      expect(placeholder.body, '');
      expect(placeholder.author, isNull);
      expect(placeholder.likeCount, 0);
    });
  });

  group('ForumPostPage.fromJson', () {
    test('置頂與一般貼文分開，has_more 為 false 時代表沒有下一頁', () {
      final page = ForumPostPage.fromJson({
        'pinned': [_postJson()..['is_pinned'] = true],
        'posts': [_postJson()],
        'page_info': {'next_cursor': null, 'has_more': false},
      });

      expect(page.pinned.single.isPinned, isTrue);
      expect(page.posts, hasLength(1));
      expect(page.pageInfo.hasMore, isFalse);
    });
  });

  group('groupComments', () {
    ForumComment comment(int id, {int? parent}) => ForumComment(
      id: id,
      postId: 1024,
      parentCommentId: parent,
      body: 'c$id',
      likeCount: 0,
      isLiked: false,
      isDeleted: false,
      createdAt: DateTime.parse('2026-08-01T11:00:00.000Z'),
      author: const ForumAuthor(displayName: 'A'),
    );

    test('回覆掛到所屬的第一層留言底下', () {
      final threads = groupComments(
        [comment(1), comment(2)],
        [comment(3, parent: 1), comment(4, parent: 1), comment(5, parent: 2)],
      );

      expect(threads.map((t) => t.root.id), [1, 2]);
      expect(threads[0].replies.map((r) => r.id), [3, 4]);
      expect(threads[1].replies.map((r) => r.id), [5]);
    });

    test('沒有回覆的留言 replies 為空', () {
      expect(groupComments([comment(1)], []).single.replies, isEmpty);
    });

    test('孤兒回覆（parent 不在本頁）被丟棄而非造成崩潰', () {
      final threads = groupComments([comment(1)], [comment(9, parent: 99)]);

      expect(threads, hasLength(1));
      expect(threads.single.replies, isEmpty);
    });

    test('保持 comments 傳入的順序，不重新排序', () {
      final threads = groupComments([comment(5), comment(2)], []);

      expect(threads.map((t) => t.root.id), [5, 2]);
    });
  });
}
