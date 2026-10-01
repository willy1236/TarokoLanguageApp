import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/listening_models.dart';

class ListeningService {
  static Future<ListeningSession> startListening(
    String mode,
    String level,
  ) async {
    final json = await ApiClient.post(ApiConfig.listeningStart, {
      'mode': mode,
      'level': level,
    });
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return ListeningSession.fromJson(data);
  }

  static Future<void> answerListening(
    String sessionId,
    String questionId,
    int selectedOptionId,
  ) async {
    await ApiClient.patch(ApiConfig.listeningAnswer, {
      'session_id': sessionId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
    });
  }

  static Future<ListeningResult> submitListening(
    String sessionId,
    List<ListeningAnswer> answers,
  ) async {
    final json = await ApiClient.post(ApiConfig.listeningSubmit, {
      'session_id': sessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return ListeningResult.fromJson(data);
  }

  /// 放棄未完成的舊聽力測驗，只刪這一份，其他 mode 不受影響。
  /// 404 SESSION_NOT_FOUND 視同成功，其他錯誤照樣丟給呼叫端。
  static Future<void> abandonListening(String sessionId) async {
    try {
      await ApiClient.post(ApiConfig.listeningAbandon, {
        'session_id': sessionId,
      });
    } on ApiException catch (e) {
      if (!e.isSessionNotFound) rethrow;
    }
  }
}
