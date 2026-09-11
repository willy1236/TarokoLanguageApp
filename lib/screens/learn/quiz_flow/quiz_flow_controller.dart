// 四支測驗畫面（單字測驗、單字分級、聽力測驗、聽力分級）共用的作答流程：
// 開始／續接 → 逐題作答（即時落地）→ 最後一題補漏 → 送出。
//
// 各畫面的 session／題目型別不同（QuizOption.id vs ListeningOption.optionId、
// 有沒有 prompt 文字），由畫面把後端 model 轉成這裡的 QuizFlow* 視圖再交給
// controller；controller 不碰 BuildContext，導頁、對話框、SnackBar 都經由
// 注入的回呼交回畫面，因此可以直接用假函式單元測試。

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class QuizFlowOption {
  final int id;
  final String text;

  const QuizFlowOption({required this.id, required this.text});
}

class QuizFlowQuestion {
  final String id;

  /// 題幹文字；聽力題沒有（只聽音檔）。
  final String? prompt;
  final String? audioUrl;
  final List<QuizFlowOption> options;

  /// 續接時後端回報的既有作答。
  final int? selectedOptionId;

  const QuizFlowQuestion({
    required this.id,
    this.prompt,
    this.audioUrl,
    required this.options,
    this.selectedOptionId,
  });
}

class QuizFlowSession {
  final String sessionId;

  /// 實際測驗的級別；續接舊 session 時可能跟使用者這次點的不同。
  final String? level;

  /// 後端回報「你想開始的級別」與未完成 session 衝突時，帶使用者這次想開的級別。
  final String? conflictingLevel;
  final List<QuizFlowQuestion> questions;

  const QuizFlowSession({
    required this.sessionId,
    this.level,
    this.conflictingLevel,
    required this.questions,
  });
}

typedef QuizFlowAnswer = ({String questionId, int optionId});

enum QuizFlowPhase { loading, error, quiz, done }

class QuizFlowController<R> extends ChangeNotifier {
  final Future<QuizFlowSession> Function() _start;
  final Future<void> Function(String sessionId, String questionId, int optionId)
  _saveAnswer;
  final Future<R> Function(String sessionId, List<QuizFlowAnswer> answers)
  _submit;

  /// 有衝突時問使用者要不要續接舊 session；回 false 代表放棄（畫面應返回）。
  final Future<bool> Function(String currentLevel, String wantedLevel)?
  confirmConflict;

  /// 非 null 時，沒有題目視為錯誤並顯示這段訊息；null 則不檢查。
  final String? emptyMessage;

  /// 單題即時儲存失敗（不擋作答，但必須讓使用者知道）。
  final void Function(Object error)? onSaveFailed;

  QuizFlowController({
    required Future<QuizFlowSession> Function() start,
    required Future<void> Function(
      String sessionId,
      String questionId,
      int optionId,
    )
    saveAnswer,
    required Future<R> Function(String sessionId, List<QuizFlowAnswer> answers)
    submit,
    this.confirmConflict,
    this.emptyMessage,
    this.onSaveFailed,
  }) : _start = start,
       _saveAnswer = saveAnswer,
       _submit = submit;

  QuizFlowPhase _phase = QuizFlowPhase.loading;
  Object? _error;
  QuizFlowSession? _session;
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;
  R? _result;
  bool _disposed = false;

  QuizFlowPhase get phase => _phase;
  Object? get error => _error;
  QuizFlowSession? get session => _session;
  int get currentIndex => _currentIndex;
  R? get result => _result;
  int get total => _session?.questions.length ?? 0;
  bool get isLast => _currentIndex == total - 1;
  QuizFlowQuestion get current => _session!.questions[_currentIndex];
  int? get selectedOptionId => _session == null ? null : _answers[current.id];

  /// 開始或續接。回傳 false 表示使用者在衝突對話框選擇返回。
  Future<bool> load() async {
    _set(() => _phase = QuizFlowPhase.loading);
    try {
      final session = await _start();
      if (_disposed) return true;
      final empty = emptyMessage;
      if (empty != null && session.questions.isEmpty) {
        _fail(
          ApiException(statusCode: 0, code: 'NO_QUESTIONS', message: empty),
        );
        return true;
      }
      final wanted = session.conflictingLevel;
      final confirm = confirmConflict;
      if (wanted != null && confirm != null) {
        final keepGoing = await confirm(session.level ?? '', wanted);
        if (_disposed) return true;
        if (!keepGoing) return false;
      }
      _apply(session);
    } catch (e) {
      if (!_disposed) _fail(e);
    }
    return true;
  }

  void _apply(QuizFlowSession session) {
    _answers
      ..clear()
      ..addAll({
        for (final q in session.questions)
          if (q.selectedOptionId != null) q.id: q.selectedOptionId!,
      });
    // 續接時跳到第一題還沒作答的位置；全部答過就停在最後一題等送出。
    final firstUnanswered = session.questions.indexWhere(
      (q) => !_answers.containsKey(q.id),
    );
    _set(() {
      _session = session;
      _currentIndex = firstUnanswered == -1
          ? session.questions.length - 1
          : firstUnanswered;
      _result = null;
      _error = null;
      _phase = QuizFlowPhase.quiz;
    });
  }

  /// 選取選項並即時落地，中途退出下次仍能續接。
  void select(int optionId) {
    final session = _session;
    if (session == null || _phase != QuizFlowPhase.quiz) return;
    final questionId = current.id;
    _set(() => _answers[questionId] = optionId);
    _saveAnswer(session.sessionId, questionId, optionId).catchError((Object e) {
      if (!_disposed) onSaveFailed?.call(e);
    });
  }

  /// 下一題；最後一題時先跳回第一個漏答的題目，全部答完才送出。
  /// 送出成功回傳結果（phase 變 done），其餘情況回傳 null。
  Future<R?> confirmAndNext() async {
    final session = _session;
    if (_submitting || session == null || selectedOptionId == null) {
      return null;
    }
    if (!isLast) {
      _set(() => _currentIndex += 1);
      return null;
    }
    final gap = session.questions.indexWhere(
      (q) => !_answers.containsKey(q.id),
    );
    if (gap != -1) {
      _set(() => _currentIndex = gap);
      return null;
    }

    _submitting = true;
    _set(() => _phase = QuizFlowPhase.loading);
    try {
      final result = await _submit(session.sessionId, [
        for (final q in session.questions)
          (questionId: q.id, optionId: _answers[q.id]!),
      ]);
      if (_disposed) return null;
      _set(() {
        _result = result;
        _phase = QuizFlowPhase.done;
      });
      return result;
    } catch (e) {
      if (!_disposed) _fail(e);
      return null;
    } finally {
      _submitting = false;
    }
  }

  void _fail(Object e) => _set(() {
    _error = e;
    _phase = QuizFlowPhase.error;
  });

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
