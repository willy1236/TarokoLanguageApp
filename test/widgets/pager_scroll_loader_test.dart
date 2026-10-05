// PagerScrollLoader：清單已在底部、不會再有捲動事件時，也會自己接著翻頁；
// 翻頁失敗或沒有下一頁時不自動重打。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/page_info.dart';
import 'package:flutter_application_1/shared/utils/cursor_pager.dart';
import 'package:flutter_application_1/shared/utils/pager_scroll_loader.dart';

typedef _Page = (List<int>, PageInfo);

class _Harness extends StatefulWidget {
  final CursorPager<int> pager;
  const _Harness({required this.pager});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _controller = ScrollController();
  late final PagerScrollLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = PagerScrollLoader(controller: _controller, pager: widget.pager);
    widget.pager.refresh();
  }

  @override
  void dispose() {
    _loader.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ListenableBuilder(
        listenable: widget.pager,
        builder: (context, _) {
          if (widget.pager.loading) return const SizedBox.shrink();
          final items = widget.pager.items;
          return ListView.builder(
            controller: _controller,
            itemCount: items.length,
            itemBuilder: (_, i) =>
                SizedBox(height: 100, child: Text('項目 ${items[i]}')),
          );
        },
      ),
    );
  }
}

void main() {
  late List<String?> cursors;

  CursorPager<int> pagerOf(Future<_Page> Function(String? cursor) fetch) {
    return CursorPager<int>(
      fetch: (cursor) {
        cursors.add(cursor);
        return fetch(cursor);
      },
      idOf: (i) => i,
    );
  }

  setUp(() => cursors = []);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('第一頁填不滿畫面：不用捲動就接著抓下一頁', (tester) async {
    final pager = pagerOf(
      (cursor) async => cursor == null
          ? ([1, 2], const PageInfo(nextCursor: 'c1'))
          : ([3, 4], PageInfo.end),
    );
    addTearDown(pager.dispose);

    await tester.pumpWidget(_Harness(pager: pager));
    await settle(tester);

    expect(cursors, [null, 'c1']);
    expect(find.text('項目 4'), findsOneWidget);
  });

  testWidgets('捲到底後下一頁整頁重複：不用再捲動就繼續翻到有新項目', (tester) async {
    // 下一頁等捲動停下才回來，之後就沒有捲動事件可以觸發翻頁。
    final duplicatePage = Completer<void>();
    final pager = pagerOf((cursor) async {
      switch (cursor) {
        case null:
          return (
            [for (var i = 1; i <= 20; i++) i],
            const PageInfo(nextCursor: 'c1'),
          );
        case 'c1':
          await duplicatePage.future;
          // 翻頁期間有新資料插入，這頁全是已載入過的
          return (
            [for (var i = 11; i <= 20; i++) i],
            const PageInfo(nextCursor: 'c2'),
          );
        default:
          return ([21, 22], PageInfo.end);
      }
    });
    addTearDown(pager.dispose);

    await tester.pumpWidget(_Harness(pager: pager));
    await settle(tester);
    expect(cursors, [null]);

    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await tester.pumpAndSettle();
    expect(cursors, [null, 'c1']);

    duplicatePage.complete();
    await settle(tester);

    expect(cursors, [null, 'c1', 'c2']);
    expect(pager.items.last, 22);
    expect(pager.hasMore, isFalse);
  });

  testWidgets('翻頁失敗：停在底部也不會自動重打', (tester) async {
    final pager = pagerOf(
      (cursor) async => cursor == null
          ? ([1, 2], const PageInfo(nextCursor: 'c1'))
          : throw Exception('斷線'),
    );
    addTearDown(pager.dispose);

    await tester.pumpWidget(_Harness(pager: pager));
    await settle(tester);
    await settle(tester);

    expect(cursors, [null, 'c1']);
    expect(pager.loadMoreFailed, isTrue);
  });
}
