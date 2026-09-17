// Widget 測試共用樣板。
//
// 背景：專案沒有 mock 套件，測試的兩個接縫是
//   1. HTTP 層：`ApiClient.httpClient` 換成 MockClient
//   2. callback 注入：像 ForumBoardView 那樣把載入函式當參數傳進去
// 這裡把每支測試原本各自複製貼上的 setUp/tearDown 收成一處。
//
// 既有 forum 測試維持原樣，不強制遷移。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';

/// 把待測 widget 包成可繪製的畫面。
/// 給固定高度是因為多數列表在無界高度下會拋 overflow，測的是內容不是版面。
Widget wrap(Widget child, {double height = 800, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: SizedBox(height: height, child: child)),
  );
}

/// 需要 Navigator 互動（push/pop、對話框後返回）時用這個，直接把 widget 當首頁。
Widget wrapScreen(Widget screen, {Map<String, WidgetBuilder>? routes}) {
  return MaterialApp(home: screen, routes: routes ?? const {});
}

/// flutter_secure_storage 在測試環境沒有原生實作。
/// ApiClient 會經 AuthService.currentToken() 讀它，不 stub 會炸 MissingPluginException。
///
/// 預設全部回 null，等同「未登入」—— 既有測試依賴這個預設，不要改。
/// 要測「已登入」的流程（例如 splash 的分支導流）才傳 [token]。
/// [expiresAt] 不給時 AuthService.isLoggedIn() 視為未過期（auth_service.dart:176-179）。
void stubSecureStorage({String? token, String? expiresAt}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (token == null && expiresAt == null) return null;
      final args = call.arguments;
      final key = args is Map ? args['key'] : null;
      if (key == 'session_token') return token;
      if (key == 'session_expires_at') return expiresAt;
      return null;
    },
  );
}

/// 吞掉指定 MethodChannel 的呼叫，回傳 [result]。
/// 給 audioplayers、vibration、url_launcher 這類「測試不關心、但不 stub 會炸」的外掛用。
void stubChannel(String name, {Object? result}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), (call) async => result);
}

/// 一次 stub 常見的平台外掛。只開需要的，避免掩蓋真正的缺漏。
void stubCommonChannels({
  bool secureStorage = true,
  bool audio = false,
  bool vibration = false,
  bool urlLauncher = false,
  String? token,
  String? expiresAt,
}) {
  if (secureStorage) stubSecureStorage(token: token, expiresAt: expiresAt);
  if (audio) {
    stubChannel('xyz.luan/audioplayers');
    stubChannel('xyz.luan/audioplayers.global');
  }
  if (vibration) stubChannel('vibration');
  if (urlLauncher) stubChannel('plugins.flutter.io/url_launcher');
}

/// 還原被換掉的 http client。每個用到 MockClient 的測試都要在 tearDown 呼叫。
void restoreHttp() => ApiClient.httpClient = http.Client();

/// 依 request path 分派假回應的 MockClient。
///
/// [routes] 的 key 是 path（例如 '/api/events'）。value 可以是：
///   - JSON body（Map/List）→ 回 200
///   - [http.Response]（用 [jsonResponse] / [errorResponse] 產生）→ 回指定狀態碼
/// 沒對到的 path 會讓測試失敗並印出是哪一支 —— 比靜默回空資料好抓問題。
/// [onRequest] 可用來記錄呼叫次數或檢查送出的內容。
/// [delayFor] 可以讓特定請求晚點才回應，用來重現「舊請求晚回、不該覆蓋新結果」
/// 這類人工幾乎測不到的競態。
void installMockClient(
  Map<String, Object?> routes, {
  void Function(http.Request request)? onRequest,
  Duration Function(http.Request request)? delayFor,
}) {
  ApiClient.httpClient = MockClient((request) async {
    onRequest?.call(request);
    final path = request.url.path;
    if (!routes.containsKey(path)) {
      fail('測試沒有為 $path 準備假回應（${request.method} ${request.url}）');
    }
    final delay = delayFor?.call(request);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final route = routes[path];
    return route is http.Response ? route : jsonResponse(route);
  });
}

/// 組一個帶 utf-8 的 JSON 回應。
/// 不指定 charset 的話 http.Response 會用 latin1 編碼，中文內容會丟例外。
http.Response jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// 組一個後端錯誤信封回應，例如 403 ACCOUNT_LOCKED。
http.Response errorResponse(String code, {int status = 400, String? message}) {
  return jsonResponse({
    'error': {'code': code, 'message': message ?? code},
  }, status: status);
}
