// 有未完成的舊測驗時的三選一對話框：放棄要再確認一次，取消就回到三選一。
// 用 320dp 寬（顯示大小調大後常見的最窄寬度）render，版面溢出會讓測試失敗。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_conflict_dialog.dart';
import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_flow_controller.dart';
import 'package:flutter_application_1/shared/widgets/confirm_dialog.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  late QuizConflictChoice? result;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;
    await tester.pumpWidget(
      wrapScreen(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showQuizConflictDialog(
                context,
                title: '有未完成的測驗',
                subject: '測驗',
                oldLevel: '初級',
                wantedLevel: '中高級',
              ),
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
  }

  testWidgets('三個選項，沒有「目前尚不支援」的說明', (tester) async {
    await open(tester);
    expect(find.text('繼續「初級」測驗'), findsOneWidget);
    expect(find.text('放棄舊測驗，開始「中高級」'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(find.textContaining('目前尚不支援'), findsNothing);
  });

  testWidgets('選繼續、返回各自回傳對應選擇', (tester) async {
    await open(tester);
    await tester.tap(find.text('繼續「初級」測驗'));
    await tester.pumpAndSettle();
    expect(result, QuizConflictChoice.resume);

    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(result, QuizConflictChoice.back);
  });

  testWidgets('放棄要二次確認；取消回到三選一，確認才回傳放棄', (tester) async {
    await open(tester);
    await tester.tap(find.text('放棄舊測驗，開始「中高級」'));
    await tester.pumpAndSettle();
    expect(find.text('已作答的題目不會保留，確定要放棄嗎？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('繼續「初級」測驗'), findsOneWidget);

    await tester.tap(find.text('放棄舊測驗，開始「中高級」'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄並開始「中高級」'));
    await tester.pumpAndSettle();
    expect(result, QuizConflictChoice.abandon);
    expect(find.byType(AppDialog), findsNothing);
  });
}
