import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_flow_controller.dart';

QuizFlowQuestion q(String id, {int? selected}) => QuizFlowQuestion(
  id: id,
  prompt: id,
  selectedOptionId: selected,
  options: const [
    QuizFlowOption(id: 1, text: 'a'),
    QuizFlowOption(id: 2, text: 'b'),
  ],
);

class _Harness {
  QuizFlowSession session;
  final saved = <(String, int)>[];
  final submitted = <List<QuizFlowAnswer>>[];
  Object? saveError;
  Completer<String>? submitGate;
  late final QuizFlowController<String> flow;
  final saveFailures = <Object>[];

  _Harness(
    this.session, {
    Future<bool> Function(String, String)? confirmConflict,
    String? emptyMessage,
  }) {
    flow = QuizFlowController<String>(
      start: () async => session,
      saveAnswer: (_, qid, opt) async {
        saved.add((qid, opt));
        if (saveError != null) throw saveError!;
      },
      submit: (_, answers) {
        submitted.add(answers);
        return submitGate?.future ?? Future.value('ok');
      },
      confirmConflict: confirmConflict,
      emptyMessage: emptyMessage,
      onSaveFailed: saveFailures.add,
    );
  }
}

void main() {
  test('續接時跳到第一題未作答並還原選取', () async {
    final h = _Harness(
      QuizFlowSession(
        sessionId: 's',
        questions: [q('q1', selected: 2), q('q2'), q('q3', selected: 1)],
      ),
    );
    await h.flow.load();
    expect(h.flow.phase, QuizFlowPhase.quiz);
    expect(h.flow.currentIndex, 1);
    expect(h.flow.selectedOptionId, isNull);
  });

  test('全部答過時停在最後一題', () async {
    final h = _Harness(
      QuizFlowSession(
        sessionId: 's',
        questions: [q('q1', selected: 1), q('q2', selected: 2)],
      ),
    );
    await h.flow.load();
    expect(h.flow.currentIndex, 1);
    expect(h.flow.selectedOptionId, 2);
  });

  test('選取即時落地；儲存失敗觸發回呼但不擋作答', () async {
    final h = _Harness(QuizFlowSession(sessionId: 's', questions: [q('q1')]));
    h.saveError = StateError('offline');
    await h.flow.load();
    h.flow.select(2);
    await pumpEventQueue();
    expect(h.saved, [('q1', 2)]);
    expect(h.saveFailures, hasLength(1));
    expect(h.flow.selectedOptionId, 2);
  });

  test('最後一題有漏答時跳回缺口，補完才送出', () async {
    final h = _Harness(
      QuizFlowSession(
        sessionId: 's',
        questions: [q('q1'), q('q2'), q('q3', selected: 1)],
      ),
    );
    await h.flow.load();
    expect(h.flow.currentIndex, 0);
    h.flow.select(1);
    await h.flow.confirmAndNext(); // → q2
    await h.flow.confirmAndNext(); // q2 沒選，不動
    expect(h.flow.currentIndex, 1);
    h.flow.select(2);
    await h.flow.confirmAndNext(); // → q3
    final result = await h.flow.confirmAndNext();
    expect(result, 'ok');
    expect(h.flow.phase, QuizFlowPhase.done);
    expect(h.submitted.single.map((a) => (a.questionId, a.optionId)), [
      ('q1', 1),
      ('q2', 2),
      ('q3', 1),
    ]);
  });

  test('送出中連點只呼叫一次 submit', () async {
    final h = _Harness(
      QuizFlowSession(sessionId: 's', questions: [q('q1', selected: 1)]),
    );
    h.submitGate = Completer<String>();
    await h.flow.load();
    final first = h.flow.confirmAndNext();
    final second = h.flow.confirmAndNext();
    h.submitGate!.complete('ok');
    expect(await first, 'ok');
    expect(await second, isNull);
    expect(h.submitted, hasLength(1));
  });

  test('送出失敗進入錯誤狀態', () async {
    final h = _Harness(
      QuizFlowSession(sessionId: 's', questions: [q('q1', selected: 1)]),
    );
    h.submitGate = Completer<String>();
    await h.flow.load();
    final pending = h.flow.confirmAndNext();
    h.submitGate!.completeError(
      ApiException(statusCode: 500, code: 'X', message: 'boom'),
    );
    expect(await pending, isNull);
    expect(h.flow.phase, QuizFlowPhase.error);
  });

  test('沒有題目時依 emptyMessage 顯示錯誤', () async {
    final h = _Harness(
      const QuizFlowSession(sessionId: 's', questions: []),
      emptyMessage: '沒有題目',
    );
    await h.flow.load();
    expect(h.flow.phase, QuizFlowPhase.error);
    expect((h.flow.error as ApiException).message, '沒有題目');
  });

  test('衝突時拒絕續接回傳 false', () async {
    final asked = <(String, String)>[];
    final h = _Harness(
      QuizFlowSession(
        sessionId: 's',
        level: 'A1',
        conflictingLevel: 'A2',
        questions: [q('q1')],
      ),
      confirmConflict: (cur, wanted) async {
        asked.add((cur, wanted));
        return false;
      },
    );
    expect(await h.flow.load(), isFalse);
    expect(asked, [('A1', 'A2')]);
    expect(h.flow.phase, QuizFlowPhase.loading);
  });

  test('dispose 後才回來的送出結果被忽略', () async {
    final h = _Harness(
      QuizFlowSession(sessionId: 's', questions: [q('q1', selected: 1)]),
    );
    h.submitGate = Completer<String>();
    await h.flow.load();
    final pending = h.flow.confirmAndNext();
    h.flow.dispose();
    h.submitGate!.complete('late');
    expect(await pending, isNull);
  });
}
