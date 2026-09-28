// UTF-16 字數上限：計數與截斷要跟後端 JS `.length` 一致。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/utils/utf16_length_limit.dart';

TextEditingValue _value(String text, {TextRange composing = TextRange.empty}) =>
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: composing,
    );

void main() {
  group('truncateUtf16', () {
    test('中文、族語字母一字算 1，與原本相同', () {
      expect('太魯閣族'.length, 4);
      expect('Truku sediq'.length, 11);
      expect(truncateUtf16('太魯閣族', 3), '太魯閣');
    });

    test('emoji 算 2，截斷不切在 emoji 中間', () {
      expect('😀'.length, 2);
      // 上限 3：「a😀」剛好 3，再加一個 emoji 超過，整個丟掉不留半個。
      expect(truncateUtf16('a😀😀', 3), 'a😀');
      expect(truncateUtf16('a😀😀', 4), 'a😀');
    });

    test('多碼點的 emoji（旗幟、ZWJ 家庭）整顆保留或整顆丟棄', () {
      const flag = '🇹🇼'; // 4 個 UTF-16 單位
      expect(truncateUtf16('a$flag', 3), 'a');
      expect(truncateUtf16('a$flag', 5), 'a$flag');
    });
  });

  group('Utf16LengthLimitingTextInputFormatter', () {
    const formatter = Utf16LengthLimitingTextInputFormatter(5);

    test('未超過不動', () {
      final v = _value('abcde');
      expect(formatter.formatEditUpdate(_value(''), v), v);
    });

    test('貼上超過上限：截在上限內，游標夾在結尾', () {
      final out = formatter.formatEditUpdate(_value(''), _value('abc😀😀'));
      expect(out.text, 'abc😀');
      expect(out.selection.baseOffset, 5);
    });

    test('已滿時在中間輸入：內容不變，不吃掉結尾的字', () {
      final old = TextEditingValue(
        text: 'abcde',
        selection: const TextSelection.collapsed(offset: 2),
      );
      final typed = TextEditingValue(
        text: 'abXcde',
        selection: const TextSelection.collapsed(offset: 3),
      );
      final out = formatter.formatEditUpdate(old, typed);
      expect(out.text, 'abcde');
      expect(out.selection.baseOffset, 2);
    });

    test('剩 1 單位時在中間插入 emoji（2 單位）：整顆不收，結尾保留', () {
      final old = TextEditingValue(
        text: 'abcd',
        selection: const TextSelection.collapsed(offset: 1),
      );
      final typed = TextEditingValue(
        text: 'a😀bcd',
        selection: const TextSelection.collapsed(offset: 3),
      );
      expect(formatter.formatEditUpdate(old, typed).text, 'abcd');
    });

    test('在中間貼上過長文字：只收得下的部分，游標停在貼上內容之後', () {
      final old = TextEditingValue(
        text: 'ab',
        selection: const TextSelection.collapsed(offset: 1),
      );
      final typed = TextEditingValue(
        text: 'a12345b',
        selection: const TextSelection.collapsed(offset: 6),
      );
      final out = formatter.formatEditUpdate(old, typed);
      expect(out.text, 'a123b');
      expect(out.selection.baseOffset, 4);
    });

    test('輸入法組字中先不截，組字完成才截', () {
      final composing = _value(
        'abcdㄊㄞ',
        composing: const TextRange(start: 4, end: 6),
      );
      expect(formatter.formatEditUpdate(_value('abcd'), composing), composing);

      final done = formatter.formatEditUpdate(composing, _value('abcd太魯'));
      expect(done.text, 'abcd太');
    });
  });

  testWidgets('計數器每個 emoji 算 2，到上限後無法再輸入', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: const [Utf16LengthLimitingTextInputFormatter(5)],
            buildCounter: utf16CounterBuilder(controller, 5),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '中😀');
    await tester.pump();
    expect(find.text('3/5'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '中😀😀😀');
    await tester.pump();
    expect(controller.text, '中😀😀');
    expect(find.text('5/5'), findsOneWidget);
  });
}
