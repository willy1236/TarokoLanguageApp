import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/quiz_models.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../history/history_screen.dart';
import 'quiz_flow/quiz_flow_adapters.dart';
import 'quiz_flow/quiz_flow_controller.dart';
import 'quiz_flow/quiz_flow_view.dart';
import '../../core/constants/app_typography.dart';

/// 單字測驗（指定級別）。作答流程見 [QuizFlowController]；完成後在本頁顯示分數。
class LessonCardScreen extends StatefulWidget {
  final String level;

  const LessonCardScreen({super.key, required this.level});

  @override
  State<LessonCardScreen> createState() => _LessonCardScreenState();
}

class _LessonCardScreenState extends State<LessonCardScreen> {
  final _audio = QuizAudio();
  late final QuizFlowController<QuizResult> _flow = QuizFlowController(
    start: () async {
      final s = await LearnService.startQuiz(widget.level);
      return QuizFlowSession(
        sessionId: s.sessionId,
        level: s.level,
        conflictingLevel: s.conflictingLevel,
        questions: quizQuestionsToFlow(s.questions),
      );
    },
    saveAnswer: (sessionId, questionId, optionId) =>
        LearnService.answerQuestion(
          sessionId: sessionId,
          questionId: questionId,
          selectedOptionId: optionId,
        ),
    submit: (sessionId, answers) => LearnService.submitQuiz(sessionId, [
      for (final a in answers)
        QuizAnswer(questionId: a.questionId, selectedOptionId: a.optionId),
    ]),
    emptyMessage: '此級別目前沒有可用的題目，請稍後再試',
    confirmConflict: (oldLevel, wantedLevel) => showConfirmDialog(
      context,
      title: '有未完成的測驗',
      message:
          '你還有未完成的「$oldLevel」測驗，要繼續完成，還是先返回？\n'
          '（目前尚不支援直接放棄舊測驗，需完成後才能開始「$wantedLevel」）',
      cancelText: '返回',
      confirmText: '繼續「$oldLevel」測驗',
      barrierDismissible: false,
    ),
    onSaveFailed: (e) {
      debugPrint('LessonCardScreen: 儲存答案失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存答案失敗，請稍後再試')));
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

  @override
  Widget build(BuildContext context) {
    // 標籤依 session 實際級別顯示，所以跟著 controller 重建。
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) => QuizFlowView(
        controller: _flow,
        audio: _audio,
        unitCaption: 'LEVEL · ${_displayLevel.toUpperCase()}',
        unitTitle: _displayLevel,
        cardCaption: '聆聽 · 選出正確答案',
        onRetry: _load,
        onConfirm: _flow.confirmAndNext,
        doneBuilder: _buildResult,
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _flow.result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_displayLevel · 測驗完成',
              style: GoogleFonts.crimsonPro(
                fontSize: AppTypography.caption,
                fontStyle: FontStyle.italic,
                color: AppColors.fog,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.score} / ${result.total}',
              style: GoogleFonts.notoSerifTc(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuizBottomButton(label: '重新測驗', primary: false, onTap: _load),
                const SizedBox(width: 10),
                QuizBottomButton(
                  label: '返回 →',
                  primary: true,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              child: Text(
                '查看測驗紀錄 →',
                style: GoogleFonts.notoSerifTc(
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
