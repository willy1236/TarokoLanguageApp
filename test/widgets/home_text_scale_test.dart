// 系統字級放大：上限 1.3；首頁放大字級時改成可捲動，不再整頁縮小。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_typography.dart';
import 'package:flutter_application_1/screens/home/home_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';

void main() {
  group('AppTypography.clampTextScaler', () {
    double scaleOf(double system, {bool senior = false}) =>
        AppTypography.clampTextScaler(
          TextScaler.linear(system),
          seniorMode: senior,
        ).scale(10);

    test('一般模式上限 1.3、下限 1.0', () {
      expect(scaleOf(1.15), closeTo(11.5, 0.01));
      expect(scaleOf(1.3), closeTo(13, 0.01));
      expect(scaleOf(2.0), closeTo(13, 0.01));
      expect(scaleOf(0.8), closeTo(10, 0.01));
    });

    test('精簡模式上限 1.5', () {
      expect(scaleOf(2.0, senior: true), closeTo(15, 0.01));
    });
  });

  group('首頁在矮畫面', () {
    Future<void> pumpHome(WidgetTester tester, double textScale) async {
      await seniorModeController.setEnabled(false);
      tester.view.physicalSize = const Size(414, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(414, 600),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('一般字級：整頁等比縮小、不捲動', (tester) async {
      await pumpHome(tester, 1.0);
      expect(find.byType(FittedBox), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('字級 1.3：改為可捲動', (tester) async {
      await pumpHome(tester, 1.3);
      expect(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
