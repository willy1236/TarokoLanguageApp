// 讀取 test/fixtures/api/ 下由 api_inspector 錄製的真實後端回應。
//
// fixture 怎麼來：見 integration_test/api_inspector_test.dart 檔頭與
// tool/extract_fixtures.dart。這裡只負責讀，不負責產。

import 'dart:convert';
import 'dart:io';

const String fixtureDir = 'test/fixtures/api';

/// fixture 是否存在。沒有錄製過的端點，測試應該 skip 而不是假裝通過。
bool hasFixture(String name) => File('$fixtureDir/$name').existsSync();

/// 讀一個 fixture 並解析成 JSON。
dynamic loadFixture(String name) {
  final file = File('$fixtureDir/$name');
  if (!file.existsSync()) {
    throw StateError(
      '找不到 fixture $name。請先錄製：\n'
      '  flutter test integration_test/api_inspector_test.dart -d <device> '
      '--dart-define=RECORD_FIXTURES=true > fixtures.log\n'
      '  dart run tool/extract_fixtures.dart fixtures.log',
    );
  }
  return jsonDecode(file.readAsStringSync());
}

/// 讀成 JSON object。
Map<String, dynamic> loadFixtureMap(String name) =>
    loadFixture(name) as Map<String, dynamic>;

/// 讀出某個 key 底下的清單（例如 events / videos / items）。
List<Map<String, dynamic>> loadFixtureList(String name, String key) {
  final json = loadFixtureMap(name);
  final list = json[key] as List<dynamic>? ?? const [];
  return list.cast<Map<String, dynamic>>();
}
