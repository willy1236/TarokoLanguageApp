import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_post_card.dart';

ForumPost buildPost({
  String title = '關於 mhuway',
  int likeCount = 3,
  int commentCount = 5,
  bool isPinned = false,
  bool isLiked = false,
  List<ForumTag> tags = const [],
  List<String> images = const [],
}) => ForumPost(
  id: 1,
  board: const ForumBoard(id: 2, slug: 'culture', name: '文化傳承'),
  title: title,
  body: '內文',
  likeCount: likeCount,
  commentCount: commentCount,
  isPinned: isPinned,
  isLiked: isLiked,
  isBookmarked: false,
  images: images,
  tags: tags,
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  updatedAt: DateTime.now(),
  author: const ForumAuthor(uid: 7, displayName: 'Sayun'),
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('顯示標題、作者、看板名與計數', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(),
          onTap: () {},
          onLike: () {},
          onBookmark: () {},
        ),
      ),
    );

    expect(find.text('關於 mhuway'), findsOneWidget);
    expect(find.text('Sayun'), findsOneWidget);
    expect(find.textContaining('文化傳承'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('置頂貼文顯示置頂標記，非置頂不顯示', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(isPinned: true),
          onTap: () {},
          onLike: () {},
          onBookmark: () {},
        ),
      ),
    );
    expect(find.text('置頂'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(),
          onTap: () {},
          onLike: () {},
          onBookmark: () {},
        ),
      ),
    );
    expect(find.text('置頂'), findsNothing);
  });

  testWidgets('標籤以 # 前綴顯示，沒有標籤時不佔位', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(
            tags: const [ForumTag(name: '族語', slug: 'yuyan')],
          ),
          onTap: () {},
          onLike: () {},
          onBookmark: () {},
        ),
      ),
    );

    expect(find.text('#族語'), findsOneWidget);
  });

  testWidgets('點卡片觸發 onTap、點讚觸發 onLike', (tester) async {
    var tapped = 0;
    var liked = 0;
    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(),
          onTap: () => tapped++,
          onLike: () => liked++,
          onBookmark: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump();
    expect(liked, 1);

    await tester.tap(find.text('關於 mhuway'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('已按讚時顯示實心愛心', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumPostCard(
          post: buildPost(isLiked: true),
          onTap: () {},
          onLike: () {},
          onBookmark: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
