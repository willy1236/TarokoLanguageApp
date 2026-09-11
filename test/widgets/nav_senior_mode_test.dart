import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/home/home_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/widgets/pill_segmented_toggle.dart';
import 'package:flutter_application_1/shared/widgets/truku_bottom_tab.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await seniorModeController.setEnabled(false);
  });

  testWidgets('底部導航為 首頁/學習影音/廣場活動/好友/我的，點擊回傳對應 index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(TrukuBottomTab(currentIndex: 0, onTap: (i) => tapped = i)),
    );

    for (final label in ['首頁', '學習影音', '廣場活動', '好友', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('視訊'), findsNothing);
    expect(find.text('個人資料'), findsNothing);

    await tester.tap(find.text('好友'));
    expect(tapped, 3);
    await tester.tap(find.text('我的'));
    expect(tapped, 4);
  });

  group('PillSegmentedToggle', () {
    Widget toggle() => wrap(
      PillSegmentedToggle(
        index: 0,
        onChanged: (_) {},
        items: const [
          PillSegmentedItem(label: '個人資料', subtitle: 'PSPUNG'),
          PillSegmentedItem(label: '視訊配對', subtitle: 'PGKALA'),
        ],
      ),
    );

    testWidgets('一般模式顯示羅馬拼音副標', (tester) async {
      await tester.pumpWidget(toggle());
      expect(find.text('PSPUNG'), findsOneWidget);
    });

    testWidgets('精簡模式隱藏副標、主標仍在', (tester) async {
      await seniorModeController.setEnabled(true);
      await tester.pumpWidget(toggle());
      expect(find.text('個人資料'), findsOneWidget);
      expect(find.text('PSPUNG'), findsNothing);
    });
  });

  group('HomeScreen 模式卡導頁', () {
    late List<(int, int?)> calls;

    Widget home() => MaterialApp(
      home: Scaffold(
        body: HomeScreen(
          onNavigateToTab: (index, {subTab}) => calls.add((index, subTab)),
        ),
      ),
    );

    setUp(() => calls = []);

    // 一般模式首頁不可捲動、模式卡吃滿剩餘高度，需要夠高的畫面；測試字型每個字
    // 都是方塊、比實際字型寬，寬度也放大一些避免卡片內的族語名誤報溢位。
    Future<void> usePhoneSize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('點「視訊」導到 我的(4) → 視訊配對(1)', (tester) async {
      await usePhoneSize(tester);
      await tester.pumpWidget(home());
      await tester.tap(find.text('視訊'));
      expect(calls, [(4, 1)]);
    });

    testWidgets('點「活動」導到 廣場活動(2) → 活動(1)', (tester) async {
      await usePhoneSize(tester);
      await tester.pumpWidget(home());
      await tester.tap(find.text('活動'));
      expect(calls, [(2, 1)]);
    });

    testWidgets('精簡模式 2x2 只列 廣場/活動/視訊/文化影音', (tester) async {
      await usePhoneSize(tester);
      await seniorModeController.setEnabled(true);
      await tester.pumpWidget(home());
      for (final zh in ['廣場', '活動', '視訊', '文化影音']) {
        expect(find.text(zh), findsOneWidget);
      }
      expect(find.text('族語學習'), findsNothing);
      expect(find.text('部落故事與傳統知識'), findsNothing); // 副標隱藏
    });

    testWidgets('精簡模式點「活動」導到 廣場活動(2) → 活動(1)', (tester) async {
      await usePhoneSize(tester);
      await seniorModeController.setEnabled(true);
      await tester.pumpWidget(home());
      await tester.tap(find.text('活動'));
      expect(calls, [(2, 1)]);
    });
  });
}
