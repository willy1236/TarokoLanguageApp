// 違規區案件預覽：好友通話維持箭頭，隨機視訊顯示使用者 A／B 與起訖時間。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/date_format.dart';
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/screens/admin/admin_cases_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

AdminCase _case(String fixture, int index) => AdminCase.fromJson(
  (loadSpecFixtureMap(fixture)['cases'] as List)[index] as Map<String, dynamic>,
);

Widget _app(AdminCase c) => MaterialApp(
  home: Scaffold(body: AdminCasePreviewView(adminCase: c)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubCommonChannels);

  testWidgets('隨機視訊案件：使用者 A／B 與起訖時間，沒有箭頭', (tester) async {
    await tester.pumpWidget(
      _app(_case('get_api_admin_moderation_cases_video_call.json', 0)),
    );

    expect(
      find.textContaining('使用者 A 20／使用者 B 21', findRichText: true),
      findsOneWidget,
    );
    final start = DateTime.utc(2026, 10, 9, 10);
    final end = DateTime.utc(2026, 10, 9, 10, 5);
    expect(
      find.textContaining(
        '通話時間：${formatDateTime(start)} – ${formatTime(end)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('→', findRichText: true), findsNothing);
  });

  testWidgets('好友通話案件：維持「發起 → 接聽」與時間', (tester) async {
    await tester.pumpWidget(
      _app(_case('get_api_admin_moderation_cases.json', 3)),
    );

    expect(find.textContaining('6 → 4', findRichText: true), findsOneWidget);
    expect(find.textContaining('時間', findRichText: true), findsOneWidget);
    expect(find.textContaining('使用者 A', findRichText: true), findsNothing);
  });
}
