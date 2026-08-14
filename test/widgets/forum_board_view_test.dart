import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/forum_board_view.dart';

ForumPost post(int id, {int likeCount = 0, bool isLiked = false}) => ForumPost(
      id: id,
      board: const ForumBoard(id: 2, slug: 'culture', name: '文化傳承'),
      title: '標題 $id',
      body: '內文',
      likeCount: likeCount,
      commentCount: 0,
      isPinned: false,
      isLiked: isLiked,
      isBookmarked: false,
      images: const [],
      tags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      author: const ForumAuthor(uid: 7, displayName: 'Sayun'),
    );

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 800, child: child)));

void main() {
  testWidgets('沒有貼文時顯示空狀態', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async =>
          const ForumPostPage(pinned: [], posts: [], nextCursor: null),
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('這個看板還沒有貼文'), findsOneWidget);
  });

  testWidgets('置頂貼文排在一般貼文之前', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: [post(99)],
        posts: [post(1)],
        nextCursor: null,
      ),
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.textContaining('標題'))
        .map((t) => t.data)
        .toList();
    expect(titles.first, '標題 99');
  });

  testWidgets('載入失敗時顯示重試，按下重試會重新載入', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async {
        calls++;
        if (calls == 1) {
          throw ApiException(
            statusCode: 0,
            code: 'NETWORK_ERROR',
            message: '無法連線到伺服器，請檢查網路',
          );
        }
        return ForumPostPage(pinned: const [], posts: [post(1)], nextCursor: null);
      },
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('無法連線到伺服器，請檢查網路'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('標題 1'), findsOneWidget);
    expect(calls, 2);
  });

  // 這兩個按讚測試沒有用 brief 原稿裡「直接 async 回傳值」的寫法：那種
  // callback 在沒有真正 I/O 的情況下會於下一個 microtask 就完成，早於
  // tester.pump() 建出的那一影格，導致樂觀更新與後端校正的兩次 setState
  // 在同一次 pump 就一起套用，看不到中間的樂觀影格。改用 Completer 手動
  // 控制何時讓 toggleLike 完成，才能確實斷言「先樂觀、後校正/回滾」。
  testWidgets('按讚先樂觀更新，成功後以後端計數校正', (tester) async {
    final completer = Completer<({bool liked, int likeCount})>();
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: const [],
        posts: [post(1, likeCount: 3)],
        nextCursor: null,
      ),
      // 後端回的計數刻意與樂觀值不同，驗證前端有採用後端的值。
      toggleLike: (_, {required like}) => completer.future,
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump(); // 樂觀更新後、後端回應前
    expect(find.text('4'), findsOneWidget);

    completer.complete((liked: true, likeCount: 10));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('按讚失敗時回滾到原本狀態', (tester) async {
    final completer = Completer<({bool liked, int likeCount})>();
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: const [],
        posts: [post(1, likeCount: 3)],
        nextCursor: null,
      ),
      toggleLike: (_, {required like}) => completer.future,
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);

    completer.completeError(ApiException(
      statusCode: 500,
      code: 'UNKNOWN',
      message: '發生未知錯誤',
    ));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('捲到底時以 cursor 載入下一頁', (tester) async {
    final seenCursors = <int?>[];
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async {
        seenCursors.add(cursor);
        if (cursor == null) {
          return ForumPostPage(
            pinned: const [],
            posts: [for (var i = 20; i > 0; i--) post(i)],
            nextCursor: 1,
          );
        }
        return ForumPostPage(
          pinned: const [],
          posts: [post(0)],
          nextCursor: null,
        );
      },
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(seenCursors, [null, 1]);
    expect(find.text('標題 0'), findsOneWidget);
  });
}
