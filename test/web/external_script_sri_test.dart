// web/ 下的靜態頁從 CDN 載入 script 時要帶 SRI（integrity），CDN 上的檔案
// 被竄改時瀏覽器會拒絕執行。CSP 只限制來源網址，擋不住同一網址的內容被換掉。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web/*.html 的外部 script 都帶 integrity 與 crossorigin', () {
    final pages = Directory(
      'web',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.html'));
    final externalScript = RegExp(
      r'''<script\b[^>]*\bsrc=["']https?://[^>]*>''',
    );

    var checked = 0;
    for (final page in pages) {
      for (final tag in externalScript.allMatches(page.readAsStringSync())) {
        checked++;
        final html = tag.group(0)!;
        expect(
          html,
          contains('integrity="sha'),
          reason: '${page.path} 的外部 script 沒有 integrity：$html',
        );
        expect(
          html,
          contains('crossorigin="anonymous"'),
          reason: '${page.path} 的外部 script 沒有 crossorigin：$html',
        );
      }
    }
    // privacy.html 載入 marked；找不到任何外部 script 代表比對寫壞了。
    expect(checked, greaterThan(0));
  });
}
