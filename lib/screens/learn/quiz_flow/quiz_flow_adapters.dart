// 後端題目 model → 共用作答流程視圖。單字題有題幹文字，聽力題只有音檔。

import '../../../core/network/api_client.dart';
import '../../../models/listening_models.dart';
import '../../../models/quiz_models.dart';
import 'quiz_flow_controller.dart';

List<QuizFlowQuestion> quizQuestionsToFlow(List<QuizQuestion> questions) => [
  for (final q in questions)
    QuizFlowQuestion(
      id: q.questionId,
      prompt: q.prompt,
      audioUrl: q.promptAudioUrl,
      selectedOptionId: q.selectedOptionId,
      options: [
        for (final o in q.options) QuizFlowOption(id: o.id, text: o.text),
      ],
    ),
];

List<QuizFlowQuestion> listeningQuestionsToFlow(
  List<ListeningQuestion> questions,
) => [
  for (final q in questions)
    QuizFlowQuestion(
      id: q.questionId,
      audioUrl: q.promptAudioUrl,
      selectedOptionId: q.selectedOptionId,
      options: [
        for (final o in q.options) QuizFlowOption(id: o.optionId, text: o.text),
      ],
    ),
];

/// 分級測驗每人只能做一次；後端回 ALREADY_PLACED 時不給重試。
bool isAlreadyPlaced(Object? e) =>
    e is ApiException && e.code == 'ALREADY_PLACED';

String? placementErrorMessage(Object? e) =>
    isAlreadyPlaced(e) ? '你已經完成過分級測驗了' : null;
