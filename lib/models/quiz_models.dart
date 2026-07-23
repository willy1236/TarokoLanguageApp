// 對應 /api/quiz/start、/api/quiz/submit
// 規格參考：資料流通與資料庫總覽.md §4.2 出題演算法、Flow 2
//
// 注意：options 陣列實際欄位名稱待真機（合法 JWT）驗證後確認，目前依文件描述
// （4 個 word id shuffle 而成）假設每個 option 同時帶 truku/zh，由 direction
// 決定顯示哪一個欄位。

class QuizOption {
  final int id;
  final String text;

  const QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['option_id'] as int,
      text: json['text'] as String? ?? '',
    );
  }

  String displayText(String direction) => text;
}

class QuizQuestion {
  final String questionId;
  final int order;
  final String direction; // 'zh_to_truku' | 'truku_to_zh'
  final String prompt;
  final String? promptAudioUrl;
  final List<QuizOption> options;
  final int? selectedOptionId; // 續接時還原先前已作答的選項

  const QuizQuestion({
    required this.questionId,
    required this.order,
    required this.direction,
    required this.prompt,
    required this.promptAudioUrl,
    required this.options,
    this.selectedOptionId,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionId: json['question_id'] as String,
      order: json['order'] as int,
      direction: json['direction'] as String,
      prompt: json['prompt'] as String? ?? '',
      promptAudioUrl: json['prompt_audio_url'] as String?,
      selectedOptionId: json['selected_option_id'] as int?,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizSession {
  final String sessionId;
  final String level;
  final List<QuizQuestion> questions;
  final bool resumed;
  final int totalQuestions;
  // 若使用者請求的 level 跟續接的舊 session 不同，這裡是使用者「原本想要」的 level；
  // 此時 [level] 是舊 session 實際的 level（回傳的 questions 也屬於舊 level）。
  final String? conflictingLevel;

  const QuizSession({
    required this.sessionId,
    required this.level,
    required this.questions,
    required this.resumed,
    required this.totalQuestions,
    this.conflictingLevel,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? [])
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    return QuizSession(
      sessionId: json['session_id'] as String,
      level: json['level'] as String? ?? '',
      resumed: json['resumed'] as bool? ?? false,
      conflictingLevel: json['conflicting_level'] as String?,
      totalQuestions: json['total_questions'] as int? ?? questions.length,
      questions: questions,
    );
  }
}

class QuizAnswer {
  final String questionId;
  final int selectedOptionId;

  const QuizAnswer({required this.questionId, required this.selectedOptionId});

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'selected_option_id': selectedOptionId,
      };
}

class QuizResult {
  final int score;
  final int total;
  final List<dynamic> results;

  const QuizResult({
    required this.score,
    required this.total,
    required this.results,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: json['score'] as int,
      total: json['total'] as int,
      results: json['results'] as List<dynamic>? ?? [],
    );
  }
}
