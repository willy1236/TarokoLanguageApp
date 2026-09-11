// 單字分級測驗作答畫面。流程與單字測驗共用 QuizFlowController，
// 差異：不需選 level（橫跨 4 級共 12 題）、submit 走 PlacementService、
// 完成後導向 PlacementResultScreen 顯示建議等級。
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md

import 'package:flutter/material.dart';
import '../../models/placement_models.dart';
import '../../services/placement_service.dart';
import 'placement_result_screen.dart';
import 'quiz_flow/quiz_flow_adapters.dart';
import 'quiz_flow/quiz_flow_controller.dart';
import 'quiz_flow/quiz_flow_view.dart';

class QuizPlacementScreen extends StatefulWidget {
  const QuizPlacementScreen({super.key});

  @override
  State<QuizPlacementScreen> createState() => _QuizPlacementScreenState();
}

class _QuizPlacementScreenState extends State<QuizPlacementScreen> {
  final _audio = QuizAudio();
  late final QuizFlowController<PlacementResult> _flow = QuizFlowController(
    start: () async {
      final s = await PlacementService.startQuizPlacement();
      return QuizFlowSession(
        sessionId: s.sessionId,
        questions: quizQuestionsToFlow(s.questions),
      );
    },
    saveAnswer: (sessionId, questionId, optionId) =>
        PlacementService.answerQuizPlacement(
          sessionId: sessionId,
          questionId: questionId,
          selectedOptionId: optionId,
        ),
    submit: (sessionId, answers) =>
        PlacementService.submitQuizPlacement(sessionId, [
          for (final a in answers)
            PlacementAnswer(
              questionId: a.questionId,
              selectedOptionId: a.optionId,
            ),
        ]),
    onSaveFailed: (e) {
      debugPrint('QuizPlacementScreen: 儲存答案失敗：$e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存答案失敗，請稍後再試')));
    },
  );

  @override
  void initState() {
    super.initState();
    _flow.load();
  }

  @override
  void dispose() {
    _flow.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final result = await _flow.confirmAndNext();
    if (result == null || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlacementResultScreen(result: result, title: '單字分級測驗'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuizFlowView(
      controller: _flow,
      audio: _audio,
      unitCaption: 'PLACEMENT · 單字分級測驗',
      unitTitle: '橫跨四個等級，找出最適合你的起點',
      unitTitleSize: 16,
      cardCaption: '選出正確答案',
      onRetry: _flow.load,
      onConfirm: _confirm,
      errorMessageOf: placementErrorMessage,
      retryable: (e) => !isAlreadyPlaced(e),
    );
  }
}
