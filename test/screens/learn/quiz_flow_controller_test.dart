import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/learn/quiz_flow/quiz_flow_controller.dart';
import 'package:flutter_application_1/services/learn_refresh_notifier.dart';

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

  /// 依序作為每次 start 的回應，用完後一律回 [session]。
  final starts = <QuizFlowSession>[];

  /// start／abandon 的呼叫順序，例如 ['start', 'abandon:old', 'start']。
  final calls = <String>[];
  Object? abandonError;
  final notices = <String>[];
  final saved = <(String, int)>[];
  final submitted = <List<QuizFlowAnswer>>[];
  Object? saveError;
  Completer<String>? submitGate;
  late final QuizFlowController<String> flow;
  final saveFailures = <Object>[];

  _Harness(
    this.session, {
    Future<QuizConflictChoice> Function(String, String)? confirmConflict,
    bool canAbandon = false,
    String? emptyMessage,
  }) {
    flow = QuizFlowController<String>(
      start: () async {
        calls.add('start');
        return starts.isNotEmpty ? starts.removeAt(0) : session;
      },
      saveAnswer: (_, qid, opt) async {
        saved.add((qid, opt));
        if (saveError != null) throw saveError!;
      },
      submit: (_, answers) {
        submitted.add(answers);
        return submitGate?.future ?? Future.value('ok');
      },
      confirmConflict: confirmConflict,
      abandon: canAbandon
          ? (sessionId) async {
              calls.add('abandon:$sessionId');
              if (abandonError != null) throw abandonError!;
            }
          : null,
      onAbandonNotice: notices.add,
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

  test('交卷後晚到的單題 409 SESSION_ALREADY_COMPLETED 被忽略', () async {
    final h = _Harness(QuizFlowSession(sessionId: 's', questions: [q('q1')]));
    h.saveError = ApiException(
      statusCode: 409,
      code: 'SESSION_ALREADY_COMPLETED',
      message: '此測驗已完成',
    );
    await h.flow.load();
    h.flow.select(1);
    await pumpEventQueue();
    expect(h.saved, [('q1', 1)]);
    expect(h.saveFailures, isEmpty);
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

  group('有未完成的舊測驗', () {
    // 舊測驗是 A1（已答一題），使用者這次想開 A2。
    QuizFlowSession conflict() => QuizFlowSession(
      sessionId: 'old',
      level: 'A1',
      conflictingLevel: 'A2',
      questions: [q('q1', selected: 1), q('q2')],
    );
    final fresh = QuizFlowSession(
      sessionId: 'new',
      level: 'A2',
      questions: [q('n1'), q('n2')],
    );

    test('選返回時回傳 false', () async {
      final asked = <(String, String)>[];
      final h = _Harness(
        conflict(),
        canAbandon: true,
        confirmConflict: (cur, wanted) async {
          asked.add((cur, wanted));
          return QuizConflictChoice.back;
        },
      );
      expect(await h.flow.load(), isFalse);
      expect(asked, [('A1', 'A2')]);
      expect(h.calls, ['start']);
      expect(h.flow.phase, QuizFlowPhase.loading);
    });

    test('選續接時開出舊測驗並還原作答', () async {
      final h = _Harness(
        conflict(),
        canAbandon: true,
        confirmConflict: (_, _) async => QuizConflictChoice.resume,
      );
      expect(await h.flow.load(), isTrue);
      expect(h.calls, ['start']);
      expect(h.flow.session!.sessionId, 'old');
      expect(h.flow.currentIndex, 1);
    });

    test('選放棄時先放棄舊測驗再重新 start，開出新測驗', () async {
      final h = _Harness(
        fresh,
        canAbandon: true,
        confirmConflict: (_, _) async => QuizConflictChoice.abandon,
      )..starts.add(conflict());
      final before = LearnRefreshNotifier.revision.value;

      expect(await h.flow.load(), isTrue);

      expect(h.calls, ['start', 'abandon:old', 'start']);
      expect(h.flow.phase, QuizFlowPhase.quiz);
      expect(h.flow.session!.level, 'A2');
      expect(h.flow.currentIndex, 0);
      expect(h.flow.selectedOptionId, isNull);
      expect(h.notices, isEmpty);
      expect(LearnRefreshNotifier.revision.value, before + 1);
    });

    test('放棄時舊測驗已交卷（409）：通知訊息後照樣開出新測驗', () async {
      final h = _Harness(
        fresh,
        canAbandon: true,
        confirmConflict: (_, _) async => QuizConflictChoice.abandon,
      )..starts.add(conflict());
      h.abandonError = ApiException(
        statusCode: 409,
        code: 'SESSION_ALREADY_COMPLETED',
        message: '測驗已完成，不能放棄',
      );

      await h.flow.load();

      expect(h.notices, ['測驗已完成，不能放棄']);
      expect(h.calls, ['start', 'abandon:old', 'start']);
      expect(h.flow.phase, QuizFlowPhase.quiz);
      expect(h.flow.session!.sessionId, 'new');
    });

    test('放棄失敗進錯誤狀態；重試會重新 start 並再問一次', () async {
      var asked = 0;
      final h = _Harness(
        conflict(),
        canAbandon: true,
        confirmConflict: (_, _) async {
          asked++;
          return QuizConflictChoice.abandon;
        },
      );
      h.abandonError = ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'offline',
      );

      await h.flow.load();
      expect(h.flow.phase, QuizFlowPhase.error);
      expect(h.calls, ['start', 'abandon:old']);

      h.abandonError = null;
      h.session = fresh;
      h.starts.add(conflict());
      await h.flow.load();
      expect(asked, 2);
      expect(h.flow.phase, QuizFlowPhase.quiz);
      expect(h.flow.session!.sessionId, 'new');
    });

    test('重新 start 又衝突時再問一次，不直接續接', () async {
      final choices = [QuizConflictChoice.abandon, QuizConflictChoice.back];
      final h = _Harness(
        fresh,
        canAbandon: true,
        confirmConflict: (_, _) async => choices.removeAt(0),
      );
      h.starts.addAll([
        conflict(),
        QuizFlowSession(
          sessionId: 'other-device',
          level: 'A3',
          conflictingLevel: 'A2',
          questions: [q('x1')],
        ),
      ]);

      expect(await h.flow.load(), isFalse);
      expect(h.calls, ['start', 'abandon:old', 'start']);
      expect(choices, isEmpty);
    });

    test('沒注入 abandon 卻選放棄時視同返回', () async {
      final h = _Harness(
        conflict(),
        confirmConflict: (_, _) async => QuizConflictChoice.abandon,
      );
      expect(await h.flow.load(), isFalse);
      expect(h.calls, ['start']);
    });
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
