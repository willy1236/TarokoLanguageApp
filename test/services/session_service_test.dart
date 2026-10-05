// 登出與啟動還原的本機狀態。
//
// 測試環境沒有初始化 Firebase，Google／Firebase 登出一定丟例外——正好用來驗
// 「登出丟例外時 JWT 仍已刪除，重開 App 是登出狀態」。

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/session_service.dart';

/// 以 Map 模擬 flutter_secure_storage，讀寫刪都作用在 [store]。
Map<String, String> stubStatefulSecureStorage(Map<String, String> initial) {
  final store = Map<String, String>.of(initial);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return store[key];
            case 'write':
              store[key!] = args['value'] as String;
              return null;
            case 'delete':
              store.remove(key);
              return null;
          }
          return null;
        },
      );
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final past = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String();
  final future = DateTime.now().add(const Duration(days: 1)).toIso8601String();

  final realRefresh = SessionService.refreshSession;
  final realUnregister = SessionService.unregisterDeviceToken;
  final realDeleteLocal = SessionService.deleteLocalToken;
  final realClearAuth = SessionService.clearAuth;
  tearDown(() {
    SessionService.refreshSession = realRefresh;
    SessionService.unregisterDeviceToken = realUnregister;
    SessionService.deleteLocalToken = realDeleteLocal;
    SessionService.clearAuth = realClearAuth;
  });

  test('AuthService.signOut：Google／Firebase 登出丟例外時，JWT 仍已刪除', () async {
    final store = stubStatefulSecureStorage({
      'session_token': 'jwt',
      'session_expires_at': future,
    });

    await AuthService.signOut();

    expect(store, isEmpty);
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('AuthService.isLoggedIn：過期只回 false，不清 token', () async {
    final store = stubStatefulSecureStorage({
      'session_token': 'jwt',
      'session_expires_at': past,
    });

    expect(await AuthService.isLoggedIn(), isFalse);
    expect(store['session_token'], 'jwt');
  });

  group('SessionService.restore', () {
    test('token 有效回 loggedIn，不動本機狀態', () async {
      final store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': future,
      });

      expect(await SessionService.restore(), RestoreResult.loggedIn);
      expect(store['session_token'], 'jwt');
    });

    test('沒有 token 回 loggedOut', () async {
      stubStatefulSecureStorage({});
      expect(await SessionService.restore(), RestoreResult.loggedOut);
    });

    test('token 過期且續期失敗（Firebase 未登入）：完整登出後回 loggedOut', () async {
      final store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': past,
      });

      expect(await SessionService.restore(), RestoreResult.loggedOut);
      expect(store, isEmpty);
    });
  });

  test('token 過期但續期成功：回 loggedIn，不登出', () async {
    stubStatefulSecureStorage({
      'session_token': 'jwt',
      'session_expires_at': past,
    });
    var signedOut = false;
    SessionService.refreshSession = () async => RefreshOutcome.ok;
    SessionService.clearAuth = () async => signedOut = true;
    SessionService.deleteLocalToken = () async => signedOut = true;

    expect(await SessionService.restore(), RestoreResult.loggedIn);
    expect(signedOut, isFalse);
  });

  group('token 過期且續期失敗', () {
    late Map<String, String> store;
    late List<String> calls;

    setUp(() {
      store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': past,
      });
      calls = [];
      SessionService.unregisterDeviceToken = () async =>
          calls.add('unregister');
      SessionService.deleteLocalToken = () async => calls.add('deleteLocal');
      SessionService.clearAuth = () async {
        calls.add('clearAuth');
        await realClearAuth();
      };
    });

    test('連不上：回 offline，不登出 Firebase、不刪 FCM token、JWT 保留', () async {
      SessionService.refreshSession = () async => RefreshOutcome.offline;

      expect(await SessionService.restore(), RestoreResult.offline);
      expect(calls, isEmpty);
      expect(store['session_token'], 'jwt');
    });

    test('連不上後網路恢復：再呼叫一次續期成功就回 loggedIn', () async {
      var outcome = RefreshOutcome.offline;
      SessionService.refreshSession = () async => outcome;

      expect(await SessionService.restore(), RestoreResult.offline);
      outcome = RefreshOutcome.ok;
      expect(await SessionService.restore(), RestoreResult.loggedIn);
      expect(calls, isEmpty);
    });

    test('被拒絕：只刪本機 FCM token、完整登出後回 loggedOut', () async {
      SessionService.refreshSession = () async => RefreshOutcome.rejected;

      expect(await SessionService.restore(), RestoreResult.loggedOut);
      expect(calls, ['deleteLocal', 'clearAuth']);
      expect(store, isEmpty);
    });
  });

  group('AuthService.refreshOutcomeFor', () {
    final cases = <String, (Object, RefreshOutcome)>{
      '連不上伺服器的 AuthException': (
        AuthException.network(),
        RefreshOutcome.offline,
      ),
      '逾時': (TimeoutException('x'), RefreshOutcome.offline),
      'SocketException': (const SocketException('x'), RefreshOutcome.offline),
      'TLS 交握失敗': (const HandshakeException('x'), RefreshOutcome.offline),
      'http.ClientException': (
        http.ClientException('x'),
        RefreshOutcome.offline,
      ),
      'Firebase 換 ID token 時沒網路': (
        FirebaseAuthException(code: 'network-request-failed'),
        RefreshOutcome.offline,
      ),
      '後端拒絕（帳號狀態不允許）': (AuthException('帳號已停用'), RefreshOutcome.rejected),
      '取不到 Firebase token': (
        AuthException('取得 Firebase token 失敗'),
        RefreshOutcome.rejected,
      ),
      'Firebase 帳號已失效': (
        FirebaseAuthException(code: 'user-token-expired'),
        RefreshOutcome.rejected,
      ),
      '未預期的錯誤': (StateError('x'), RefreshOutcome.rejected),
    };
    cases.forEach((name, c) {
      test('$name → ${c.$2.name}', () {
        expect(AuthService.refreshOutcomeFor(c.$1), c.$2);
      });
    });
  });

  group('SessionService.signOut 順序', () {
    late Map<String, String> store;
    late List<String> calls;

    setUp(() {
      store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': future,
      });
      calls = [];
      SessionService.unregisterDeviceToken = () async {
        // 註銷要帶 JWT，此時 token 必須還在。
        calls.add('unregister:${store['session_token']}');
      };
      SessionService.deleteLocalToken = () async => calls.add('deleteLocal');
      SessionService.clearAuth = () async {
        calls.add('clearAuth');
        await realClearAuth();
      };
    });

    test('一般登出：先帶 JWT 註銷裝置，再清 JWT', () async {
      await SessionService.signOut();
      expect(calls, ['unregister:jwt', 'clearAuth']);
      expect(store, isEmpty);
    });

    test('強制登出：只刪本機 FCM token，不打註銷', () async {
      await SessionService.signOut(unregisterDevice: false);
      expect(calls, ['deleteLocal', 'clearAuth']);
      expect(store, isEmpty);
    });

    test('註銷丟例外仍清掉 JWT', () async {
      SessionService.unregisterDeviceToken = () async => throw Exception('x');
      await SessionService.signOut();
      expect(calls, ['clearAuth']);
      expect(store, isEmpty);
    });
  });
}
