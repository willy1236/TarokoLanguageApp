import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/history_models.dart';

class HistoryService {
  static Future<HistoryListResult> fetchHistory({
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.historyList,
      query: {'type': ?type, 'page': '$page', 'page_size': '$pageSize'},
    );
    return HistoryListResult.fromJson(json);
  }

  static Future<QuizHistoryDetail> fetchQuizDetail(String sessionId) async {
    final json = await ApiClient.get('/api/history/quiz/$sessionId');
    return QuizHistoryDetail.fromJson(json);
  }

  static Future<ListeningHistoryDetail> fetchListeningDetail(
    String sessionId,
  ) async {
    final json = await ApiClient.get('/api/history/listening/$sessionId');
    return ListeningHistoryDetail.fromJson(json);
  }

  static Future<void> reportQuestion({
    required String questionType,
    required String sessionId,
    required String questionId,
    required String message,
  }) async {
    await ApiClient.post(ApiConfig.historyReport, {
      'question_type': questionType,
      'session_id': sessionId,
      'question_id': questionId,
      'message': message,
    });
  }
}
