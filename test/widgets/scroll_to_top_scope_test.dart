// 底部分頁根部的 ScrollToTopScope：收到訊號時子樹裡的垂直捲動都回到最上面，
// 包含 IndexedStack 裡沒顯示的那塊與自帶 controller 的捲動；橫向捲動與各頁
// State（例如選中的分類）不受影響。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/widgets/scroll_to_top_scope.dart';

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// 模擬「分頁內有分類 chip」：選中的分類存在 State 裡，回頂端後不該被重設。
class _CategoryList extends StatefulWidget {
  final ScrollController? controller;

  const _CategoryList({super.key, this.controller});

  @override
  State<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<_CategoryList> {
  int category = 0;

  @override
  Widget build(BuildContext context) => ListView(
    controller: widget.controller,
    children: [
      SizedBox(
        height: 40,
        child: ListView(
          key: const Key('chips'),
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < 20; i++)
              SizedBox(width: 80, child: Text('分類$i')),
          ],
        ),
      ),
      for (var i = 0; i < 50; i++) SizedBox(height: 60, child: Text('項目$i')),
    ],
  );
}

void main() {
  late _Signal signal;
  late ScrollController ownController;

  setUp(() {
    signal = _Signal();
    ownController = ScrollController();
  });

  tearDown(() {
    signal.dispose();
    ownController.dispose();
  });

  Future<void> pumpScope(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ScrollToTopScope(
        signal: signal,
        child: IndexedStack(
          sizing: StackFit.expand,
          children: [
            // 第一塊沒有 controller，第二塊（不顯示）自帶 controller。
            const _CategoryList(key: Key('shown')),
            _CategoryList(key: const Key('hidden'), controller: ownController),
          ],
        ),
      ),
    ),
  );

  ScrollPosition positionOf(WidgetTester tester, String key) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(Key(key), skipOffstage: false),
              matching: find.byType(Scrollable, skipOffstage: false),
              skipOffstage: false,
            )
            .first,
      )
      .position;

  testWidgets('收到訊號時顯示與沒顯示的垂直捲動都跳回最上面', (tester) async {
    await pumpScope(tester);
    positionOf(tester, 'shown').jumpTo(500);
    ownController.jumpTo(800);
    await tester.pump();

    signal.fire();
    await tester.pump();

    expect(positionOf(tester, 'shown').pixels, 0);
    expect(ownController.offset, 0);
  });

  testWidgets('沒收到訊號時捲動位置保留（外層重建也不動）', (tester) async {
    await pumpScope(tester);
    positionOf(tester, 'shown').jumpTo(500);
    ownController.jumpTo(800);
    await tester.pump();

    await pumpScope(tester);

    expect(positionOf(tester, 'shown').pixels, 500);
    expect(ownController.offset, 800);
  });

  testWidgets('回頂端不動橫向捲動，也不重設分頁 State', (tester) async {
    await pumpScope(tester);
    final shown = find.byKey(const Key('shown'));
    tester.state<_CategoryListState>(shown).category = 3;
    final chips = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('chips')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    chips.jumpTo(200);
    // 捲太遠 chip 列會被 ListView 回收，這裡只捲到還在快取範圍內的距離。
    positionOf(tester, 'shown').jumpTo(200);
    await tester.pump();

    signal.fire();
    await tester.pump();

    expect(positionOf(tester, 'shown').pixels, 0);
    expect(chips.pixels, 200);
    expect(tester.state<_CategoryListState>(shown).category, 3);
  });
}
