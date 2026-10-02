// 膠囊分頁的左右大滑切換：只有水平為主、距離過門檻的拖曳才切到隔壁段，
// 短拖、輕甩、縱向捲動、滑鼠拖曳、內層橫向清單上的滑動都不切，兩端不越界。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/widgets/swipe_segment_switcher.dart';

class _Harness {
  final changes = <int>[];
  final progresses = <double>[];

  Widget build({int index = 0, int count = 3}) => MaterialApp(
    home: Scaffold(
      body: SwipeSegmentSwitcher(
        index: index,
        count: count,
        onChanged: changes.add,
        onDragProgress: progresses.add,
        child: ListView(
          key: const Key('list'),
          children: [
            SizedBox(
              height: 60,
              child: ListView(
                key: const Key('chips'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(width: 80, child: Text('分類$i')),
                ],
              ),
            ),
            for (var i = 0; i < 50; i++)
              SizedBox(height: 60, child: Text('項目$i')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // 預設測試畫面寬 800，門檻 = 800 × 0.4 = 320。
  final content = find.text('項目3');

  testWidgets('往左滑過門檻切到右邊一段，往右滑過門檻切到左邊一段', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build(index: 1));
    await tester.drag(content, const Offset(-340, 0));
    await tester.pumpAndSettle();
    await tester.drag(content, const Offset(340, 0));
    await tester.pumpAndSettle();
    expect(h.changes, [2, 0]);
  });

  testWidgets('略斜（約 13°）的大滑照樣切到隔壁段', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final gesture = await tester.startGesture(tester.getCenter(content));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(-340, -80) / 20);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.changes, [1]);
  });

  testWidgets('距離不到門檻不切', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.drag(content, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('短距離快速輕甩不切', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.fling(content, const Offset(-150, 0), 3000);
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('第一段往右、最後一段往左都不動作', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build(index: 0));
    await tester.drag(content, const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(h.build(index: 2));
    await tester.drag(content, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
    expect(h.progresses.where((p) => p != 0), isEmpty);
  });

  testWidgets('斜向但垂直位移過大不切', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.drag(content, const Offset(-340, -200));
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('以上下為主的拖曳照常捲清單', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final before = tester.getTopLeft(content).dy;
    await tester.drag(content, const Offset(-30, -300));
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
    expect(tester.getTopLeft(content).dy, lessThan(before - 200));
  });

  testWidgets('約 30°～37° 的斜滑照常捲清單，不被切換手勢吃掉', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    for (final delta in const [Offset(-200, -120), Offset(-200, -150)]) {
      final before = tester.getTopLeft(content).dy;
      // 分 20 步移動，像真實手指一樣陸續送 move 事件。
      final gesture = await tester.startGesture(tester.getCenter(content));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(delta / 20);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(content).dy, lessThan(before - 60));
    }
    expect(h.changes, isEmpty);
  });

  testWidgets('在內層橫向清單上滑動，動的是清單不切分頁', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final before = tester.getTopLeft(find.text('分類7')).dx;
    await tester.drag(find.text('分類2'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
    expect(tester.getTopLeft(find.text('分類7')).dx, lessThan(before - 300));
  });

  testWidgets('滑鼠拖曳不觸發', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.drag(
      content,
      const Offset(-400, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('滑動中回報進度、到門檻為 1，不到門檻放開後彈回 0', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final gesture = await tester.startGesture(tester.getCenter(content));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(h.progresses.last, closeTo(0.5, 0.01));
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(h.progresses.last, 1);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
    expect(h.progresses.last, 0);
    expect(tester.getTopLeft(find.byKey(const Key('list'))).dx, 0);
  });
}
