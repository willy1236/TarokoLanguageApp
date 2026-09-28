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

/// FlutterFire Web 套件向 firebase_core_web 註冊的服務：`registerService` 的
/// 第一個參數決定 SDK 檔名，`productNameOverride` 決定掛到哪個 window 變數。
({String file, String windowVar})? _registeredService(Directory packageRoot) {
  final pattern = RegExp(
    r"registerService\(\s*'([^']+)'(?:\s*,\s*productNameOverride:\s*'([^']+)')?",
  );
  for (final file in Directory(
    '${packageRoot.path}/lib',
  ).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final match = pattern.firstMatch(file.readAsStringSync());
    if (match == null) continue;
    final name = match.group(1)!;
    return (
      // 與 firebase_core_web 的 injectService 相同：Firestore 載的是 pipelines 版。
      file: name == 'firestore'
          ? 'firebase-firestore-pipelines.js'
          : 'firebase-$name.js',
      windowVar: 'firebase_${match.group(2) ?? name}',
    );
  }
  return null;
}

void main() {
  // 去掉註解，避免只寫在註解裡的字串也算數。行尾註解只認前面是空白的 //，
  // 網址裡的 https:// 不受影響。
  final bootstrap = File('web/flutter_bootstrap.js')
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'(^|\s)//.*$', multiLine: true), '');
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

  test('每個 FlutterFire Web 套件的 SDK 模組都以正確檔名預先載入', () {
    // firebase_auth_web、cloud_firestore_web 這類套件都向 firebase_core_web 註冊。
    final packages = roots.keys.where(
      (n) =>
          n.endsWith('_web') &&
          n != 'firebase_core_web' &&
          (n.startsWith('firebase_') || n.startsWith('cloud_')),
    );
    expect(packages, isNotEmpty);

    for (final package in packages) {
      final service = _registeredService(roots[package]!);
      expect(
        service,
        isNotNull,
        reason: '$package 找不到 registerService，FlutterFire 的註冊方式可能改了',
      );
      expect(
        bootstrap,
        contains('\${base}${service!.file}'),
        reason: '$package：web/flutter_bootstrap.js 沒有載入 ${service.file}',
      );
      expect(
        bootstrap,
        contains('window.${service.windowVar} ='),
        reason:
            '$package：web/flutter_bootstrap.js 沒有設定 window.${service.windowVar}',
      );
    }
  });
}
