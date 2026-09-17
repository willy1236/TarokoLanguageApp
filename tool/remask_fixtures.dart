// ignore_for_file: avoid_print
// 對已存在的 fixture 重跑一次遮罩。
//
// 用途：遮罩名單擴充後，不必接實機重錄一輪，直接把手上的 fixture 洗一次。
// 遮罩是冪等的（遮過的值再遮還是同一個值），所以可以放心重複執行。
//
//   dart run tool/remask_fixtures.dart
//
// 名單本身在 integration_test/helpers/pii_mask.dart，只有那一份。

import 'dart:convert';
import 'dart:io';

import '../integration_test/helpers/pii_mask.dart';

const _dir = 'test/fixtures/api';

void main() {
  final dir = Directory(_dir);
  if (!dir.existsSync()) {
    stderr.writeln('找不到 $_dir');
    exit(1);
  }

  final encoder = const JsonEncoder.withIndent('  ');
  var changed = 0;
  var total = 0;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    total++;
    final original = file.readAsStringSync();
    final masked = '${encoder.convert(maskPii(jsonDecode(original)))}\n';
    final name = file.uri.pathSegments.last;
    if (masked == original) {
      print('未變   $name');
      continue;
    }
    file.writeAsStringSync(masked);
    changed++;
    print('已遮罩 $name');
  }

  print('\n共 $total 份，$changed 份有變更。');
}
