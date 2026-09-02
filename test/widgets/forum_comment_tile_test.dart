import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_comment_tile.dart';

ForumComment comment({
  int likeCount = 0,
  bool isLiked = false,
  bool isDeleted = false,
}) => ForumComment(
  id: 5,
  postId: 1,
  parentCommentId: null,
  body: '推一個',
  likeCount: likeCount,
  isLiked: isLiked,
  isDeleted: isDeleted,
  createdAt: DateTime.now(),
  author: const ForumAuthor(uid: 7, displayName: 'Pisaw'),
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('顯示作者、內容與讚數', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(likeCount: 2),
          isReply: false,
          isMine: false,
          onLike: () {},
          onReply: () {},
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );

    expect(find.text('Pisaw'), findsOneWidget);
    expect(find.text('推一個'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('自己的留言顯示刪除、別人的顯示檢舉', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(),
          isReply: false,
          isMine: true,
          onLike: () {},
          onReply: () {},
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );
    expect(find.text('刪除'), findsOneWidget);
    expect(find.text('檢舉'), findsNothing);

    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(),
          isReply: false,
          isMine: false,
          onLike: () {},
          onReply: () {},
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );
    expect(find.text('檢舉'), findsOneWidget);
    expect(find.text('刪除'), findsNothing);
  });

  testWidgets('第二層回覆有縮排，第一層沒有', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(),
          isReply: true,
          isMine: false,
          onLike: () {},
          onReply: () {},
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('forum-comment-indent')),
    );
    expect((padding.padding as EdgeInsets).left, greaterThan(0));
  });

  testWidgets('點回覆觸發 onReply', (tester) async {
    var replied = 0;
    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(),
          isReply: false,
          isMine: false,
          onLike: () {},
          onReply: () => replied++,
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );

    await tester.tap(find.text('回覆'));
    await tester.pump();

    expect(replied, 1);
  });

  testWidgets('已刪除的留言只顯示佔位文字，不給任何操作按鈕', (tester) async {
    await tester.pumpWidget(
      wrap(
        ForumCommentTile(
          comment: comment(isDeleted: true),
          isReply: false,
          isMine: false,
          onLike: () {},
          onReply: () {},
          onDelete: () {},
          onReport: () {},
        ),
      ),
    );

    expect(find.text('此留言已刪除'), findsOneWidget);
    // 對已刪除的留言操作後端一律回 404，所以不該有任何入口。
    expect(find.text('回覆'), findsNothing);
    expect(find.text('檢舉'), findsNothing);
    expect(find.text('刪除'), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    // 作者身分不外洩。
    expect(find.text('Pisaw'), findsNothing);
  });
}
