// QuizFlowView（四支測驗畫面共用的作答版面）的畫面層測試。
//
// controller 的流程邏輯已由 test/screens/learn/quiz_flow_controller_test.dart 覆蓋，
// 這支只測「controller 的狀態怎麼呈現給使用者」：進度、選項選取、
// 下一題按鈕的啟用條件、錯誤與可重試與否。
//
// 這取代的人工測試是最花時間的一種：要真的從第一題點到最後一題才驗得到
// 「完成測驗」按鈕與漏答回跳，而且每次都要重開一個 session。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_flow_controller.dart';
import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_flow_view.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';

import '../helpers/widget_test_helpers.dart';

QuizFlowQuestion _q(String id, {int? selected}) => QuizFlowQuestion(
  id: id,
  prompt: '題目 $id',
  options: [
    QuizFlowOption(id: 1, text: '$id-選項一'),
    QuizFlowOption(id: 2, text: '$id-選項二'),
  ],
  selectedOptionId: selected,
);

QuizFlowSession _session(List<QuizFlowQuestion> questions) =>
    QuizFlowSession(sessionId: 's1', level: '初級', questions: questions);

/// 用假函式組 controller：不碰 HTTP，也不需要 BuildContext。
QuizFlowController<String> _controller({
  Future<QuizFlowSession> Function()? start,
  Future<String> Function(String, List<QuizFlowAnswer>)? submit,
  void Function(Object)? onSaveFailed,
  Future<void> Function(String, String, int)? saveAnswer,
}) {
  return QuizFlowController<String>(
    start: start ?? () async => _session([_q('a'), _q('b'), _q('c')]),
    saveAnswer: saveAnswer ?? (_, _, _) async {},
    submit: submit ?? (_, _) async => 'done',
    onSaveFailed: onSaveFailed,
  );
}

Widget _view(
  QuizFlowController<String> controller, {
  Future<void> Function()? onConfirm,
  Future<void> Function()? onRetry,
  bool Function(Object?)? retryable,
  WidgetBuilder? doneBuilder,
}) {
  return MaterialApp(
    home: QuizFlowView(
      controller: controller,
      audio: QuizAudio(),
      unitCaption: 'LEVEL · A1',
      unitTitle: '初級單字',
      cardCaption: '選出正確答案',
      onRetry: onRetry ?? () async {},
      onConfirm: onConfirm ?? () async => controller.confirmAndNext(),
      retryable: retryable,
      doneBuilder: doneBuilder,
    ),
  );
}

/// 取「下一題／完成測驗」那顆按鈕目前是否可按。
bool _nextEnabled(WidgetTester tester, String label) {
  final button = tester.widget<QuizBottomButton>(
    find.widgetWithText(QuizBottomButton, label),
  );
  return button.onTap != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => stubCommonChannels(audio: true));

  testWidgets('載入中顯示轉圈', (tester) async {
    final controller = _controller(
      start: () =>
          Future.delayed(const Duration(seconds: 1), () => _session([_q('a')])),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    unawaitedLoad(controller);
    await tester.pump();

    expect(find.byType(TrukuLoadingView), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('顯示題目、選項與進度', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    expect(find.text('題目 a'), findsOneWidget);
    expect(find.text('a-選項一'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('初級單字'), findsOneWidget);
  });

  testWidgets('還沒選答案時下一題按鈕不可按', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    expect(_nextEnabled(tester, '下一題 →'), isFalse);

    await tester.tap(find.text('a-選項一'));
    await tester.pump();

    expect(_nextEnabled(tester, '下一題 →'), isTrue);
  });

  testWidgets('答完一題進到下一題，進度跟著走', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    await tester.tap(find.text('a-選項一'));
    await tester.pump();
    await tester.tap(find.text('下一題 →'));
    await tester.pumpAndSettle();

    expect(find.text('題目 b'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('最後一題的按鈕文字換成完成測驗', (tester) async {
    final controller = _controller(start: () async => _session([_q('a')]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    expect(find.text('完成測驗 →'), findsOneWidget);
    expect(find.text('下一題 →'), findsNothing);
  });

  testWidgets('續接時跳到第一個沒作答的題目', (tester) async {
    final controller = _controller(
      start: () async => _session([_q('a', selected: 1), _q('b'), _q('c')]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    expect(find.text('題目 b'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('最後一題送出前有漏答會跳回漏答的題目', (tester) async {
    var submitted = false;
    final controller = _controller(
      start: () async => _session([_q('a'), _q('b', selected: 2)]),
      submit: (_, _) async {
        submitted = true;
        return 'done';
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller));
    await controller.load();
    await tester.pump();

    // 續接後停在第 1 題（a 未答），先跳過它到最後一題。
    await tester.tap(find.text('a-選項二'));
    await tester.pump();
    await tester.tap(find.text('下一題 →'));
    await tester.pumpAndSettle();

    expect(find.text('題目 b'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('錯誤時顯示錯誤畫面與重試', (tester) async {
    var retried = false;
    final controller = _controller(
      start: () async => throw ApiException(
        statusCode: 500,
        code: 'SERVER_ERROR',
        message: '伺服器忙碌中',
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _view(
        controller,
        onRetry: () async {
          retried = true;
        },
      ),
    );
    await controller.load();
    await tester.pump();

    expect(find.byType(TrukuErrorView), findsOneWidget);
    expect(find.textContaining('伺服器忙碌中'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('不可重試的錯誤不顯示重試按鈕', (tester) async {
    final controller = _controller(
      start: () async => throw ApiException(
        statusCode: 409,
        code: 'ALREADY_PLACED',
        message: '你已完成分級測驗',
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_view(controller, retryable: (_) => false));
    await controller.load();
    await tester.pump();

    expect(find.textContaining('你已完成分級測驗'), findsOneWidget);
    expect(find.text('重試'), findsNothing);
  });

  testWidgets('送出完成後顯示 doneBuilder 的內容', (tester) async {
    final controller = _controller(start: () async => _session([_q('a')]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _view(controller, doneBuilder: (_) => const Center(child: Text('計分中'))),
    );
    await controller.load();
    await tester.pump();

    await tester.tap(find.text('a-選項一'));
    await tester.pump();
    await tester.tap(find.text('完成測驗 →'));
    await tester.pumpAndSettle();

    expect(find.text('計分中'), findsOneWidget);
  });
}

/// 刻意不 await：測試要在載入還沒完成時檢查轉圈畫面。
void unawaitedLoad(QuizFlowController<String> controller) {
  controller.load();
}
