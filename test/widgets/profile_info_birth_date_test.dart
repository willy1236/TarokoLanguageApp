// 個人資料頁的出生日期（POL-01）：唯讀顯示 YYYY/MM/DD，舊後端沒有欄位時不顯示。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/profile/profile_info_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  Future<void> open(WidgetTester tester, Map<String, dynamic> me) async {
    installMockClient({'/api/me': me});
    UserService.currentUid = me['uid'] as int;
    UserService.cacheUser(UserModel.fromJson(me));
    await tester.pumpWidget(wrapScreen(const ProfileInfoScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('顯示 YYYY/MM/DD 與更正說明，點了不會開編輯', (tester) async {
    // 後端 POL-01 未部署，birth_date 依規格 00_核心與認證.md §2.3 手寫。
    await open(
      tester,
      loadFixtureMap('get_api_me.json')..['birth_date'] = '2001-07-04',
    );

    expect(find.text('出生日期'), findsOneWidget);
    expect(find.text('2001/07/04'), findsOneWidget);
    expect(find.text('如需更正請聯繫我們'), findsOneWidget);

    await tester.tap(find.text('2001/07/04'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('360dp 寬度下長內容（通知信箱加徽章）不 overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await open(
      tester,
      loadFixtureMap('get_api_me.json')
        ..['birth_date'] = '2001-07-04'
        ..['self_intro'] = '我在學太魯閣族語，' * 10,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('2001/07/04'), findsOneWidget);
  });

  testWidgets('舊後端沒有 birth_date 時不顯示這一列', (tester) async {
    await open(tester, loadFixtureMap('get_api_me.json'));

    expect(find.text('出生日期'), findsNothing);
  });
}
