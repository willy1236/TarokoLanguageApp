// 登出與啟動還原的本機狀態。
//
// 測試環境沒有初始化 Firebase，Google／Firebase 登出一定丟例外——正好用來驗
// 「登出丟例外時 JWT 仍已刪除，重開 App 是登出狀態」。

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('token 有效回 true，不動本機狀態', () async {
      final store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': future,
      });

      expect(await SessionService.restore(), isTrue);
      expect(store['session_token'], 'jwt');
    });

    test('沒有 token 回 false', () async {
      stubStatefulSecureStorage({});
      expect(await SessionService.restore(), isFalse);
    });

    test('token 過期且續期失敗（Firebase 未登入）：完整登出後回 false', () async {
      final store = stubStatefulSecureStorage({
        'session_token': 'jwt',
        'session_expires_at': past,
      });

      expect(await SessionService.restore(), isFalse);
      expect(store, isEmpty);
    });
  });
}
