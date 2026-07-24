// 對應 /api/listening/start、/api/listening/answer、/api/listening/submit
// 規格參考：說明文件/API/聽力測驗.md（v1.2）
//
// 與 quiz_models.dart 的差異：題幹只有音檔，沒有 prompt/direction 文字欄位；
// session 多帶 mode（word_to_zh|word_to_truku|sentence_to_zh）與
// conflicting_level；submit 的 results/detail 在此深度解析（而非維持
// List<dynamic>），因為訂正畫面需要直接讀取 explanation/context/audio_url。

class ListeningOption {
  final int optionId;
  final String text;

  const ListeningOption({required this.optionId, required this.text});

  factory ListeningOption.fromJson(Map<String, dynamic> json) {
    return ListeningOption(
      optionId: json['option_id'] as int,
      text: json['text'] as String? ?? '',
    );
  }
}

class ListeningQuestion {
  final String questionId;
  final int order;
  final String? promptAudioUrl;
  final int? selectedOptionId;
  final List<ListeningOption> options;

  const ListeningQuestion({
    required this.questionId,
    required this.order,
    required this.promptAudioUrl,
    required this.selectedOptionId,
    required this.options,
  });

  factory ListeningQuestion.fromJson(Map<String, dynamic> json) {
    return ListeningQuestion(
      questionId: json['question_id'] as String,
      order: json['order'] as int,
      promptAudioUrl: json['prompt_audio_url'] as String?,
      selectedOptionId: json['selected_option_id'] as int?,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => ListeningOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ListeningSession {
  final String sessionId;
  final String mode;
  final String level;
  final bool resumed;
  final String? conflictingLevel;
  final int totalQuestions;
  final List<ListeningQuestion> questions;

  const ListeningSession({
    required this.sessionId,
    required this.mode,
    required this.level,
    required this.resumed,
    required this.conflictingLevel,
    required this.totalQuestions,
    required this.questions,
  });

  factory ListeningSession.fromJson(Map<String, dynamic> json) {
    return ListeningSession(
      sessionId: json['session_id'] as String,
      mode: json['mode'] as String,
      level: json['level'] as String,
      resumed: json['resumed'] as bool? ?? false,
      conflictingLevel: json['conflicting_level'] as String?,
      totalQuestions: json['total_questions'] as int? ?? 0,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => ListeningQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ListeningAnswer {
  final String questionId;
  final int selectedOptionId;

  const ListeningAnswer({
    required this.questionId,
    required this.selectedOptionId,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'selected_option_id': selectedOptionId,
      };
}

class ListeningAnswerRef {
  final int optionId;
  final String text;

  const ListeningAnswerRef({required this.optionId, required this.text});

  factory ListeningAnswerRef.fromJson(Map<String, dynamic> json) {
    return ListeningAnswerRef(
      optionId: json['option_id'] as int,
      text: json['text'] as String? ?? '',
    );
  }
}

class ListeningDetail {
  final String type; // 'word' | 'sentence'
  final int id;
  final String truku;
  final String zh;
  final String? en;
  final String? category; // 詞才有
  final String level;
  final String? audioUrl;
  final String? explanation;
  final String? context; // 句子才有（situation 才有）
  final String? source; // 句子才有：'situation' | 'curriculum'

  const ListeningDetail({
    required this.type,
    required this.id,
    required this.truku,
    required this.zh,
    required this.en,
    required this.category,
    required this.level,
    required this.audioUrl,
    required this.explanation,
    required this.context,
    required this.source,
  });

  factory ListeningDetail.fromJson(Map<String, dynamic> json) {
    return ListeningDetail(
      type: json['type'] as String? ?? 'word',
      id: json['id'] as int,
      truku: json['truku'] as String? ?? '',
      zh: json['zh'] as String? ?? '',
      en: json['en'] as String?,
      category: json['category'] as String?,
      level: json['level'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      explanation: json['explanation'] as String?,
      context: json['context'] as String?,
      source: json['source'] as String?,
    );
  }
}

class ListeningResultItem {
  final String questionId;
  final int order;
  final String? promptAudioUrl;
  final bool isCorrect;
  final ListeningAnswerRef yourAnswer;
  final ListeningAnswerRef correctAnswer;
  final ListeningDetail detail;

  const ListeningResultItem({
    required this.questionId,
    required this.order,
    required this.promptAudioUrl,
    required this.isCorrect,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.detail,
  });

  factory ListeningResultItem.fromJson(Map<String, dynamic> json) {
    return ListeningResultItem(
      questionId: json['question_id'] as String,
      order: json['order'] as int,
      promptAudioUrl: json['prompt_audio_url'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
      yourAnswer: ListeningAnswerRef.fromJson(
        json['your_answer'] as Map<String, dynamic>,
      ),
      correctAnswer: ListeningAnswerRef.fromJson(
        json['correct_answer'] as Map<String, dynamic>,
      ),
      detail: ListeningDetail.fromJson(
        json['detail'] as Map<String, dynamic>,
      ),
    );
  }
}

class ListeningResult {
  final String sessionId;
  final String mode;
  final int score;
  final int total;
  final String completedAt;
  final List<ListeningResultItem> results;

  const ListeningResult({
    required this.sessionId,
    required this.mode,
    required this.score,
    required this.total,
    required this.completedAt,
    required this.results,
  });

  factory ListeningResult.fromJson(Map<String, dynamic> json) {
    return ListeningResult(
      sessionId: json['session_id'] as String,
      mode: json['mode'] as String? ?? '',
      score: json['score'] as int,
      total: json['total'] as int,
      completedAt: json['completed_at'] as String? ?? '',
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => ListeningResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
