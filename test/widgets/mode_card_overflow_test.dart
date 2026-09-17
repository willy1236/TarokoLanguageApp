// 首頁模式卡在窄螢幕的版面守門測試。
//
// 背景：PR #73 發現 ModeCard（mode_card.dart 的頂部 Row）在 414px 寬會橫向
// overflow 18~33px——iPhone 14/15 的邏輯寬度正落在這裡，卡片右上角的族語名會
// 被截掉。當時的處置是把測試畫布調寬到 480 避開，等於把唯一的自動化警報拆掉。
// 這支測試就是那個警報：族語名改成 FittedBox 縮放後，窄螢幕不該再 overflow。
//
// RenderFlex overflow 在 widget test 裡會以例外形式浮出，用 takeException 斷言。
// 測試字型（Ahem）每個字都是等寬方塊、比實際的 crimsonPro 寬，所以這裡過了，
// 實機只會更寬鬆。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/screens/home/home_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';

Widget _home() => MaterialApp(
      home: Scaffold(
        body: HomeScreen(onNavigateToTab: (index, {subTab}) {}),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await seniorModeController.setEnabled(false);
  });

  // 414 = iPhone 14/15；360 = Android 常見的最窄邏輯寬度。
  // 兩個都測，確認縮放策略不是剛好卡在 414 的特例。
  for (final width in [414.0, 360.0]) {
    testWidgets('模式卡在 ${width.toInt()}px 寬不會橫向 overflow', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_home());

      expect(
        tester.takeException(),
        isNull,
        reason: '$width 寬出現 overflow，代表模式卡在實機上會截字',
      );

      // 縮放不該把文字整個吃掉：五張卡的族語名都要還在。
      for (final truku in ['KARI TRUKU', 'LNGLUNGAN', 'PGKALA', 'ALANG', 'SMRATUC']) {
        expect(find.text(truku), findsOneWidget, reason: '$truku 不見了');
      }
    });
  }
}
