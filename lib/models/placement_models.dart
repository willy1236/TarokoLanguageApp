// 對應 /api/quiz/placement/{start,answer,submit}、/api/listening/placement/{start,answer,submit}
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md
//
// start/answer 回應形狀與現有 quiz_models.dart/listening_models.dart 完全相同，
// 直接重用 QuizQuestion/ListeningQuestion.fromJson。submit 回應多了 result_level
// （分級測驗建議的起始等級），且詳解結構跟一般 quiz/listening 的 submit 不同，
// 故另建 PlacementResult/PlacementResultItem，而非沿用 QuizResult（其 results
// 只是未解析的 List<dynamic>）。
//
// 單字（word_detail）與聽力（mode + detail）的逐題詳解欄位不完全相同，
// 用 PlacementResultItem 的 nullable 欄位分別承接。

import 'quiz_models.dart';
import 'listening_models.dart';

// 單字分級：題目形狀與一般 quiz 相同（有 direction/prompt），重用 QuizQuestion。
class QuizPlacementSession {
  final String sessionId;
  final bool resumed;
  final int totalQuestions;
  final List<QuizQuestion> questions;

  const QuizPlacementSession({
    required this.sessionId,
    required this.resumed,
    required this.totalQuestions,
    required this.questions,
  });

  factory QuizPlacementSession.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? [])
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    return QuizPlacementSession(
      sessionId: json['session_id'] as String,
      resumed: json['resumed'] as bool? ?? false,
      totalQuestions: json['total_questions'] as int? ?? questions.length,
      questions: questions,
    );
  }
}

// 聽力分級：題目沒有 direction/prompt 文字（只有音檔），mode 每題隨機、不對外暴露，
// 形狀與一般 listening 的 question 相同，重用 ListeningQuestion。
class ListeningPlacementSession {
  final String sessionId;
  final bool resumed;
  final int totalQuestions;
  final List<ListeningQuestion> questions;

  const ListeningPlacementSession({
    required this.sessionId,
    required this.resumed,
    required this.totalQuestions,
    required this.questions,
  });

  factory ListeningPlacementSession.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? [])
        .map((e) => ListeningQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    return ListeningPlacementSession(
      sessionId: json['session_id'] as String,
      resumed: json['resumed'] as bool? ?? false,
      totalQuestions: json['total_questions'] as int? ?? questions.length,
      questions: questions,
    );
  }
}

class PlacementWordDetail {
  final int wordId;
  final String truku;
  final String zh;
  final String? en;
  final String? category;
  final String level;
  final String? audioUrl;
  final String? explanation;

  const PlacementWordDetail({
    required this.wordId,
    required this.truku,
    required this.zh,
    required this.en,
    required this.category,
    required this.level,
    required this.audioUrl,
    required this.explanation,
  });

  factory PlacementWordDetail.fromJson(Map<String, dynamic> json) {
    return PlacementWordDetail(
      wordId: json['word_id'] as int,
      truku: json['truku'] as String? ?? '',
      zh: json['zh'] as String? ?? '',
      en: json['en'] as String?,
      category: json['category'] as String?,
      level: json['level'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      explanation: json['explanation'] as String?,
    );
  }
}

class PlacementResultItem {
  final String questionId;
  final int order;
  final bool isCorrect;
  final ListeningAnswerRef? yourAnswer;
  final ListeningAnswerRef correctAnswer;
  // 單字分級才有：
  final String? direction;
  final String? prompt;
  final PlacementWordDetail? wordDetail;
  // 聽力分級才有：
  final String? mode;
  final String? promptAudioUrl;
  final ListeningDetail? detail;

  const PlacementResultItem({
    required this.questionId,
    required this.order,
    required this.isCorrect,
    required this.yourAnswer,
    required this.correctAnswer,
    this.direction,
    this.prompt,
    this.wordDetail,
    this.mode,
    this.promptAudioUrl,
    this.detail,
  });

  factory PlacementResultItem.fromJson(Map<String, dynamic> json) {
    ListeningAnswerRef? parseAnswerRef(dynamic raw) {
      if (raw == null) return null;
      final map = raw as Map<String, dynamic>;
      if (map['option_id'] == null) return null;
      return ListeningAnswerRef.fromJson(map);
    }

    return PlacementResultItem(
      questionId: json['question_id'] as String,
      order: json['order'] as int,
      isCorrect: json['is_correct'] as bool? ?? false,
      yourAnswer: parseAnswerRef(json['your_answer']),
      correctAnswer: parseAnswerRef(json['correct_answer'])!,
      direction: json['direction'] as String?,
      prompt: json['prompt'] as String?,
      wordDetail: json['word_detail'] == null
          ? null
          : PlacementWordDetail.fromJson(
              json['word_detail'] as Map<String, dynamic>,
            ),
      mode: json['mode'] as String?,
      promptAudioUrl: json['prompt_audio_url'] as String?,
      detail: json['detail'] == null
          ? null
          : ListeningDetail.fromJson(json['detail'] as Map<String, dynamic>),
    );
  }
}

class PlacementResult {
  final String sessionId;
  final int score;
  final int total;
  final String resultLevel;
  final String completedAt;
  final List<PlacementResultItem> results;

  const PlacementResult({
    required this.sessionId,
    required this.score,
    required this.total,
    required this.resultLevel,
    required this.completedAt,
    required this.results,
  });

  factory PlacementResult.fromJson(Map<String, dynamic> json) {
    return PlacementResult(
      sessionId: json['session_id'] as String,
      score: json['score'] as int,
      total: json['total'] as int,
      resultLevel: json['result_level'] as String? ?? '',
      completedAt: json['completed_at'] as String? ?? '',
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => PlacementResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlacementAnswer {
  final String questionId;
  final int selectedOptionId;

  const PlacementAnswer({
    required this.questionId,
    required this.selectedOptionId,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'selected_option_id': selectedOptionId,
      };
}
