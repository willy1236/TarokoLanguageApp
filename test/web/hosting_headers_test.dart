// firebase.json 安全標頭的套用範圍：除了 Firebase Hosting 保留路徑 /__/（登入用的
// auth iframe 要能被主頁嵌入），其他路徑都要帶上。沒匹配到的路徑一樣會 rewrite
// 回 index.html，漏掉任何一種都等於整個 App 可以被 iframe 嵌入。
// 這個 regex 只用 RE2 與 Dart RegExp 行為一致的語法。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = jsonDecode(File('firebase.json').readAsStringSync()) as Map;
  final rules = ((config['hosting'] as Map)['headers'] as List).cast<Map>();
  final securityRule = rules.singleWhere(
    (r) => (r['headers'] as List).any(
      (h) => (h as Map)['key'] == 'Content-Security-Policy',
    ),
  );
  final pattern = RegExp(securityRule['regex'] as String);

  test('一般路徑都套用安全標頭', () {
    for (final path in [
      '/',
      '/_',
      '/__',
      '/_x',
      '/__x',
      '/___',
      '/index.html',
      '/privacy.html',
      '/vendor/hls.min.js',
      '/a/__/b',
      '//__/a',
    ]) {
      expect(pattern.hasMatch(path), isTrue, reason: path);
    }
  });

  test('Firebase 保留路徑 /__/ 不套用', () {
    for (final path in [
      '/__/',
      '/__/auth/iframe',
      '/__/auth/handler',
      '/__/firebase/init.js',
    ]) {
      expect(pattern.hasMatch(path), isFalse, reason: path);
    }
  });
}
