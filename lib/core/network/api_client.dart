// 通用 API client：帶 JWT 呼叫後端、統一錯誤處理。
// 供所有 service（learn / quiz / listening / profile…）共用，避免各自重複寫
// http 邏輯。token 讀取沿用既有的 AuthService.currentToken()。
//
// 規格書對應：API設計/資料交換表_核心.md（錯誤格式 {error:{code,message}}）

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import '../../main.dart';
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

  @override
  String toString() => message;
}

class ApiClient {
  static Future<Map<String, dynamic>> get(String path) async {
    final token = await AuthService.currentToken();
    final resp = await http.get(
      Uri.parse(ApiConfig.baseUrl + path),
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

  static Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await http.patch(
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
      final error = _parseError(resp);
      if (error.isUnauthorized) {
        _forceLogout();
      }
      throw error;
    }
    if (resp.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static bool _loggingOut = false;

  /// JWT 失效（401）時清 token 並導回登入畫面。
  /// 用 _loggingOut 防止同時多個請求 401 時重複觸發。
  static void _forceLogout() {
    if (_loggingOut) return;
    _loggingOut = true;
    AuthService.signOut().whenComplete(() {
      _loggingOut = false;
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
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
