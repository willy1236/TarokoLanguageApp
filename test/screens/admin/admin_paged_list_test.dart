// AdminPagedListController：就地換一筆、條件變了丟掉晚回來的舊回應、已處理的錯誤不顯示。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/page_info.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_paged_list.dart';
import 'package:flutter_application_1/services/admin_service.dart';

AdminPage<String> _page(List<String> items, [String? next]) =>
    (items: items, pageInfo: PageInfo(nextCursor: next));

void main() {
  test('replace 只換符合的那一筆，不重抓', () async {
    var calls = 0;
    final c = AdminPagedListController<String>(
      fetch: (_) async {
        calls++;
        return _page(['a', 'b']);
      },
    );
    await c.reload();
    var notified = 0;
    c.addListener(() => notified++);

    expect(c.replace((s) => s == 'b', 'B'), isTrue);
    expect(c.items, ['a', 'B']);
    expect(c.replace((s) => s == 'z', 'Z'), isFalse);
    expect(calls, 1);
    expect(notified, 1);
  });

  test('reset 後晚回來的舊回應丟掉', () async {
    final first = Completer<AdminPage<String>>();
    var filter = 'old';
    final c = AdminPagedListController<String>(
      fetch: (_) => filter == 'old' ? first.future : Future.value(_page(['新'])),
    );
    final pending = c.reload();
    filter = 'new';
    await c.reset();
    first.complete(_page(['舊']));
    await pending;
    expect(c.items, ['新']);
  });

  test('onError 回 true 時不記錯誤；回 false 時記下', () async {
    var handled = true;
    final c = AdminPagedListController<String>(
      fetch: (_) async => throw Exception('x'),
      onError: (_) => handled,
    );
    await c.reload();
    expect(c.error, isNull);
    handled = false;
    await c.reload();
    expect(c.error, isNotNull);
    expect(c.loading, isFalse);
  });

  test('下一頁失敗後不自動重打，retryLoadMore 才重送', () async {
    var fail = true;
    final cursors = <String?>[];
    final c = AdminPagedListController<String>(
      fetch: (cursor) async {
        cursors.add(cursor);
        if (cursor != null && fail) throw Exception('x');
        return cursor == null ? _page(['a'], 'p2') : _page(['b']);
      },
    );
    await c.reload();
    await c.loadMore();
    expect(c.loadMoreFailed, isTrue);
    await c.loadMore();
    expect(cursors, [null, 'p2'], reason: '失敗後捲動不再重打');

    fail = false;
    c.retryLoadMore();
    await pumpEventQueue();
    expect(c.items, ['a', 'b']);
    expect(c.hasMore, isFalse);
  });
}
