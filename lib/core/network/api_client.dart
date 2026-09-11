// 通用 API client：帶 JWT 呼叫後端、統一錯誤處理。
// 供所有 service（learn / quiz / listening / profile…）共用，避免各自重複寫
// http 邏輯。token 讀取沿用既有的 AuthService.currentToken()。
//
// 規格書對應：API設計/資料交換表_核心.md（錯誤格式 {error:{code,message}}）

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api.dart';
import '../../main.dart';
import '../../services/auth_service.dart';

/// multipart 的單一檔案。bytes 由呼叫端準備好（論壇附圖在 App 端壓縮後上傳，
/// 後端不做伺服器端壓縮），mimeType 必填——後端 multer 以它過濾檔案類型。
class MultipartFileData {
  final String field;
  final List<int> bytes;
  final String filename;
  final String mimeType;

  const MultipartFileData({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}

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
  bool get isRateLimited => statusCode == 429;
  bool get isConsentRequired => code == 'CONSENT_REQUIRED';
  bool get isSessionNotFound => code == 'SESSION_NOT_FOUND';
  bool get isSessionNotCompleted => code == 'SESSION_NOT_COMPLETED';
  bool get isVideoUnavailable =>
      statusCode == 503 && code == 'VIDEO_UNAVAILABLE';
  bool get isVideoNicknameRequired =>
      statusCode == 403 && code == 'VIDEO_NICKNAME_REQUIRED';
  bool get isSessionEnded => code == 'SESSION_ENDED';
  bool get isIdentityLocked => code == 'IDENTITY_LOCKED';
  bool get isFileTooLarge => code == 'FILE_TOO_LARGE';
  bool get isInvalidFileType => code == 'INVALID_FILE_TYPE';
  bool get isQuestionNotFound => code == 'QUESTION_NOT_FOUND';

  // 好友/聊天/通話（見 Truku_backend backend/routes/friends.ts、friendCalls.ts、friendMessages.ts）
  bool get isAlreadyFriends => code == 'ALREADY_FRIENDS';
  bool get isRequestAlreadySent => code == 'REQUEST_ALREADY_SENT';
  bool get isBlocked => code == 'BLOCKED';
  bool get isNotFriends => code == 'NOT_FRIENDS';
  bool get isMuted => code == 'MUTED';
  bool get isCalleeBusy => code == 'CALLEE_BUSY';
  bool get isAlreadyInCall => code == 'ALREADY_IN_CALL';
  bool get isCallNotRinging => code == 'CALL_NOT_RINGING';
  bool get isNeedFriend => code == 'NEED_FRIEND';
  bool get isProfanity => code == 'PROFANITY';

  @override
  String toString() => message;
}

/// 畫面上常見的「錯誤是不是因為未登入」判斷，統一隱藏 `is ApiException` 轉型。
bool isAuthError(Object? error) => error is ApiException && error.isUnauthorized;

/// 給使用者看的錯誤文案：後端 [ApiException] 已是中文訊息直接用，
/// 其他（程式錯誤、型別錯誤）不外露原始內容，改顯示 [fallback]。
String apiErrorMessage(Object? error, {String fallback = '發生錯誤，請稍後再試'}) =>
    error is ApiException && error.message.isNotEmpty ? error.message : fallback;

class ApiClient {
  /// 傳輸層。正式執行時是預設的 http client；測試可換成 MockClient。
  /// 換成可注入的原因：service 的端點、query、multipart 組成需要在沒有網路的
  /// 情況下驗證，直接呼叫 http 頂層函式無法做到。
  static http.Client httpClient = http.Client();

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(
      ApiConfig.baseUrl + path,
    ).replace(queryParameters: query);
    final resp = await _send(
      () => httpClient.get(uri, headers: _headers(token)),
      method: 'GET',
      url: uri,
    );
    return _handle(resp);
  }

  /// 取回非 JSON 回應的原始文字內容（例如 CSV 匯出），錯誤處理沿用 [_handle]
  /// 的狀態碼判斷，但成功時不做 jsonDecode，直接回傳 body 原文。
  static Future<String> getRaw(String path) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path);
    final resp = await _send(
      () => httpClient.get(uri, headers: _headers(token)),
      method: 'GET',
      url: uri,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final error = _parseError(resp);
      if (error.isUnauthorized) _forceLogout();
      throw error;
    }
    return resp.body;
  }

  static Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path);
    final encodedBody = body == null ? null : jsonEncode(body);
    final resp = await _send(
      () => httpClient.post(uri, headers: _headers(token), body: encodedBody),
      method: 'POST',
      url: uri,
      body: encodedBody,
    );
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path);
    final encodedBody = body == null ? null : jsonEncode(body);
    final resp = await _send(
      () => httpClient.patch(uri, headers: _headers(token), body: encodedBody),
      method: 'PATCH',
      url: uri,
      body: encodedBody,
    );
    return _handle(resp);
  }

  /// multipart 送出。文字欄位與檔案一併送，供發文（文字 + 最多 4 張附圖）使用。
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFileData> files,
  }) async {
    return _sendMultipart(
      path,
      fields: fields,
      files: [
        for (final file in files)
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
            contentType: MediaType.parse(file.mimeType),
          ),
      ],
      logBody: 'fields=$fields, files=${files.map((f) => f.filename).toList()}',
    );
  }

  static Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path);
    final encodedBody = body == null ? null : jsonEncode(body);
    final resp = await _send(
      () => httpClient.delete(uri, headers: _headers(token), body: encodedBody),
      method: 'DELETE',
      url: uri,
      body: encodedBody,
    );
    return _handle(resp);
  }

  /// multipart/form-data 上傳（例如頭像）。不可帶 Content-Type: application/json，
  /// 交給 http.MultipartRequest 自行設定含 boundary 的 Content-Type。
  static Future<Map<String, dynamic>> postMultipartFile(
    String path, {
    required String fieldName,
    required File file,
    String? contentType,
  }) async {
    return _sendMultipart(
      path,
      files: [
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: contentType == null ? null : MediaType.parse(contentType),
        ),
      ],
      // 只記檔名與大小，不記完整本機路徑（可能含使用者名稱）。
      logBody: 'field=$fieldName, file=${file.uri.pathSegments.last} (${file.lengthSync()} bytes)',
    );
  }

  /// multipart POST 的共用骨架：組 request、帶 Authorization、走 [_send] 與
  /// [_handle]。[logBody] 是給 log 用的摘要，不要放檔案內容或完整路徑。
  static Future<Map<String, dynamic>> _sendMultipart(
    String path, {
    Map<String, String> fields = const {},
    required List<http.MultipartFile> files,
    required String logBody,
  }) async {
    final token = await AuthService.currentToken();
    final uri = Uri.parse(ApiConfig.baseUrl + path);
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.addAll(files);
    final resp = await _send(
      () async => http.Response.fromStream(await httpClient.send(request)),
      method: 'POST(multipart)',
      url: uri,
      body: logBody,
    );
    return _handle(resp);
  }

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// debug log 會外流的敏感欄位：個資（email、族群身分、部落名、公開暱稱、
  /// 聯絡方式）與各類憑證。這些即使在 debug build 也不該出現在 log 原文。
  static const List<String> _sensitiveKeys = [
    'email',
    'contact_email',
    'contact_phone',
    'phone',
    'password',
    'token',
    'id_token',
    'access_token',
    'refresh_token',
    'rtc_token',
    'fcm_token',
    'app_id',
    'video_nickname',
    'ethnic_group',
    'is_indigenous',
    'tribal_name',
    'display_name',
  ];

  /// 把 JSON 字串中敏感欄位的值換成 ***。只在 debug log 路徑上使用，
  /// 不影響實際送出的 body。
  static String _redact(String body) {
    var out = body;
    for (final key in _sensitiveKeys) {
      out = out
          // 字串值："email":"a@b.c"
          .replaceAll(RegExp('"$key"\\s*:\\s*"[^"]*"'), '"$key":"***"')
          // 非字串值（數字/bool/null）："is_indigenous":true
          .replaceAll(
            RegExp('"$key"\\s*:\\s*(?!")[^,}\\]]+'),
            '"$key":***',
          );
    }
    return out;
  }

  /// 只留 scheme+host+path，去掉可能含搜尋關鍵字或 id 的 query。
  static String _safeUrl(Object? url) {
    if (url is Uri) return '${url.origin}${url.path}';
    return url?.toString().split('?').first ?? '';
  }

  /// debugPrint 在 release build 仍會寫進系統 log（adb logcat 可讀），
  /// 所以 body 這類含個資的內容必須自己用 kDebugMode 擋掉。
  static void _logVerbose(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// 統一攔截離線（SocketException），轉成一致的 NETWORK_ERROR ApiException，
  /// 讓所有 service 不必各自 catch SocketException。
  /// method/url/body 僅用於 debug log，不影響實際請求。
  static Future<http.Response> _send(
    Future<http.Response> Function() doRequest, {
    String? method,
    Object? url,
    String? body,
  }) async {
    _logVerbose(
      'ApiClient →  $method $url${body != null ? '\n  body: ${_redact(body)}' : ''}',
    );
    try {
      final resp = await doRequest();
      if (kDebugMode) {
        debugPrint(
          'ApiClient ←  ${resp.statusCode} $method $url\n  body: ${_redact(resp.body)}',
        );
      } else {
        // release 只保留狀態碼與路徑，足以定位問題且不外洩內容。
        debugPrint('ApiClient ←  ${resp.statusCode} $method ${_safeUrl(url)}');
      }
      return resp;
    } on SocketException {
      debugPrint('ApiClient ←  NETWORK_ERROR $method ${_safeUrl(url)}');
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
      } else if (error.isConsentRequired &&
          resp.request?.url.path != '/api/terms' &&
          resp.request?.url.path != '/api/terms/consent') {
        _forceConsent();
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
        ..showSnackBar(const SnackBar(content: Text('登入已過期，請重新登入')));
    });
  }

  static bool _showingConsent = false;

  /// CONSENT_REQUIRED（403）時導去強制同意畫面。
  /// 用 _showingConsent 防止同時多個請求 403 時重複觸發。
  static void _forceConsent() {
    if (_showingConsent) return;
    _showingConsent = true;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _showingConsent = false;
      return;
    }
    nav
        .pushNamed('/terms-consent')
        .whenComplete(() => _showingConsent = false);
  }

  static ApiException _parseError(http.Response resp) {
    // 全域速率限制（每 IP 每分鐘 200 次、上傳類 15 次）：訊息統一換成固定文案，
    // 不做自動重試——429 當下立刻重打只會讓限流更嚴重，交給使用者自己重試。
    if (resp.statusCode == 429) {
      return ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: '操作太頻繁，請稍後再試',
      );
    }
    try {
      final j = jsonDecode(resp.body);
      final error = j['error'] as Map<String, dynamic>?;
      if (error == null) {
        _logVerbose(
          'ApiClient: ${resp.statusCode} ${_safeUrl(resp.request?.url)} 回應無 error 欄位: ${_redact(resp.body)}',
        );
      }
      return ApiException(
        statusCode: resp.statusCode,
        code: error?['code'] as String? ?? 'UNKNOWN',
        message: error?['message'] as String? ?? '發生未知錯誤',
      );
    } catch (e) {
      _logVerbose(
        'ApiClient: ${resp.statusCode} ${_safeUrl(resp.request?.url)} 錯誤回應解析失敗 ($e): ${_redact(resp.body)}',
      );
      return ApiException(
        statusCode: resp.statusCode,
        code: resp.statusCode == 401 ? 'UNAUTHORIZED' : 'UNKNOWN',
        message: resp.statusCode == 401 ? '請先登入' : '發生未知錯誤',
      );
    }
  }
}
