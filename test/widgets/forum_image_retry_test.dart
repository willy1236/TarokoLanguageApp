// 貼文詳情頁「圖片簽章網址過期就自動重取」的次數守門測試。
//
// 背景：web 版上 GCS 桶沒設 CORS，貼文圖一律載入失敗。原本的保護是壞的——
// ForumImageGrid 的 errorWidget 每次 rebuild 都排一次回報，而 _load() 開頭又把
// 擋住自己的 _imageAutoRefreshed 旗標清掉，於是變成無節流迴圈，每輪兩支 API，
// 一路打到後端全域限流回 429。
//
// 這支測試就是那個警報：圖片永遠載不起來時，貼文 API 最多只能被打兩次
// （進頁 1 次 + 自動重試 1 次）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_image_grid.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, Object?> _postJson() => {
  'post': {
    'id': 1,
    'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
    'title': '關於 mhuway',
    'body': '內文',
    'like_count': 0,
    'comment_count': 0,
    'is_pinned': false,
    'is_liked': false,
    'is_bookmarked': false,
    // 測試環境沒有網路，這個網址一定載入失敗，等同「簽章過期」的情境。
    'images': ['https://example.invalid/expired.jpg'],
    'tags': <Object?>[],
    'created_at': '2026-09-01T00:00:00Z',
    'updated_at': '2026-09-01T00:00:00Z',
    'author': {'uid': 7, 'display_name': 'Sayun'},
  },
};

void main() {
  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  testWidgets('圖片一直載不起來時，貼文 API 最多被打兩次', (tester) async {
    var postCalls = 0;
    installMockClient(
      {
        '/api/forum/posts/1': _postJson(),
        '/api/forum/posts/1/comments': {
          'comments': <Object?>[],
          'replies': <Object?>[],
        },
        '/api/shop/items': {'items': <Object?>[]},
      },
      onRequest: (request) {
        if (request.url.path == '/api/forum/posts/1') postCalls++;
      },
    );

    await tester.pumpWidget(wrapScreen(const ForumDetailScreen(postId: 1)));
    await tester.pumpAndSettle();
    expect(postCalls, 1, reason: '進頁應該只打一次');

    // 直接驅動 ForumImageGrid 回報過期的接縫。真的讓 CachedNetworkImage 在測試
    // 環境失敗是驅動不出來的（沒有網路也沒有 cache manager 外掛，它不會進
    // errorWidget），所以這裡模擬「每張圖每次 rebuild 都回報一次」的最壞情況。
    final grid = tester.widget<ForumImageGrid>(find.byType(ForumImageGrid));
    for (var i = 0; i < 10; i++) {
      grid.onImageExpired!();
      await tester.pumpAndSettle();
    }

    expect(
      postCalls,
      lessThanOrEqualTo(2),
      reason: '重打 $postCalls 次貼文 API——自動重試的次數上限失效了，實機會打到 429',
    );
  });
}
