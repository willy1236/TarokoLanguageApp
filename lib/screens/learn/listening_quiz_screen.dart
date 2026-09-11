import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../models/listening_models.dart';
import '../../services/listening_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'listening_correction_screen.dart';
import 'quiz_flow/quiz_flow_adapters.dart';
import 'quiz_flow/quiz_flow_controller.dart';
import 'quiz_flow/quiz_flow_view.dart';

/// 已知的聽力測驗模組專屬錯誤碼 → 繁中提示文字
/// 規格參考：說明文件/API/聽力測驗.md §0 模組專屬錯誤碼
String? _listeningErrorMessage(Object? e) {
  if (e is! ApiException) return null;
  switch (e.code) {
    case 'ANSWER_COUNT_MISMATCH':
      return '作答題數不完整，請重新確認每一題都已作答';
    case 'QUESTION_ID_NOT_FOUND':
      return '題目不屬於此次測驗，請重新開始測驗';
    case 'INVALID_MODE':
      return '測驗模式錯誤，請重新選擇模式';
    case 'SESSION_NOT_FOUND':
      return '找不到測驗紀錄，請重新開始測驗';
    case 'SESSION_ALREADY_COMPLETED':
      return '此測驗已完成，請重新開始新的測驗';
    default:
      return null;
  }
}

class ListeningQuizScreen extends StatefulWidget {
  final String mode;
  final String level;

  const ListeningQuizScreen({
    super.key,
    required this.mode,
    required this.level,
  });

  @override
  State<ListeningQuizScreen> createState() => _ListeningQuizScreenState();
}

class _ListeningQuizScreenState extends State<ListeningQuizScreen> {
  final _audio = QuizAudio();
  late final QuizFlowController<ListeningResult> _flow = QuizFlowController(
    start: () async {
      final s = await ListeningService.startListening(
        widget.mode,
        widget.level,
      );
      return QuizFlowSession(
        sessionId: s.sessionId,
        level: s.level,
        conflictingLevel: s.conflictingLevel,
        questions: listeningQuestionsToFlow(s.questions),
      );
    },
    saveAnswer: ListeningService.answerListening,
    submit: (sessionId, answers) =>
        ListeningService.submitListening(sessionId, [
          for (final a in answers)
            ListeningAnswer(
              questionId: a.questionId,
              selectedOptionId: a.optionId,
            ),
        ]),
    emptyMessage: '此級別目前沒有可用的聽力題目，請稍後再試',
    confirmConflict: (oldLevel, wantedLevel) => showConfirmDialog(
      context,
      title: '有未完成的聽力測驗',
      message:
          '你還有未完成的「$oldLevel」聽力測驗，要繼續完成，還是先返回？\n'
          '（目前尚不支援直接放棄舊測驗，需完成後才能開始「$wantedLevel」）',
      cancelText: '返回',
      confirmText: '繼續「$oldLevel」測驗',
      barrierDismissible: false,
    ),
    onSaveFailed: (e) {
      if (!mounted) return;
      final message =
          _listeningErrorMessage(e) ??
          apiErrorMessage(e, fallback: '儲存答案失敗，請稍後再試');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    },
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _flow.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final keepGoing = await _flow.load();
    if (!keepGoing && mounted) Navigator.pop(context);
  }

  /// 續接舊 session 時，實際測驗的 level 可能跟使用者這次點的不同。
  String get _displayLevel => _flow.session?.level ?? widget.level;

  Future<void> _confirm() async {
    final result = await _flow.confirmAndNext();
    if (result == null || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListeningCorrectionScreen(result: result, level: _displayLevel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 標籤依 session 實際級別顯示，所以跟著 controller 重建。
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) => QuizFlowView(
        controller: _flow,
        audio: _audio,
        unitCaption: 'LISTENING · ${_displayLevel.toUpperCase()}',
        unitTitle: '聽力測驗 · $_displayLevel',
        cardCaption: '聆聽 · 選出正確答案',
        onRetry: _load,
        onConfirm: _confirm,
        errorMessageOf: _listeningErrorMessage,
      ),
    );
  }
}
