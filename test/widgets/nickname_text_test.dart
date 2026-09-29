// 別人的暱稱旁附好友碼末 4 碼：同名的人靠末碼區分。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
        wrap(
          const NicknameText(
            '阿華',
            friendCode: 'AB12K7Q2',
            style: style,
            maxLines: 1,
          ),
        ),
      );

      expect(find.text('阿華'), findsOneWidget);
      final tag = tester.widget<Text>(find.text(' #K7Q2'));
      expect(tag.style?.fontSize, 16, reason: '沿用暱稱的字級（含精簡模式）');
      expect(tag.style?.color, style.color!.withValues(alpha: 0.55));
    });

    testWidgets('可換行時末碼接在暱稱最後一個字後面', (tester) async {
      await tester.pumpWidget(
        wrap(const NicknameText('阿華', friendCode: 'AB12K7Q2', style: style)),
      );

      expect(find.text('阿華 #K7Q2', findRichText: true), findsOneWidget);
    });

    testWidgets('暱稱過長時只截暱稱，末碼完整顯示', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Center(
            child: SizedBox(
              key: ValueKey('box'),
              width: 140,
              child: NicknameText(
                '官方客服小編官方客服小編官方客服小編',
                friendCode: 'AB12K7Q2',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );

      final name = tester.renderObject<RenderParagraph>(
        find.text('官方客服小編官方客服小編官方客服小編'),
      );
      final tag = tester.renderObject<RenderParagraph>(find.text(' #K7Q2'));
      expect(name.didExceedMaxLines, isTrue);
      expect(tag.didExceedMaxLines, isFalse);
      expect(
        tester.getTopRight(find.text(' #K7Q2')).dx,
        lessThanOrEqualTo(
          tester.getTopRight(find.byKey(const ValueKey('box'))).dx,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('沒有好友碼時只顯示暱稱', (tester) async {
      await tester.pumpWidget(
        wrap(const NicknameText('阿華', friendCode: null, style: style)),
      );

      expect(find.text('阿華'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
    });
  });
}
