// 對應 /api/history、/api/history/quiz/:session_id、/api/history/listening/:session_id
// 規格參考：說明文件/API/測驗紀錄.md

class HistoryRecord {
  final String type; // 'quiz' | 'listening'
  final String typeLabel;
  final String sessionId;
  final String status; // 'in_progress' | 'completed'
  final String statusLabel;
  final String level;
  final String? mode; // 僅 listening 有
  final String? modeLabel;
  final int? score; // 進行中為 null
  final int answeredCount;
  final int totalQuestions;
  final String startedAt;
  final String lastActiveAt;
  final String? completedAt;

  const HistoryRecord({
    required this.type,
    required this.typeLabel,
    required this.sessionId,
    required this.status,
    required this.statusLabel,
    required this.level,
    required this.mode,
    required this.modeLabel,
    required this.score,
    required this.answeredCount,
    required this.totalQuestions,
    required this.startedAt,
    required this.lastActiveAt,
    required this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isListening => type == 'listening';

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      type: json['type'] as String,
      typeLabel: json['type_label'] as String? ?? '',
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String? ?? '',
      level: json['level'] as String? ?? '',
      mode: json['mode'] as String?,
      modeLabel: json['mode_label'] as String?,
      score: json['score'] as int?,
      answeredCount: json['answered_count'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      startedAt: json['started_at'] as String? ?? '',
      lastActiveAt: json['last_active_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
    );
  }
}

class HistoryListResult {
  final int total;
  final int page;
  final int pageSize;
  final List<HistoryRecord> records;

  const HistoryListResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.records,
  });

  factory HistoryListResult.fromJson(Map<String, dynamic> json) {
    return HistoryListResult(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      records: (json['records'] as List<dynamic>? ?? [])
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HistoryAnswerOption {
  final int optionId;
  final String text;

  const HistoryAnswerOption({required this.optionId, required this.text});

  factory HistoryAnswerOption.fromJson(Map<String, dynamic> json) {
    return HistoryAnswerOption(
      optionId: json['option_id'] as int,
      text: json['text'] as String? ?? '',
    );
  }
}

// ── 單字測驗詳解 ──────────────────────────────────────────────────────────────

class QuizWordDetail {
  final int wordId;
  final String truku;
  final String zh;
  final String? en;
  final String? category;
  final String level;
  final String? audioUrl;
  final String? explanation;

  const QuizWordDetail({
    required this.wordId,
    required this.truku,
    required this.zh,
    required this.en,
    required this.category,
    required this.level,
    required this.audioUrl,
    required this.explanation,
  });

  factory QuizWordDetail.fromJson(Map<String, dynamic> json) {
    return QuizWordDetail(
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

class QuizHistoryResultItem {
  final String questionId;
  final int order;
  final String direction;
  final String prompt;
  final bool isCorrect;
  final HistoryAnswerOption yourAnswer;
  final HistoryAnswerOption correctAnswer;
  final QuizWordDetail wordDetail;

  const QuizHistoryResultItem({
    required this.questionId,
    required this.order,
    required this.direction,
    required this.prompt,
    required this.isCorrect,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.wordDetail,
  });

  factory QuizHistoryResultItem.fromJson(Map<String, dynamic> json) {
    return QuizHistoryResultItem(
      questionId: json['question_id'] as String,
      order: json['order'] as int? ?? 0,
      direction: json['direction'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      yourAnswer: HistoryAnswerOption.fromJson(
          json['your_answer'] as Map<String, dynamic>? ?? const {}),
      correctAnswer: HistoryAnswerOption.fromJson(
          json['correct_answer'] as Map<String, dynamic>? ?? const {}),
      wordDetail: QuizWordDetail.fromJson(
          json['word_detail'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class QuizHistoryDetail {
  final String sessionId;
  final int score;
  final int total;
  final String? completedAt;
  final List<QuizHistoryResultItem> results;

  const QuizHistoryDetail({
    required this.sessionId,
    required this.score,
    required this.total,
    required this.completedAt,
    required this.results,
  });

  factory QuizHistoryDetail.fromJson(Map<String, dynamic> json) {
    return QuizHistoryDetail(
      sessionId: json['session_id'] as String,
      score: json['score'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      completedAt: json['completed_at'] as String?,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => QuizHistoryResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── 聽力測驗詳解 ──────────────────────────────────────────────────────────────

class ListeningResultDetail {
  final String type; // 'word' | 'sentence'
  final int id;
  final String? truku;
  final String zh;
  final String? en;
  final String? category;
  final String level;
  final String? audioUrl;
  final String? explanation;
  final String? context;
  final String? source;

  const ListeningResultDetail({
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

  factory ListeningResultDetail.fromJson(Map<String, dynamic> json) {
    return ListeningResultDetail(
      type: json['type'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      truku: json['truku'] as String?,
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

class ListeningHistoryResultItem {
  final String questionId;
  final int order;
  final String? promptAudioUrl;
  final bool isCorrect;
  final HistoryAnswerOption yourAnswer;
  final HistoryAnswerOption correctAnswer;
  final ListeningResultDetail detail;

  const ListeningHistoryResultItem({
    required this.questionId,
    required this.order,
    required this.promptAudioUrl,
    required this.isCorrect,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.detail,
  });

  factory ListeningHistoryResultItem.fromJson(Map<String, dynamic> json) {
    return ListeningHistoryResultItem(
      questionId: json['question_id'] as String,
      order: json['order'] as int? ?? 0,
      promptAudioUrl: json['prompt_audio_url'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
      yourAnswer: HistoryAnswerOption.fromJson(
          json['your_answer'] as Map<String, dynamic>? ?? const {}),
      correctAnswer: HistoryAnswerOption.fromJson(
          json['correct_answer'] as Map<String, dynamic>? ?? const {}),
      detail: ListeningResultDetail.fromJson(
          json['detail'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class ListeningHistoryDetail {
  final String sessionId;
  final String mode;
  final int score;
  final int total;
  final String? completedAt;
  final List<ListeningHistoryResultItem> results;

  const ListeningHistoryDetail({
    required this.sessionId,
    required this.mode,
    required this.score,
    required this.total,
    required this.completedAt,
    required this.results,
  });

  factory ListeningHistoryDetail.fromJson(Map<String, dynamic> json) {
    return ListeningHistoryDetail(
      sessionId: json['session_id'] as String,
      mode: json['mode'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      completedAt: json['completed_at'] as String?,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) =>
              ListeningHistoryResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
