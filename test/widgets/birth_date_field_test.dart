// 出生日期三欄滾輪（POL-01）：換年、換月後月與日要收回合法範圍，不能選到未來或不存在的日期。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/utils/birth_date.dart';
import 'package:flutter_application_1/shared/widgets/birth_date_field.dart';

Future<List<DateTime>> _pumpField(WidgetTester tester, DateTime value) async {
  final picked = <DateTime>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BirthDateField(value: value, onChanged: picked.add),
      ),
    ),
  );
  await tester.tap(find.text(formatDisplayDate(value)));
  await tester.pumpAndSettle();
  return picked;
}

FixedExtentScrollController _wheel(WidgetTester tester, int index) => tester
    .widget<CupertinoPicker>(find.byType(CupertinoPicker).at(index))
    .scrollController!;

void main() {
  testWidgets('2/31 不存在：從 3/31 換到 2 月，日收回 28', (tester) async {
    final picked = await _pumpField(tester, DateTime(2001, 3, 31));
    _wheel(tester, 1).jumpToItem(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(picked, [DateTime(2001, 2, 28)]);
  });

  testWidgets('換到今年時月與日不超過今天', (tester) async {
    final today = taiwanToday();
    final picked = await _pumpField(tester, DateTime(today.year - 1, 12, 31));
    _wheel(tester, 0).jumpToItem(today.year - earliestBirthDate().year);
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(picked, hasLength(1));
    expect(picked.single.isAfter(today), isFalse);
  });

  testWidgets('按取消不回傳日期', (tester) async {
    final picked = await _pumpField(tester, DateTime(2001, 3, 31));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.byType(CupertinoPicker), findsNothing);
  });
}
