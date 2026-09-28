// 版本更新提示：一般更新可略過／稍後；低於最低版本時只剩「更新」，按了也不關閉。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/app_update/app_update_service.dart';
import 'package:flutter_application_1/services/app_update/app_version.dart';
import 'package:flutter_application_1/shared/widgets/app_update_prompt.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => stubCommonChannels(urlLauncher: true));
  tearDown(() => AppUpdateService.available.value = null);

  final version = AppVersion.tryParse('1.0.1+9')!;

  Widget app() => const MaterialApp(
    home: AppUpdatePromptLayer(child: Scaffold(body: Text('底下的頁面'))),
  );

  testWidgets('一般更新：三個按鈕，按「稍後」就關閉', (tester) async {
    AppUpdateService.available.value = AvailableUpdate(
      version: version,
      url: 'https://example.com/store',
    );
    await tester.pumpWidget(app());

    expect(find.text('有新版本可用'), findsOneWidget);
    expect(find.text('略過此版本'), findsOneWidget);
    await tester.tap(find.text('稍後'));
    await tester.pump();

    expect(find.text('有新版本可用'), findsNothing);
  });

  testWidgets('強制更新：只有「更新」，按了去商店後提示仍然擋著', (tester) async {
    AppUpdateService.available.value = AvailableUpdate(
      version: version,
      url: 'https://example.com/store',
      required: true,
    );
    await tester.pumpWidget(app());

    expect(find.text('需要更新'), findsOneWidget);
    expect(find.text('略過此版本'), findsNothing);
    expect(find.text('稍後'), findsNothing);

    await tester.tap(find.text('更新'));
    await tester.pump();

    expect(find.text('需要更新'), findsOneWidget);
    expect(AppUpdateService.available.value, isNotNull);
  });

  testWidgets('強制更新但沒有更新連結（iOS 沒設 update_url_ios）：仍然擋著，請使用者自己去更新', (
    tester,
  ) async {
    AppUpdateService.available.value = AvailableUpdate(
      version: version,
      url: null,
      required: true,
    );
    await tester.pumpWidget(app());

    expect(find.textContaining('請到 TestFlight 或 App Store 更新'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
