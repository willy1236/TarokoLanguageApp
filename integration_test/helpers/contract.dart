// ignore_for_file: avoid_print
//
// API 契約測試工具：形狀斷言 + fixture 錄製。
//
// 為什麼錄製走 stdout 而不是直接寫檔：整合測試跑在裝置／模擬器上，
// dart:io 寫出來的檔案會落在裝置的檔案系統，開發機看不到。
// 因此這裡把（遮罩後的）回應以標記包起來印到 stdout，
// 再由開發機上的 tool/extract_fixtures.dart 從測試輸出還原成 fixture 檔。
//
// 錄製流程：
//   flutter test integration_test/api_inspector_test.dart -d <device> \
//       --dart-define=RECORD_FIXTURES=true > fixtures.log
//   dart run tool/extract_fixtures.dart fixtures.log

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'pii_mask.dart';

export 'pii_mask.dart' show maskPii, kStringMasks;

/// 是否處於 fixture 錄製模式。
const bool kRecordFixtures = bool.fromEnvironment('RECORD_FIXTURES');

const String fixtureBegin = '<<<FIXTURE';
const String fixtureEnd = 'FIXTURE>>>';

// ---------------------------------------------------------------
// 形狀斷言
// ---------------------------------------------------------------

/// 一個欄位的期望型別。用 enum 而非 dart Type，因為 JSON 解出來的
/// 型別組合有限，且要能表達「可為 null」與「數字不分 int/double」。
enum F {
  string,
  number,
  boolean,
  list,
  object,
  /// 型別不拘，只要 key 存在（值可以是 null）。
  any,
}

bool _matches(F type, Object? value) {
  switch (type) {
    case F.string:
      return value is String;
    case F.number:
      return value is num;
    case F.boolean:
      return value is bool;
    case F.list:
      return value is List;
    case F.object:
      return value is Map;
    case F.any:
      return true;
  }
}

String _typeName(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'string';
  if (value is num) return 'number';
  if (value is bool) return 'boolean';
  if (value is List) return 'list';
  if (value is Map) return 'object';
  return value.runtimeType.toString();
}

/// 檢查 [json] 具備 [spec] 指定的必要欄位與型別。
///
/// 設計取捨：
///   - 缺欄位或型別不符 → 失敗（後端拿掉／改型別會打壞 app）。
///   - [nullable] 列出的欄位允許值為 null，但 key 仍須存在。
///   - [optional] 列出的欄位可以整個不存在；存在時仍檢查型別。
///   - 多出來的欄位只印提醒不失敗（後端加欄位不該讓測試變紅）。
void expectShape(
  Object? json,
  Map<String, F> spec, {
  Set<String> nullable = const {},
  Map<String, F> optional = const {},
  String label = '',
}) {
  final where = label.isEmpty ? '' : '[$label] ';
  expect(json, isA<Map<String, dynamic>>(),
      reason: '$where' '預期是 JSON object，實際是 ${_typeName(json)}');
  final map = json as Map<String, dynamic>;

  spec.forEach((key, type) {
    expect(map.containsKey(key), isTrue, reason: '$where缺少必要欄位 "$key"');
    final value = map[key];
    if (value == null) {
      expect(nullable.contains(key), isTrue,
          reason: '$where欄位 "$key" 不應為 null');
      return;
    }
    expect(_matches(type, value), isTrue,
        reason: '$where欄位 "$key" 型別應為 ${type.name}，'
            '實際是 ${_typeName(value)}');
  });

  optional.forEach((key, type) {
    if (!map.containsKey(key)) return;
    final value = map[key];
    if (value == null) return;
    expect(_matches(type, value), isTrue,
        reason: '$where選填欄位 "$key" 型別應為 ${type.name}，'
            '實際是 ${_typeName(value)}');
  });

  final known = {...spec.keys, ...optional.keys};
  final extra = map.keys.where((k) => !known.contains(k)).toList();
  if (extra.isNotEmpty) {
    print('（提醒）$where後端多回了未納入契約的欄位：${extra.join(', ')}');
  }
}

/// 對清單型回應的每一筆做 [expectShape]。空清單直接通過（資料庫可能就是空的）。
void expectEachShape(
  Object? list,
  Map<String, F> spec, {
  Set<String> nullable = const {},
  Map<String, F> optional = const {},
  String label = '',
}) {
  expect(list, isA<List>(),
      reason: '[$label] 預期是 JSON array，實際是 ${_typeName(list)}');
  final items = list as List;
  for (var i = 0; i < items.length; i++) {
    expectShape(
      items[i],
      spec,
      nullable: nullable,
      optional: optional,
      label: label.isEmpty ? '[$i]' : '$label[$i]',
    );
  }
}

/// 驗錯誤信封 `{error: {code, message}}`。
void expectErrorShape(http.Response response, {String? code}) {
  final decoded = jsonDecode(response.body);
  expectShape(decoded, {'error': F.object}, label: 'error envelope');
  final error = (decoded as Map<String, dynamic>)['error'];
  expectShape(error, {'code': F.string, 'message': F.string},
      optional: {'retry_after': F.number, 'mute_until': F.string},
      label: 'error');
  if (code != null) {
    expect((error as Map<String, dynamic>)['code'], code,
        reason: '錯誤碼不符');
  }
}


// ---------------------------------------------------------------
// Fixture 錄製
// ---------------------------------------------------------------

/// 由 method + path 產生 fixture 檔名，例如 GET /api/me → get_api_me.json。
/// query string 會被壓成後綴，讓 `?sort=popular` 這種變體各自成檔。
String fixtureName(String method, String path) {
  final parts = path.split('?');
  var slug = '${method.toLowerCase()}_${parts.first}';
  if (parts.length > 1 && parts[1].isNotEmpty) {
    slug = '${slug}__${parts[1]}';
  }
  slug = slug
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return '$slug.json';
}

/// 把回應以標記包起來印到 stdout，供 tool/extract_fixtures.dart 取出。
/// 只在 [kRecordFixtures] 為 true 時作用；非 2xx 不錄（不要把錯誤當成契約基準）。
void recordFixture(
  String method,
  String path,
  http.Response response, {
  String? as,
}) {
  if (!kRecordFixtures) return;
  if (response.statusCode < 200 || response.statusCode >= 300) return;
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    return; // 非 JSON（例如 CSV 匯出）不錄
  }
  final masked = maskPii(decoded);
  print('$fixtureBegin ${as ?? fixtureName(method, path)}');
  print(const JsonEncoder.withIndent('  ').convert(masked));
  print(fixtureEnd);
}
