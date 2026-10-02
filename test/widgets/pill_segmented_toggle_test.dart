// 膠囊選中色塊依 dragProgress 預移：位置 = index + dragProgress，兩端夾住不往外移。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/widgets/pill_segmented_toggle.dart';

Widget _toggle({required int index, double dragProgress = 0}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 308, // 扣掉左右各 4 的內距後每段 100 寬。
        child: PillSegmentedToggle(
          index: index,
          dragProgress: dragProgress,
          onChanged: (_) {},
          items: const [
            PillSegmentedItem(label: '一', subtitle: 'A'),
            PillSegmentedItem(label: '二', subtitle: 'B'),
            PillSegmentedItem(label: '三', subtitle: 'C'),
          ],
        ),
      ),
    ),
  ),
);

Finder get _indicator => find.descendant(
  of: find.byType(AnimatedPositioned),
  matching: find.byType(DecoratedBox),
);

double _indicatorLeft(WidgetTester tester) =>
    tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left!;

void main() {
  testWidgets('色塊位置跟著 dragProgress 移，到 1 剛好蓋住隔壁段', (tester) async {
    await tester.pumpWidget(_toggle(index: 1));
    expect(_indicatorLeft(tester), 100);
    await tester.pumpWidget(_toggle(index: 1, dragProgress: 0.5));
    expect(_indicatorLeft(tester), 150);
    await tester.pumpWidget(_toggle(index: 1, dragProgress: -1));
    expect(_indicatorLeft(tester), 0);
  });

  testWidgets('跟手時色塊當幀就到位，不落後手指', (tester) async {
    await tester.pumpWidget(_toggle(index: 0));
    final origin = tester.getTopLeft(_indicator).dx;
    await tester.pumpWidget(_toggle(index: 0, dragProgress: 0.5));
    expect(tester.getTopLeft(_indicator).dx, origin + 50);
  });

  testWidgets('換段後色塊接在同一位置不跳', (tester) async {
    await tester.pumpWidget(_toggle(index: 0, dragProgress: 1));
    final atThreshold = tester.getTopLeft(_indicator).dx;
    await tester.pumpWidget(_toggle(index: 1));
    expect(tester.getTopLeft(_indicator).dx, atThreshold);
  });

  testWidgets('兩端往外的進度夾住，色塊不超出膠囊', (tester) async {
    await tester.pumpWidget(_toggle(index: 2, dragProgress: 1));
    expect(_indicatorLeft(tester), 200);
    await tester.pumpWidget(_toggle(index: 0, dragProgress: -1));
    expect(_indicatorLeft(tester), 0);
  });
}
