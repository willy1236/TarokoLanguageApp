import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/utils/birth_date.dart';

/// 在 BirthDateField 開三欄滾輪，把年轉到 [year]、日轉到 [day]（月份不動）後按確定。
Future<void> pickBirthDate(
  WidgetTester tester, {
  int year = 2000,
  int day = 15,
}) async {
  await tester.tap(find.text('請選擇出生日期'));
  await tester.pumpAndSettle();
  FixedExtentScrollController wheel(int index) => tester
      .widget<CupertinoPicker>(find.byType(CupertinoPicker).at(index))
      .scrollController!;
  wheel(0).jumpToItem(year - earliestBirthDate().year);
  await tester.pumpAndSettle();
  wheel(2).jumpToItem(day - 1);
  await tester.pumpAndSettle();
  await tester.tap(find.text('確定'));
  await tester.pumpAndSettle();
}

/// 按送出後跳出的生日確認框按「確認」。
Future<void> confirmBirthDateDialog(WidgetTester tester) async {
  expect(find.text('確認出生日期'), findsOneWidget);
  await tester.tap(find.text('確認'));
  await tester.pumpAndSettle();
}
