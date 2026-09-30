// 檢舉當時 vs 目前的內容：佇列標「檢舉後已修改」，詳情並列兩份，
// 下拉重新整理重抓（頭像複本是限時網址）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/screens/admin/admin_case_detail_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_cases_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_report_detail_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_reports_screen.dart';
import 'package:flutter_application_1/screens/admin/widgets/admin_snapshot_compare.dart';
import 'package:flutter_application_1/shared/widgets/ephemeral_network_image.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app(Widget home) =>
    MaterialApp(scaffoldMessengerKey: scaffoldMessengerKey, home: home);

const _changedLabel = '⚠️ 檢舉後已修改';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> reportsJson;
  late Map<String, dynamic> casesJson;
  late List<http.Request> seen;

  List<AdminReport> reports() => [
    for (final r in reportsJson['reports'] as List)
      AdminReport.fromJson(r as Map<String, dynamic>),
  ];

  List<AdminCase> cases() => [
    for (final c in casesJson['cases'] as List)
      AdminCase.fromJson(c as Map<String, dynamic>),
  ];

  setUp(() {
    stubCommonChannels();
    seen = [];
    reportsJson = loadSpecFixtureMap(
      'get_api_admin_forum_reports_snapshot.json',
    );
    casesJson = loadSpecFixtureMap(
      'get_api_admin_moderation_cases_snapshot.json',
    );
    installMockClient({
      '/api/admin/forum/reports': reportsJson,
      '/api/admin/moderation/cases': casesJson,
      '/api/shop/items': {'items': []},
    }, onRequest: seen.add);
  });
  tearDown(restoreHttp);

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('佇列：被改過的檢舉標「檢舉後已修改」，不並列內容', (tester) async {
    tall(tester);
    await tester.pumpWidget(_app(const AdminReportsScreen()));
    await tester.pumpAndSettle();

    // 五筆裡有兩筆 target_changed。
    expect(find.text(_changedLabel), findsNWidgets(2));
    expect(find.byType(AdminSnapshotCompare), findsNothing);
    expect(find.text('改過之後的標題'), findsOneWidget);
  });

  testWidgets('貼文檢舉詳情：當時的標題內文與目前的內容並列', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[0])),
    );
    await tester.pumpAndSettle();

    expect(find.text(_changedLabel), findsOneWidget);
    expect(find.text('檢舉當時的標題'), findsOneWidget);
    expect(find.text('檢舉當時的內文'), findsOneWidget);
    expect(find.text('改過之後的標題'), findsOneWidget);
  });

  testWidgets('活動檢舉詳情：當時的標題、說明、地點、地址', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[1])),
    );
    await tester.pumpAndSettle();

    expect(find.text(_changedLabel), findsNothing);
    expect(find.text('當時的活動標題'), findsOneWidget);
    expect(find.text('當時的活動說明'), findsOneWidget);
    expect(find.textContaining('當時的地點', findRichText: true), findsOneWidget);
    expect(find.textContaining('當時的地址', findRichText: true), findsOneWidget);
  });

  testWidgets('個人檔案檢舉詳情：有複本顯示當時的頭像複本，並列目前的暱稱自介', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[2])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('當時的暱稱', findRichText: true), findsOneWidget);
    expect(find.textContaining('當時的自介', findRichText: true), findsOneWidget);
    expect(find.textContaining('目前的暱稱', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<EphemeralNetworkImage>(find.byType(EphemeralNetworkImage))
          .url,
      contains('evidence.webp'),
    );
  });

  testWidgets('個人檔案檢舉詳情：沒有複本時依 avatar_id 顯示商店頭像', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[3])),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EphemeralNetworkImage), findsNothing);
    expect(find.text('頭像（商店頭像）'), findsOneWidget);
  });

  testWidgets('沒有存證（留言等）：照舊只顯示目前內容', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[4])),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminSnapshotCompare), findsNothing);
    expect(find.text('被檢舉的留言'), findsOneWidget);
  });

  testWidgets('檢舉詳情下拉重新整理：重抓佇列，換上新的複本網址', (tester) async {
    await tester.pumpWidget(
      _app(AdminReportDetailScreen(report: reports()[2])),
    );
    await tester.pumpAndSettle();

    final target = (reportsJson['reports'] as List)[2] as Map<String, dynamic>;
    (target['target_snapshot'] as Map<String, dynamic>)['avatar_evidence_url'] =
        'https://example.com/evidence.webp?sig=fresh';

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(
      seen
          .where((r) => r.url.path == '/api/admin/forum/reports')
          .single
          .url
          .queryParameters['status'],
      'pending',
    );
    expect(
      tester
          .widget<EphemeralNetworkImage>(find.byType(EphemeralNetworkImage))
          .url,
      endsWith('sig=fresh'),
    );
  });

  testWidgets('違規區：列表與詳情都顯示當事人好友碼，詳情並列開案那筆檢舉當時的內容', (tester) async {
    tall(tester);
    await tester.pumpWidget(_app(const AdminCasesScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('DDDD2345', findRichText: true), findsOneWidget);
    expect(find.byType(AdminSnapshotCompare), findsNothing);

    await tester.pumpWidget(_app(AdminCaseDetailScreen(adminCase: cases()[0])));
    await tester.pumpAndSettle();

    expect(find.textContaining('DDDD2345', findRichText: true), findsOneWidget);
    expect(find.text('檢舉當時的標題'), findsOneWidget);
    expect(find.text('目前的標題'), findsOneWidget);
  });

  testWidgets('管理員直接下架的案件沒有存證：只顯示目前內容', (tester) async {
    tall(tester);
    await tester.pumpWidget(_app(AdminCaseDetailScreen(adminCase: cases()[1])));
    await tester.pumpAndSettle();

    expect(find.byType(AdminSnapshotCompare), findsNothing);
    expect(find.text('違規標題'), findsOneWidget);
  });
}
