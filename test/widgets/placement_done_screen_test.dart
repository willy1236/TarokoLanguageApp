// PlacementDoneScreen（分級測驗已做過）的畫面層測試。
//
// 這支取代的人工測試：拿已做過分級測驗的帳號，從學習頁再點一次分級測驗，
// 確認不是雲朵錯誤畫面，而是酒紅頂部、已完成、建議等級與返回。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/screens/learn/placement_done_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/widgets/app_back_button.dart';

Widget _screen() => PlacementDoneScreen(
  title: '單字分級測驗',
  suggestedLevel: '中級',
  levelOf: (user) => user.quizSuggestedLevel,
);

Future<void> _pumpOnLearnPage(WidgetTester tester) async {
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('學習頁')),
    ),
  );
  navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => _screen()));
  await tester.pumpAndSettle();
  expect(find.byType(PlacementDoneScreen), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('顯示測驗名稱、已完成、建議起始等級，左上有返回鍵', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _screen()));

    expect(find.text('單字分級測驗'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('建議起始等級'), findsOneWidget);
    expect(find.text('中級'), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text(PlacementDoneView.backLabel), findsOneWidget);
    expect(find.textContaining('你已經完成過分級測驗了'), findsNothing);
  });

  testWidgets('左上返回鍵回到學習頁', (tester) async {
    await _pumpOnLearnPage(tester);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementDoneScreen), findsNothing);
    expect(find.text('學習頁'), findsOneWidget);
  });

  testWidgets('主要按鈕回到學習頁', (tester) async {
    await _pumpOnLearnPage(tester);
    await tester.tap(find.text(PlacementDoneView.backLabel));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementDoneScreen), findsNothing);
    expect(find.text('學習頁'), findsOneWidget);
  });

  group('精簡模式', () {
    setUp(() => seniorModeController.setEnabled(true));
    tearDown(() => seniorModeController.setEnabled(false));

    testWidgets('字級放大', (tester) async {
      await tester.pumpWidget(MaterialApp(home: _screen()));
      final size = tester.widget<Text>(find.text('建議起始等級')).style!.fontSize!;
      expect(size, 14);
    });
  });
}
