// CursorPager：重整後丟棄舊世代的下一頁、去重、翻頁失敗等重試、沒有下一頁就不再請求。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/page_info.dart';
import 'package:flutter_application_1/shared/utils/cursor_pager.dart';

typedef _Page = (List<int>, PageInfo);

/// 每次 fetch 都記下游標，回傳一個由測試決定何時完成的 Completer。
class _FakeSource {
  final requests = <(String?, Completer<_Page>)>[];

  Future<_Page> fetch(String? cursor) {
    final completer = Completer<_Page>();
    requests.add((cursor, completer));
    return completer.future;
  }

  List<String?> get cursors => [for (final (c, _) in requests) c];

  void reply(int index, List<int> items, [String? next]) =>
      requests[index].$2.complete((items, PageInfo(nextCursor: next)));

  void fail(int index) => requests[index].$2.completeError(Exception('斷線'));
}

void main() {
  late _FakeSource source;
  late CursorPager<int> pager;

  setUp(() {
    source = _FakeSource();
    pager = CursorPager<int>(fetch: source.fetch, idOf: (i) => i);
  });

  tearDown(() => pager.dispose());

  /// 載好第一頁 [1, 2, 3]，還有下一頁 c1。
  Future<void> loadFirstPage() async {
    final done = pager.refresh();
    source.reply(0, [1, 2, 3], 'c1');
    await done;
  }

  test('第一頁載好後帶 next_cursor 抓下一頁並接在後面', () async {
    await loadFirstPage();
    expect(pager.items, [1, 2, 3]);
    expect(pager.hasMore, isTrue);

    final more = pager.loadMore();
    expect(pager.loadingMore, isTrue);
    source.reply(1, [4, 5]);
    await more;

    expect(source.cursors, [null, 'c1']);
    expect(pager.items, [1, 2, 3, 4, 5]);
    expect(pager.loadingMore, isFalse);
    expect(pager.hasMore, isFalse);
  });

  test('翻頁還在路上時重整：晚回來的舊頁被丟棄，重整後能繼續翻頁', () async {
    await loadFirstPage();
    final staleMore = pager.loadMore();

    final refreshed = pager.refresh();
    // 重整一開始就清掉翻頁旗標，不必等舊請求回來。
    expect(pager.loadingMore, isFalse);
    source.reply(2, [10, 11], 'c2');
    await refreshed;

    source.reply(1, [4, 5], 'old');
    await staleMore;
    expect(pager.items, [10, 11]);
    expect(pager.loadingMore, isFalse);

    final more = pager.loadMore();
    source.reply(3, [12]);
    await more;
    expect(source.cursors.last, 'c2');
    expect(pager.items, [10, 11, 12]);
  });

  test('兩次重整重疊：只採用最後一次的結果', () async {
    final first = pager.refresh();
    final second = pager.refresh();
    source.reply(1, [7], 'new');
    await second;
    source.reply(0, [1], 'old');
    await first;

    expect(pager.items, [7]);
    expect(pager.loading, isFalse);
  });

  test('兩頁之間有重複項目時只留先出現的那份', () async {
    await loadFirstPage();
    final more = pager.loadMore();
    source.reply(1, [3, 4, 3]);
    await more;
    expect(pager.items, [1, 2, 3, 4]);
  });

  test('翻頁失敗：不再自動重打，按重試後才重新請求同一個游標', () async {
    await loadFirstPage();
    final failed = pager.loadMore();
    source.fail(1);
    await failed;

    expect(pager.loadMoreFailed, isTrue);
    expect(pager.loadingMore, isFalse);
    expect(pager.items, [1, 2, 3]);

    await pager.loadMore();
    expect(source.requests, hasLength(2));

    pager.retryLoadMore();
    expect(pager.loadMoreFailed, isFalse);
    expect(source.cursors, [null, 'c1', 'c1']);
    source.reply(2, [4]);
    await pumpEventQueue();
    expect(pager.items, [1, 2, 3, 4]);
  });

  test('第一頁還在抓、或沒有下一頁時，loadMore 不送請求', () async {
    final done = pager.refresh();
    // 第一頁還在抓
    await pager.loadMore();
    source.reply(0, [1]);
    await done;
    expect(pager.hasMore, isFalse);

    await pager.loadMore();
    expect(source.requests, hasLength(1));
  });

  test('翻頁進行中重複呼叫 loadMore 只送一次', () async {
    await loadFirstPage();
    pager.loadMore();
    pager.loadMore();
    expect(source.requests, hasLength(2));
  });

  test('第一頁失敗時記下錯誤，重整成功後清掉', () async {
    final failed = pager.refresh();
    source.fail(0);
    await failed;
    expect(pager.error, isNotNull);
    expect(pager.loading, isFalse);

    final ok = pager.refresh();
    expect(pager.error, isNull);
    source.reply(1, [1]);
    await ok;
    expect(pager.items, [1]);
  });

  test('removeWhere 就地移除並通知畫面', () async {
    await loadFirstPage();
    var notified = 0;
    pager.addListener(() => notified++);

    pager.removeWhere((i) => i == 2);

    expect(pager.items, [1, 3]);
    expect(notified, 1);
  });

  test('dispose 後請求才回來不會丟錯', () async {
    final done = pager.refresh();
    pager.dispose();
    source.reply(0, [1]);
    await done;
    // tearDown 再 dispose 一次會丟錯，換一個新的給它。
    pager = CursorPager<int>(fetch: source.fetch, idOf: (i) => i);
  });
}
