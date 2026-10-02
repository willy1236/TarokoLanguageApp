// PlacementResultScreen（分級測驗結果）的畫面層測試。
//
// 這支取代的人工測試：做完一整輪分級測驗才看得到的那一頁。
// 人工每驗一次就得重做一次測驗，而且「答錯才顯示正確答案」「未作答顯示（未作答）」
// 這類分支得刻意答錯才碰得到；返回要回到學習頁、不能退回題目頁，也得實際走一輪才看得出來。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/listening_models.dart';
import 'package:flutter_application_1/models/placement_models.dart';
import 'package:flutter_application_1/screens/learn/placement_result_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/widgets/app_back_button.dart';

import '../helpers/flow_test_helpers.dart';

PlacementResultItem _item({
  required int order,
  required bool isCorrect,
  String prompt = 'qmpahang',
  String correct = '教書',
  String? yours = '唱歌',
}) => PlacementResultItem(
  questionId: 'q$order',
  order: order,
  isCorrect: isCorrect,
  yourAnswer: yours == null
      ? null
      : ListeningAnswerRef(optionId: 2, text: yours),
  correctAnswer: ListeningAnswerRef(optionId: 1, text: correct),
  prompt: prompt,
);

PlacementResult _result({
  int score = 2,
  int total = 3,
  String level = '中級',
  List<PlacementResultItem>? items,
}) => PlacementResult(
  sessionId: 's1',
  score: score,
  total: total,
  resultLevel: level,
  completedAt: '2026-09-17T00:00:00Z',
  results:
      items ??
      [_item(order: 1, isCorrect: true), _item(order: 2, isCorrect: false)],
);

Widget _app(PlacementResult result, {String title = '單字分級測驗'}) => MaterialApp(
  home: PlacementResultScreen(result: result, title: title),
);

/// 重現真實堆疊：學習頁 → 等級選擇頁 → 分級測驗題目頁，交卷後題目頁被結果頁
/// pushReplacement 取代。
Future<void> _pumpRealStack(WidgetTester tester) async {
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('學習頁')),
    ),
  );
  navKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('等級頁'))),
  );
  await tester.pumpAndSettle();
  navKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('題目頁'))),
  );
  await tester.pumpAndSettle();
  navKey.currentState!.pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => PlacementResultScreen(result: _result(), title: '單字分級測驗'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(PlacementResultScreen), findsOneWidget);
}

void _expectBackOnLearnPage() {
  expect(find.byType(PlacementResultScreen), findsNothing);
  expect(find.text('題目頁'), findsNothing);
  expect(find.text('等級頁'), findsNothing);
  expect(find.text('學習頁'), findsOneWidget);
}

double _fontSizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('酒紅成績區顯示測驗名稱、分數、建議起始等級，左上有返回鍵', (tester) async {
    await tester.pumpWidget(_app(_result(score: 2, total: 3, level: '中級')));

    expect(find.text('單字分級測驗'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('建議起始等級'), findsOneWidget);
    expect(find.text('中級'), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text(PlacementResultScreen.backToLearnLabel), findsOneWidget);
  });

  testWidgets('逐題卡顯示題號與答對／答錯標籤', (tester) async {
    await tester.pumpWidget(_app(_result()));

    expect(find.text('第 1 題'), findsOneWidget);
    expect(find.text('第 2 題'), findsOneWidget);
    expect(find.text('答對'), findsOneWidget);
    expect(find.text('答錯'), findsOneWidget);
  });

  testWidgets('答對的題目只顯示你的作答，不顯示正確答案', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(
          items: [_item(order: 1, isCorrect: true, correct: '教書', yours: '教書')],
        ),
      ),
    );

    expect(find.text('你的作答'), findsOneWidget);
    expect(find.text('教書'), findsOneWidget);
    expect(find.text('正確答案'), findsNothing);
  });

  testWidgets('答錯的題目同時顯示你的作答與正確答案', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(
          items: [
            _item(order: 1, isCorrect: false, correct: '教書', yours: '唱歌'),
          ],
        ),
      ),
    );

    expect(find.text('唱歌'), findsOneWidget);
    expect(find.text('正確答案'), findsOneWidget);
    expect(find.text('教書'), findsOneWidget);
  });

  testWidgets('沒作答的題目顯示（未作答）而不是空白', (tester) async {
    await tester.pumpWidget(
      _app(_result(items: [_item(order: 1, isCorrect: false, yours: null)])),
    );

    expect(find.text('（未作答）'), findsOneWidget);
  });

  testWidgets('滿分也正常顯示', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(score: 3, total: 3, items: [_item(order: 1, isCorrect: true)]),
      ),
    );

    expect(find.text('3 / 3'), findsOneWidget);
  });

  group('返回一律回到學習頁、不退回題目頁', () {
    testWidgets('左上返回鍵', (tester) async {
      await _pumpRealStack(tester);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      _expectBackOnLearnPage();
    });

    testWidgets('主要按鈕', (tester) async {
      await _pumpRealStack(tester);
      await tester.tap(find.text(PlacementResultScreen.backToLearnLabel));
      await tester.pumpAndSettle();
      _expectBackOnLearnPage();
    });

    testWidgets('系統返回', (tester) async {
      await _pumpRealStack(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _expectBackOnLearnPage();
    });
  });

  for (final senior in [false, true]) {
    group(senior ? '精簡模式' : '一般模式', () {
      // 在 testWidgets 的 FakeAsync 內切換會卡住，改在 setUp 切。
      setUp(() => seniorModeController.setEnabled(senior));
      tearDown(() => seniorModeController.setEnabled(false));

      testWidgets('字級依模式換算', (tester) async {
        await tester.pumpWidget(_app(_result()));
        final step = senior ? 2.0 : 0.0;

        expect(_fontSizeOf(tester, '單字分級測驗'), 12 + step);
        expect(_fontSizeOf(tester, '建議起始等級'), 12 + step);
        expect(
          _fontSizeOf(tester, PlacementResultScreen.backToLearnLabel),
          16 + step,
        );
        expect(_fontSizeOf(tester, '第 1 題'), 12 + step);
        expect(_fontSizeOf(tester, '正確答案'), 12 + step);
      });

      testWidgets('320dp 寬度不 overflow', (tester) async {
        usePhoneSurface(tester, size: const Size(320, 640));
        await tester.pumpWidget(
          _app(
            _result(
              level: '進階級',
              items: [
                _item(
                  order: 1,
                  isCorrect: false,
                  prompt: 'mkla kari Truku ka hiya',
                  correct: '他會說太魯閣族語',
                  yours: '他喜歡唱太魯閣族的歌',
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
