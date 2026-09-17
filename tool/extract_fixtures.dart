// 從 api_inspector 的測試輸出取出 fixture 並寫進 test/fixtures/api/。
//
// 為什麼需要這一步：整合測試跑在裝置／模擬器上，測試程式用 dart:io 寫的檔案
// 會落在裝置的檔案系統，開發機拿不到。所以錄製時把（已遮罩的）回應印到 stdout，
// 再由這支在開發機上執行的腳本還原成檔案。
//
// 用法：
//   flutter test integration_test/api_inspector_test.dart -d <device> \
//       --dart-define=RECORD_FIXTURES=true > fixtures.log
//   dart run tool/extract_fixtures.dart fixtures.log
//
// 沒給檔名就從 stdin 讀，可以直接 pipe：
//   flutter test ... --dart-define=RECORD_FIXTURES=true | dart run tool/extract_fixtures.dart

import 'dart:convert';
import 'dart:io';

const String _begin = '<<<FIXTURE';
const String _end = 'FIXTURE>>>';
const String _outDir = 'test/fixtures/api';

Future<void> main(List<String> args) async {
  final String raw;
  if (args.isEmpty) {
    raw = await systemEncoding.decodeStream(stdin);
  } else {
    final file = File(args.first);
    if (!file.existsSync()) {
      stderr.writeln('找不到檔案：${args.first}');
      exitCode = 1;
      return;
    }
    raw = file.readAsStringSync();
  }

  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final lines = const LineSplitter().convert(raw);
  var written = 0;
  var skipped = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith(_begin)) continue;

    final name = line.substring(_begin.length).trim();
    final buffer = StringBuffer();
    var closed = false;
    for (var j = i + 1; j < lines.length; j++) {
      if (lines[j].trim() == _end) {
        i = j;
        closed = true;
        break;
      }
      buffer.writeln(lines[j]);
    }
    if (!closed) {
      stderr.writeln('！ $name 的區塊沒有結束標記，略過（測試可能中斷）');
      skipped++;
      continue;
    }

    // 再解析一次確認是合法 JSON——測試輸出可能夾雜其他 print。
    final Object? decoded;
    try {
      decoded = jsonDecode(buffer.toString());
    } catch (e) {
      stderr.writeln('！ $name 不是合法 JSON，略過：$e');
      skipped++;
      continue;
    }

    final out = File('$_outDir/$name');
    final pretty = '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
    final isNew = !out.existsSync();
    final changed = isNew || out.readAsStringSync() != pretty;
    out.writeAsStringSync(pretty);
    written++;
    final mark = isNew ? '新增' : (changed ? '更新' : '未變');
    stdout.writeln('$mark  $_outDir/$name');
  }

  stdout.writeln('\n共寫出 $written 個 fixture'
      '${skipped > 0 ? '，略過 $skipped 個' : ''}。');
  if (written == 0) {
    stderr.writeln(
      '沒有取到任何 fixture。請確認測試有加 --dart-define=RECORD_FIXTURES=true，'
      '且輸出有被導進這支腳本。',
    );
    exitCode = 1;
  }
}
