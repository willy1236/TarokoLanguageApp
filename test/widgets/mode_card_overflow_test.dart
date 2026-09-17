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

Widget _home({double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: HomeScreen(onNavigateToTab: (index, {subTab}) {}),
        ),
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

  // 矮視窗：web 上網址列、工具列、翻譯列會吃掉高度；手機橫向與分割畫面同理。
  // 這些情境下模式卡曾被 ModeCard 的 Clip.hardEdge 把中文標題切成一半，而
  // 裁切不會拋 overflow 例外，所以這裡除了例外還要斷言標題文字仍在畫面上。
  //
  // textScale 1.15 是 main.dart 對一般模式的 textScaler 上限。
  for (final (width, height, textScale) in [
    (360.0, 640.0, 1.0),
    (390.0, 600.0, 1.0),
    (390.0, 600.0, 1.15),
    (414.0, 480.0, 1.15),
  ]) {
    testWidgets(
      '模式卡在 ${width.toInt()}x${height.toInt()} textScale $textScale 不會被裁掉',
      (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_home(textScale: textScale));

        expect(tester.takeException(), isNull);

        // 高度不足時模式卡區會改成可捲，捲到底把後面的卡片帶進畫面。
        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -600));
          await tester.pumpAndSettle();
        }

        // 中文標題是這張卡的識別，任何情況都不該消失或被切掉。
        for (final zh in ['廣場', '活動']) {
          final finder = find.text(zh);
          expect(finder, findsWidgets, reason: '$zh 標題不見了');
          final box = tester.getRect(finder.first);
          expect(box.height, greaterThan(0), reason: '$zh 標題被壓成 0 高');
        }
      },
    );
  }
}
