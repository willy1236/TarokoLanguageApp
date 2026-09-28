// web/flutter_bootstrap.js 自己載入 Firebase JS SDK（避開 CSP 擋下的 inline
// script）。FlutterFire 升級或新增 Firebase 套件時，這裡提醒同步更新：
// 版本不一致會載到未經 FlutterFire 測試的 SDK；少載一個服務，Web 版用到時才出錯。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 從 .dart_tool/package_config.json 找出套件根目錄。
Map<String, Directory> _packageRoots() {
  final configFile = File('.dart_tool/package_config.json');
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  return {
    for (final p in (config['packages'] as List).cast<Map>())
      p['name'] as String: Directory.fromUri(
        configFile.absolute.uri.resolve(p['rootUri'] as String),
      ),
  };
}

void main() {
  final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
  final roots = _packageRoots();

  test('預先載入的 SDK 版本與 firebase_core_web 支援的版本一致', () {
    final versionFile = File(
      '${roots['firebase_core_web']!.path}/lib/src/firebase_sdk_version.dart',
    );
    final supported = RegExp(
      r"supportedFirebaseJsSdkVersion = '([^']+)'",
    ).firstMatch(versionFile.readAsStringSync())!.group(1);
    final preloaded = RegExp(
      r"firebaseJsSdkVersion = '([^']+)'",
    ).firstMatch(bootstrap)!.group(1);

    expect(preloaded, supported);
  });

  test('每個 firebase_*_web 套件的 SDK 模組都有預先載入', () {
    final services = roots.keys
        .where((n) => n.startsWith('firebase_') && n.endsWith('_web'))
        .where((n) => n != 'firebase_core_web')
        .map((n) => n.substring(0, n.length - '_web'.length));

    for (final windowVar in services) {
      expect(
        bootstrap,
        contains('window.$windowVar ='),
        reason: '$windowVar 沒有在 web/flutter_bootstrap.js 預先載入',
      );
    }
  });
}
