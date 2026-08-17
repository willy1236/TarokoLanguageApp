// 通用 API client：帶 JWT 呼叫後端、統一錯誤處理。
// 供所有 service（learn / quiz / listening / profile…）共用，避免各自重複寫
// http 邏輯。token 讀取沿用既有的 AuthService.currentToken()。
//
// 規格書對應：API設計/資料交換表_核心.md（錯誤格式 {error:{code,message}}）

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  bool get isSessionNotFound => code == 'SESSION_NOT_FOUND';
  bool get isSessionNotCompleted => code == 'SESSION_NOT_COMPLETED';
  bool get isIdentityLocked => code == 'IDENTITY_LOCKED';
  bool get isFileTooLarge => code == 'FILE_TOO_LARGE';
  bool get isInvalidFileType => code == 'INVALID_FILE_TYPE';

  @override
  String toString() => message;
}

class ApiClient {
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path).replace(
      queryParameters: query,
    );
    final resp = await _send(() => http.get(uri, headers: _headers(token)));
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await _send(() => http.post(
          Uri.parse(ApiConfig.baseUrl + path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await _send(() => http.patch(
          Uri.parse(ApiConfig.baseUrl + path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await http.delete(
      Uri.parse(ApiConfig.baseUrl + path),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(resp);
  }

  /// multipart/form-data 上傳（例如頭像）。不可帶 Content-Type: application/json，
  /// 交給 http.MultipartRequest 自行設定含 boundary 的 Content-Type。
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fieldName,
    required File file,
    String? contentType,
  }) async {
    final token = await AuthService.currentToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.baseUrl + path),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      file.path,
      contentType: contentType == null ? null : MediaType.parse(contentType),
    ));
    final resp = await _send(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    return _handle(resp);
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// 統一攔截離線（SocketException），轉成一致的 NETWORK_ERROR ApiException，
  /// 讓所有 service 不必各自 catch SocketException。
  static Future<http.Response> _send(
    Future<http.Response> Function() doRequest,
  ) async {
    try {
      return await doRequest();
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: '無法連線到伺服器，請檢查網路',
      );
    }
  }

  /// 後端回應有時包一層 {data:{...}}、有時直接回物件，統一在此解包。
  static Map<String, dynamic> unwrapData(Map<String, dynamic> json) =>
      (json['data'] as Map<String, dynamic>?) ?? json;

  /// 取回應中的清單欄位；相容 {key:[...]}、{data:[...]} 兩種格式。
  static List<dynamic> unwrapList(Map<String, dynamic> json, String key) =>
      json[key] as List<dynamic>? ?? (json['data'] as List<dynamic>? ?? []);

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
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('登入已過期，請重新登入')),
        );
    });
  }

  static ApiException _parseError(http.Response resp) {
    try {
      final j = jsonDecode(resp.body);
      final error = j['error'] as Map<String, dynamic>?;
      if (error == null) {
        debugPrint(
          'ApiClient: ${resp.statusCode} ${resp.request?.url} 回應無 error 欄位: ${resp.body}',
        );
      }
      return ApiException(
        statusCode: resp.statusCode,
        code: error?['code'] as String? ?? 'UNKNOWN',
        message: error?['message'] as String? ?? '發生未知錯誤',
      );
    } catch (e) {
      debugPrint(
        'ApiClient: ${resp.statusCode} ${resp.request?.url} 錯誤回應解析失敗 ($e): ${resp.body}',
      );
      return ApiException(
        statusCode: resp.statusCode,
        code: resp.statusCode == 401 ? 'UNAUTHORIZED' : 'UNKNOWN',
        message: resp.statusCode == 401 ? '請先登入' : '發生未知錯誤',
      );
    }
  }
}
