// 個人資料編輯對話框的長度上限：以 UTF-16 計數顯示計數器，輸入與貼上截在上限內，
// 組字中直接按儲存而超過上限時擋下並提示，不送出給後端。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile/widgets/profile_rename_dialog.dart';

void main() {
  String? result;
  var closed = false;

  Future<void> open(WidgetTester tester, {String initial = ''}) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => ProfileRenameDialog(
                    title: '修改公開暱稱',
                    label: '公開暱稱',
                    initialValue: initial,
                    maxLength: 5,
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('計數器每個 emoji 算 2，貼上超長文字截在上限內且不切斷 emoji', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '中😀');
    await tester.pump();
    expect(find.text('3/5'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '中😀😀😀');
    await tester.pump();
    expect(find.text('中😀😀'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
  });

  testWidgets('儲存時回傳去掉頭尾空白的內容', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), ' 阿美 ');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, '阿美');
  });

  testWidgets('組字中超過上限直接按儲存：提示並擋下，對話框不關', (tester) async {
    await open(tester);
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abcdef',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 4, end: 6),
      ),
    );
    await tester.pump();
    expect(find.text('6/5'), findsOneWidget);

    await tester.tap(find.text('儲存'));
    await tester.pump();
    expect(find.text('公開暱稱不能超過 5 字'), findsOneWidget);
    expect(closed, isFalse);
    expect(find.byType(ProfileRenameDialog), findsOneWidget);
  });
}
