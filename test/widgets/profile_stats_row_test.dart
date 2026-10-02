// 個人頁三格統計：數字放大、標籤明顯較小，窄螢幕多位數不換行不溢出。
//
// 取代的人工測試：在 360 寬手機切精簡模式，讓連續學習到 365 天，
// 看三格數字有沒有折行或撐破格子。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_typography.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/profile/widgets/profile_stats.dart';

const _narrowSurface = Size(360, 800);

UserModel _user({int streak = 365, int calls = 128, int posts = 999}) =>
    UserModel(
      uid: 1,
      email: 'me@example.com',
      createdAt: DateTime(2026),
      studyStreak: streak,
      videoCallCount: calls,
      forumPostCount: posts,
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required UserModel user,
    required bool seniorMode,
  }) async {
    tester.view.physicalSize = _narrowSurface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileStatsRow(user: user, seniorMode: seniorMode),
        ),
      ),
    );
  }

  /// 數字實際畫出來是一行、沒有被裁切，且整個落在所屬格子（Expanded 的 Column）內。
  void expectSingleLineInsideCell(WidgetTester tester, String value) {
    final text = find.text(value);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(
      paragraph.getMaxIntrinsicHeight(double.infinity),
      closeTo(paragraph.size.height, 0.01),
      reason: '$value 不該換行',
    );
    // 單靠 maxLines:1 會把數字直接裁掉，上面兩項仍會通過；要確認字沒被截。
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$value 不該被裁切');
    final cell = find.ancestor(of: text, matching: find.byType(Column)).first;
    final cellRect = tester.getRect(cell);
    final textRect = tester.getRect(text);
    expect(textRect.left, greaterThanOrEqualTo(cellRect.left - 0.01));
    expect(textRect.right, lessThanOrEqualTo(cellRect.right + 0.01));
  }

  for (final senior in [false, true]) {
    final mode = senior ? '精簡模式' : '一般模式';

    testWidgets('$mode：數字 display24 粗體酒紅，標籤至少 body 且明顯較小', (tester) async {
      await pump(tester, user: _user(), seniorMode: senior);

      final number = tester.widget<Text>(find.text('365')).style!;
      final label = tester.widget<Text>(find.text('連續學習')).style!;
      final numberSize = AppTypography.size(
        AppTypography.display24,
        seniorMode: senior,
      );
      expect(number.fontSize, numberSize);
      expect(number.fontWeight, FontWeight.w700);
      expect(number.color, AppColors.primary);
      expect(
        label.fontSize,
        greaterThanOrEqualTo(
          AppTypography.size(AppTypography.body, seniorMode: senior),
        ),
      );
      expect(label.fontSize! + 6, lessThanOrEqualTo(numberSize));
    });

    testWidgets('$mode：360 寬三位數不換行、不溢出格子', (tester) async {
      await pump(tester, user: _user(), seniorMode: senior);
      expect(tester.takeException(), isNull);
      for (final v in ['365', '128', '999']) {
        expectSingleLineInsideCell(tester, v);
      }
    });

    testWidgets('$mode：極端位數也靠縮放留在格子內', (tester) async {
      await pump(
        tester,
        user: _user(streak: 1234567890, calls: 9876543210, posts: 1111111111),
        seniorMode: senior,
      );
      expect(tester.takeException(), isNull);
      for (final v in ['1234567890', '9876543210', '1111111111']) {
        expectSingleLineInsideCell(tester, v);
      }
    });
  }
}
