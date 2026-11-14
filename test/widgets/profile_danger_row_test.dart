// 刪除帳號入口：用 danger 色，點了呼叫 onTap。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/screens/profile/widgets/profile_rows.dart';

void main() {
  testWidgets('刪除帳號列是 danger 色並可點', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: profileDangerRow(
            icon: Icons.delete_forever_outlined,
            label: '刪除帳號',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('刪除帳號')).style!.color,
      AppColors.dangerDark,
    );
    await tester.tap(find.text('刪除帳號'));
    expect(taps, 1);
  });
}
