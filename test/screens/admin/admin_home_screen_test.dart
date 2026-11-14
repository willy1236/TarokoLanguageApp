// 後台首頁：功能分組，每個入口都在某一組裡。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/admin/admin_home_screen.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUp(stubCommonChannels);

  testWidgets('四個分組標題與全部 15 個入口都在', (tester) async {
    tester.view.physicalSize = const Size(414, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminHomeScreen()));

    for (final title in ['管理 · 審核', '管理 · 內容', '管理 · 帳號', '管理 · 系統']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    const labels = [
      '檢舉佇列',
      '違規區',
      '申訴',
      '題目回報',
      '髒話詞庫',
      '官方公告',
      '新增文章',
      '影片管理',
      '分類管理',
      '禁言',
      '角色管理',
      '更正出生日期',
      '更正族群／部落',
      '小米幣查帳',
      '發布條款',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
