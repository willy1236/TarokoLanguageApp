// 別人的暱稱旁附好友碼末 4 碼：同名的人靠末碼區分。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/widgets/nickname_text.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('friendCodeTag', () {
    test('取末 4 碼並轉大寫', () {
      expect(friendCodeTag('ab12k7q2'), '#K7Q2');
    });

    test('沒有好友碼時不出現孤立的 #', () {
      expect(friendCodeTag(null), isNull);
      expect(friendCodeTag(''), isNull);
      expect(friendCodeTag('  '), isNull);
    });

    test('不足 4 碼時整組顯示', () {
      expect(friendCodeTag('k7q'), '#K7Q');
    });
  });

  group('NicknameText', () {
    const style = TextStyle(fontSize: 16, color: Color(0xFF1C0F0D));

    testWidgets('顯示成「暱稱 #末4碼」，末碼字級一致、顏色較淡', (tester) async {
      await tester.pumpWidget(
        wrap(const NicknameText('阿華', friendCode: 'AB12K7Q2', style: style)),
      );

      expect(find.text('阿華 #K7Q2', findRichText: true), findsOneWidget);
      TextSpan? tag;
      tester.widget<RichText>(find.byType(RichText)).text.visitChildren((s) {
        if (s is TextSpan && s.text == ' #K7Q2') tag = s;
        return true;
      });
      expect(tag, isNotNull);
      expect(tag!.style?.fontSize, isNull, reason: '沿用暱稱的字級（含精簡模式）');
      expect(tag!.style?.color, style.color!.withValues(alpha: 0.55));
    });

    testWidgets('沒有好友碼時只顯示暱稱', (tester) async {
      await tester.pumpWidget(
        wrap(const NicknameText('阿華', friendCode: null, style: style)),
      );

      expect(find.text('阿華', findRichText: true), findsOneWidget);
      expect(find.textContaining('#', findRichText: true), findsNothing);
    });
  });
}
