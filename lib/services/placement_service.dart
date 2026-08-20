// 對應 /api/quiz/placement/*、/api/listening/placement/*
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/placement_models.dart';

class PlacementService {
  static Future<QuizPlacementSession> startQuizPlacement() async {
    final json = await ApiClient.post(ApiConfig.quizPlacementStart);
    final data = ApiClient.unwrapData(json);
    return QuizPlacementSession.fromJson(data);
  }

  static Future<void> answerQuizPlacement({
    required String sessionId,
    required String questionId,
    required int selectedOptionId,
  }) async {
    await ApiClient.patch(ApiConfig.quizPlacementAnswer, {
      'session_id': sessionId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
    });
  }

  static Future<PlacementResult> submitQuizPlacement(
    String sessionId,
    List<PlacementAnswer> answers,
  ) async {
    final json = await ApiClient.post(ApiConfig.quizPlacementSubmit, {
      'session_id': sessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    final data = ApiClient.unwrapData(json);
    return PlacementResult.fromJson(data);
  }

  static Future<ListeningPlacementSession> startListeningPlacement() async {
    final json = await ApiClient.post(ApiConfig.listeningPlacementStart);
    final data = ApiClient.unwrapData(json);
    return ListeningPlacementSession.fromJson(data);
  }

  static Future<void> answerListeningPlacement({
    required String sessionId,
    required String questionId,
    required int selectedOptionId,
  }) async {
    await ApiClient.patch(ApiConfig.listeningPlacementAnswer, {
      'session_id': sessionId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
    });
  }

  static Future<PlacementResult> submitListeningPlacement(
    String sessionId,
    List<PlacementAnswer> answers,
  ) async {
    final json = await ApiClient.post(ApiConfig.listeningPlacementSubmit, {
      'session_id': sessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    final data = ApiClient.unwrapData(json);
    return PlacementResult.fromJson(data);
  }
}
