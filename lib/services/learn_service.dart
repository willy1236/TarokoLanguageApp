import '../core/network/api_client.dart';
import '../models/level_info.dart';
import '../models/quiz_models.dart';

class LearnService {
  static Future<List<LevelInfo>> fetchLevels() async {
    final json = await ApiClient.get('/api/levels');
    final list = json['levels'] as List<dynamic>? ?? (json['data'] as List<dynamic>? ?? []);
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => e['code'] != null || e['label'] != null || e['level'] != null)
        .map(LevelInfo.fromJson)
        .toList();
  }

  static Future<QuizSession> startQuiz(String level) async {
    final json = await ApiClient.post('/api/quiz/start', {'level': level});
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return QuizSession.fromJson(data);
  }

  static Future<QuizResult> submitQuiz(
    String sessionId,
    List<QuizAnswer> answers,
  ) async {
    final json = await ApiClient.post('/api/quiz/submit', {
      'session_id': sessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    return QuizResult.fromJson(json);
  }
}
