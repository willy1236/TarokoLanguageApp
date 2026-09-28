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
  final regex = securityRule['regex'] as String;
  // 部分比對與整串比對都要成立，不依賴 Hosting 用哪一種。
  bool applies(String path) {
    final partial = RegExp(regex).hasMatch(path);
    final whole = RegExp('^(?:$regex)\$').hasMatch(path);
    expect(partial, whole, reason: '$path 在部分比對與整串比對下結果不同');
    return partial;
  }

  test('T-12 的四個安全標頭都在同一條規則，套用範圍一致', () {
    final keys = (securityRule['headers'] as List)
        .map((h) => (h as Map)['key'])
        .toSet();
    expect(
      keys,
      containsAll([
        'X-Frame-Options',
        'X-Content-Type-Options',
        'Referrer-Policy',
        'Content-Security-Policy',
      ]),
    );
  });

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
      '/?a=1',
      '/__?a=1',
    ]) {
      expect(applies(path), isTrue, reason: path);
    }
  });

  test('Firebase 保留路徑 /__/ 不套用', () {
    for (final path in [
      '/__/',
      '/__/auth/iframe',
      '/__/auth/handler',
      '/__/firebase/init.js',
      '/__/__',
    ]) {
      expect(applies(path), isFalse, reason: path);
    }
  });
}
