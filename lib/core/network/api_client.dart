// 通用 API client：帶 JWT 呼叫後端、統一錯誤處理。
// 供所有 service（learn / quiz / listening / profile…）共用，避免各自重複寫
// http 邏輯。token 讀取沿用既有的 AuthService.currentToken()。
//
// 規格書對應：API設計/資料交換表_核心.md（錯誤格式 {error:{code,message}}）

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import '../../services/auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isSessionNotFound => code == 'SESSION_NOT_FOUND';
  bool get isSessionNotCompleted => code == 'SESSION_NOT_COMPLETED';

  @override
  String toString() => message;
}

class ApiClient {
  static Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path)
        .replace(queryParameters: query);
    final resp = await http.get(
      uri,
      headers: _headers(token),
    );
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await http.post(
      Uri.parse(ApiConfig.baseUrl + path),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(resp);
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _handle(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw _parseError(resp);
    }
    if (resp.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static ApiException _parseError(http.Response resp) {
    try {
      final j = jsonDecode(resp.body);
      final error = j['error'] as Map<String, dynamic>?;
      return ApiException(
        statusCode: resp.statusCode,
        code: error?['code'] as String? ?? 'UNKNOWN',
        message: error?['message'] as String? ?? '發生未知錯誤',
      );
    } catch (_) {
      return ApiException(
        statusCode: resp.statusCode,
        code: resp.statusCode == 401 ? 'UNAUTHORIZED' : 'UNKNOWN',
        message: resp.statusCode == 401 ? '請先登入' : '發生未知錯誤',
      );
    }
  }
}
