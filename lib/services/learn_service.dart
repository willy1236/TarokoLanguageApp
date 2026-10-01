import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/level_info.dart';
import '../models/quiz_models.dart';

class LearnService {
  static Future<List<LevelInfo>> fetchLevels() async {
    final json = await ApiClient.get('/api/levels');
    final list = ApiClient.unwrapList(json, 'levels');
    return list
        .cast<Map<String, dynamic>>()
        .where(
          (e) => e['code'] != null || e['label'] != null || e['level'] != null,
        )
        .map(LevelInfo.fromJson)
        .toList();
  }

  static Future<QuizSession> startQuiz(String level) async {
    final json = await ApiClient.post('/api/quiz/start', {'level': level});
    final data = ApiClient.unwrapData(json);
    return QuizSession.fromJson(data);
  }

  // 單題即時儲存作答，讓中途退出仍能在下次 /quiz/start 續接時還原。
  static Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required int selectedOptionId,
  }) async {
    await ApiClient.patch(ApiConfig.quizAnswer, {
      'session_id': sessionId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
    });
  }

  static Future<QuizResult> submitQuiz(
    String sessionId,
    List<QuizAnswer> answers,
  ) async {
    final json = await ApiClient.post('/api/quiz/submit', {
      'session_id': sessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return QuizResult.fromJson(data);
  }

  /// 放棄未完成的舊測驗。404 SESSION_NOT_FOUND 代表已經放棄過（例如網路重送），
  /// 視同成功；409 SESSION_ALREADY_COMPLETED 等其他錯誤照樣丟給呼叫端。
  static Future<void> abandonQuiz(String sessionId) async {
    try {
      await ApiClient.post(ApiConfig.quizAbandon, {'session_id': sessionId});
    } on ApiException catch (e) {
      if (!e.isSessionNotFound) rethrow;
    }
  }
}
