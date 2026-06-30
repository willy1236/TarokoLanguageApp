// 對應 /api/quiz/start、/api/quiz/submit
// 規格參考：資料流通與資料庫總覽.md §4.2 出題演算法、Flow 2
//
// 注意：options 陣列實際欄位名稱待真機（合法 JWT）驗證後確認，目前依文件描述
// （4 個 word id shuffle 而成）假設每個 option 同時帶 truku/zh，由 direction
// 決定顯示哪一個欄位。

class QuizOption {
  final int id;
  final String? truku;
  final String? zh;

  const QuizOption({required this.id, this.truku, this.zh});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as int,
      truku: json['truku'] as String?,
      zh: json['zh'] as String?,
    );
  }

  /// 依方向取得這個選項該顯示的文字（與 prompt 相反語言）
  String displayText(String direction) {
    return direction == 'zh_to_truku' ? (truku ?? '') : (zh ?? '');
  }
}

class QuizQuestion {
  final String questionId;
  final int order;
  final String direction; // 'zh_to_truku' | 'truku_to_zh'
  final String prompt;
  final String? promptAudioUrl;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.questionId,
    required this.order,
    required this.direction,
    required this.prompt,
    required this.promptAudioUrl,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionId: json['question_id'] as String,
      order: json['order'] as int,
      direction: json['direction'] as String,
      prompt: json['prompt'] as String? ?? '',
      promptAudioUrl: json['prompt_audio_url'] as String?,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizSession {
  final String sessionId;
  final List<QuizQuestion> questions;
  final bool resumed;

  const QuizSession({
    required this.sessionId,
    required this.questions,
    required this.resumed,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      sessionId: json['session_id'] as String,
      resumed: json['resumed'] as bool? ?? false,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
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
