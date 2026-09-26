// PlacementResultScreen（分級測驗結果）的畫面層測試。
//
// 這支取代的人工測試：做完一整輪分級測驗才看得到的那一頁。
// 人工每驗一次就得重做一次測驗，而且「答錯才顯示你的答案」「未作答顯示（未作答）」
// 這類分支得刻意答錯才碰得到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/listening_models.dart';
import 'package:flutter_application_1/models/placement_models.dart';
import 'package:flutter_application_1/screens/learn/placement_result_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('顯示分數、建議等級與標題', (tester) async {
    await tester.pumpWidget(_app(_result(score: 2, total: 3, level: '中級')));

    expect(find.text('單字分級測驗'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('中級'), findsOneWidget);
    expect(find.text('建議起始等級'), findsOneWidget);
  });

  testWidgets('明講建議可被覆蓋，不讓使用者以為被鎖等級', (tester) async {
    await tester.pumpWidget(_app(_result()));

    expect(find.text('這只是建議，你隨時可以手動選擇其他等級開始測驗。'), findsOneWidget);
  });

  testWidgets('逐題詳解列出每一題', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(
          items: [
            _item(order: 1, isCorrect: true, prompt: 'qmpahang'),
            _item(order: 2, isCorrect: false, prompt: 'mkan'),
          ],
        ),
      ),
    );

    expect(find.text('qmpahang'), findsOneWidget);
    expect(find.text('mkan'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('答對的題目不顯示「你的答案」，只顯示正確答案', (tester) async {
    await tester.pumpWidget(
      _app(_result(items: [_item(order: 1, isCorrect: true, correct: '教書')])),
    );

    expect(find.text('正確答案：教書'), findsOneWidget);
    expect(find.textContaining('你的答案'), findsNothing);
  });

  testWidgets('答錯的題目同時顯示你的答案與正確答案', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(
          items: [
            _item(order: 1, isCorrect: false, correct: '教書', yours: '唱歌'),
          ],
        ),
      ),
    );

    expect(find.text('你的答案：唱歌'), findsOneWidget);
    expect(find.text('正確答案：教書'), findsOneWidget);
  });

  testWidgets('沒作答的題目顯示（未作答）而不是空白', (tester) async {
    await tester.pumpWidget(
      _app(_result(items: [_item(order: 1, isCorrect: false, yours: null)])),
    );

    expect(find.text('你的答案：（未作答）'), findsOneWidget);
  });

  testWidgets('滿分也正常顯示', (tester) async {
    await tester.pumpWidget(
      _app(
        _result(score: 3, total: 3, items: [_item(order: 1, isCorrect: true)]),
      ),
    );

    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('完成！'), findsOneWidget);
  });
}
